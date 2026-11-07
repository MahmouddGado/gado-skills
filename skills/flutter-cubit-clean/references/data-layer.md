# Data layer

Responsible for talking to the outside world and translating it into domain types.

## Flow

```
Dio / Supabase / storage
   │ throws ApiException
   ▼
XRemoteDataSource  ──►  XModel (JSON)
   ▼
XRepositoryImpl    ──►  try/catch → Result<Entity>
```

## ApiClient (core, once)

```dart
@lazySingleton
final class ApiClient {
  ApiClient(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get<Map<String, dynamic>>(path, queryParameters: query));

  Future<Map<String, dynamic>> post(String path, {Object? body}) =>
      _send(() => _dio.post<Map<String, dynamic>>(path, data: body));

  Future<Map<String, dynamic>> _send(
    Future<Response<Map<String, dynamic>>> Function() request,
  ) async {
    try {
      final response = await request();
      return response.data ?? const {};
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
```

Interceptors (auth token, refresh, locale header, request id) live in
`network/interceptors/`, one per file. Base URL comes from `Env`, never hard-coded.

## ApiException + mapper (core, once)

```dart
final class ApiException implements Exception {
  const ApiException({required this.code, this.message, this.statusCode});

  factory ApiException.fromDio(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic> && data['code'] is String) {
      return ApiException(
        code: data['code'] as String,
        message: data['message'] as String?,
        statusCode: e.response?.statusCode,
      );
    }
    return switch (e.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout => const ApiException(code: 'NETWORK'),
      _ => ApiException(code: 'UNEXPECTED', statusCode: e.response?.statusCode),
    };
  }

  final String code;
  final String? message;
  final int? statusCode;
}
```

```dart
Failure mapException(Object error) => switch (error) {
  ApiException(code: 'NETWORK') => const NetworkFailure(),
  ApiException(statusCode: 401) => const UnauthorizedFailure(),
  ApiException(statusCode: 422, :final code, :final message) => ValidationFailure(code, message),
  ApiException(:final code, :final message) => ServerFailure(code, message),
  _ => const UnexpectedFailure(),
};
```

A small helper keeps every repository method to a few lines:

```dart
Future<Result<T>> guard<T>(Future<T> Function() body) async {
  try {
    return Ok(await body());
  } on Object catch (e, s) {
    log('repository error', error: e, stackTrace: s);
    return Err(mapException(e));
  }
}
```

## Models

```dart
@JsonSerializable(createToJson: false)
final class TripModel {
  const TripModel({
    required this.id,
    required this.lineName,
    required this.departsAt,
    required this.seatsLeft,
    required this.pricePiastres,
    required this.status,
  });

  factory TripModel.fromJson(Map<String, dynamic> json) => _$TripModelFromJson(json);

  final String id;
  @JsonKey(name: 'line_name')
  final String lineName;
  @JsonKey(name: 'departs_at')
  final DateTime departsAt;
  @JsonKey(name: 'seats_left')
  final int seatsLeft;
  @JsonKey(name: 'price_piastres')
  final int pricePiastres;
  @JsonKey(unknownEnumValue: TripStatusDto.unknown)
  final TripStatusDto status;

  Trip toEntity() => Trip(
    id: id,
    lineName: lineName,
    departsAt: departsAt,
    seatsLeft: seatsLeft,
    pricePiastres: pricePiastres,
    status: status.toEntity(),
  );
}
```

- Prefer `@JsonSerializable(fieldRename: FieldRename.snake)` at class level over
  per-field `@JsonKey(name:)` when the API is consistently snake_case.
- Models never leave the data layer. Mapping lives on the model (`toEntity`) or in a
  `x_mapper.dart` when it grows.
- Request bodies get their own small model (`BookSeatRequest`) with `toJson`.
- Generated `*.g.dart` is committed or ignored following the repo's rule; it never
  counts toward the line limit.

## Remote datasource

```dart
abstract interface class TripsRemoteDataSource {
  Future<List<TripModel>> getUpcomingTrips(String lineId);
}

@LazySingleton(as: TripsRemoteDataSource)
final class TripsRemoteDataSourceImpl implements TripsRemoteDataSource {
  const TripsRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<List<TripModel>> getUpcomingTrips(String lineId) async {
    final json = await _client.get(ApiPaths.trips, query: {'line_id': lineId});
    final items = json['items'] as List<dynamic>;
    return items.map((e) => TripModel.fromJson(e as Map<String, dynamic>)).toList();
  }
}
```

- Endpoint paths live in one `ApiPaths` class per feature or in core.
- A datasource throws; it never returns `Result`.
- Local datasources (cache, secure storage, offline queue) follow the same shape:
  `XLocalDataSource` interface + impl.

## Repository implementation

```dart
@LazySingleton(as: TripsRepository)
final class TripsRepositoryImpl implements TripsRepository {
  const TripsRepositoryImpl(this._remote);

  final TripsRemoteDataSource _remote;

  @override
  Future<Result<List<Trip>>> getUpcomingTrips({required String lineId}) => guard(
    () async => (await _remote.getUpcomingTrips(lineId)).map((m) => m.toEntity()).toList(),
  );
}
```

- Caching strategy (remote first, fall back to cache; or cache then refresh) is the
  repository's decision — document it in one line on the class.
- Offline write queues (e.g. driver manifest check-ins) belong to the repository +
  a local datasource, not to the cubit.

## Streams (realtime, GPS)

- The datasource exposes `Stream<XModel>`; the repository maps to
  `Stream<Entity>` and converts errors with `handleError` into a domain event or
  lets the cubit handle `onError`.
- Ordering and dedupe rules the server enforces (e.g. sequence numbers) are still
  sent correctly by the client: keep a monotonic counter in the datasource.

## Uploads (signed URLs)

1. Repository asks the backend for a signed upload URL.
2. Datasource `PUT`s the file bytes to that URL with Dio (no SDK table access).
3. Repository confirms the upload with the backend and returns the entity.

Never log file contents, URLs with tokens, or receipt images.

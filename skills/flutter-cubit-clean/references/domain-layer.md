# Domain layer

Pure Dart. No `package:flutter`, no Dio, no JSON, no Supabase.

## Core building blocks (create once in the core package)

```dart
// core/result/result.dart
sealed class Result<T> {
  const Result();

  R when<R>({required R Function(T value) ok, required R Function(Failure failure) err}) =>
      switch (this) {
        Ok<T>(:final value) => ok(value),
        Err<T>(:final failure) => err(failure),
      };
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);
  final Failure failure;
}
```

```dart
// core/error/failure.dart
sealed class Failure extends Equatable {
  const Failure(this.code, [this.message]);

  /// Stable backend error code, e.g. TRIP_FULL.
  final String code;
  final String? message;

  @override
  List<Object?> get props => [code, message];
}

final class NetworkFailure extends Failure {
  const NetworkFailure() : super('NETWORK');
}

final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure() : super('UNAUTHORIZED');
}

final class ServerFailure extends Failure {
  const ServerFailure(super.code, [super.message]);
}

final class ValidationFailure extends Failure {
  const ValidationFailure(super.code, [super.message]);
}

final class UnexpectedFailure extends Failure {
  const UnexpectedFailure() : super('UNEXPECTED');
}
```

```dart
// core/usecase/usecase.dart
abstract interface class UseCase<T, P> {
  Future<Result<T>> call(P params);
}

final class NoParams {
  const NoParams();
}
```

Stream use cases (live GPS, realtime) return `Stream<T>` and are separate classes —
do not force them into `UseCase`.

## Entities

```dart
final class Trip extends Equatable {
  const Trip({
    required this.id,
    required this.lineName,
    required this.departsAt,
    required this.seatsLeft,
    required this.pricePiastres,
    required this.status,
  });

  final String id;
  final String lineName;
  final DateTime departsAt;
  final int seatsLeft;
  final int pricePiastres;
  final TripStatus status;

  bool get isBookable => status == TripStatus.scheduled && seatsLeft > 0;

  @override
  List<Object?> get props => [id, lineName, departsAt, seatsLeft, pricePiastres, status];
}

enum TripStatus { scheduled, inProgress, completed, cancelled }
```

Rules:
- Only fields the UI or rules need — not a mirror of the API JSON.
- Derived getters are fine (`isBookable`) when they are display logic the server
  already decided (status + seats). Never compute prices, balances or permissions.
- Money: `int` minor units with a `Piastres`/`Cents` suffix.
- Dates: `DateTime` in UTC from the API; convert to local only when formatting.
- Enums for closed sets; unknown API values map to an explicit `unknown` value.

## Repository contracts

```dart
abstract interface class TripsRepository {
  Future<Result<List<Trip>>> getUpcomingTrips({required String lineId});
  Future<Result<Trip>> getTrip(String id);
  Stream<BusLocation> watchBusLocation(String tripId);
}
```

- Named by business noun, not by data source (`TripsRepository`, not `TripsApi`).
- Methods describe intent (`bookSeat`), not HTTP (`postBooking`).
- Return `Result<T>`; return `Result<void>` for commands with no body
  (`Ok<void>(null)`).
- Pagination: return a `Page<T>` entity (`items`, `nextCursor`), never raw maps.

## Use cases

```dart
@injectable
class GetUpcomingTrips implements UseCase<List<Trip>, String> {
  const GetUpcomingTrips(this._repository);

  final TripsRepository _repository;

  @override
  Future<Result<List<Trip>>> call(String lineId) =>
      _repository.getUpcomingTrips(lineId: lineId);
}
```

- One use case = one user intent. Name it with a verb.
- Several params → a small params class (or a record typedef):
  `typedef BookSeatParams = ({String tripId, int seats, String stopId});`
- Use cases may combine repositories (e.g. book then refresh wallet), but keep
  them under ~60 lines; more means a missing domain concept.
- Thin pass-through use cases are fine — they give a stable seam for tests and
  later rules. For trivial read-only screens a cubit may call the repository
  directly; be consistent inside a feature.

## Value objects (optional, when validation repeats)

```dart
extension type const PhoneNumber._(String value) {
  static Result<PhoneNumber> parse(String raw) {
    final v = raw.replaceAll(RegExp(r'\s'), '');
    return RegExp(r'^01[0125]\d{8}$').hasMatch(v)
        ? Ok(PhoneNumber._(v))
        : const Err(ValidationFailure('INVALID_PHONE'));
  }
}
```

Use Dart extension types for zero-cost typed IDs or validated strings when mixing
them up would be a real bug (`TripId` vs `BookingId`).

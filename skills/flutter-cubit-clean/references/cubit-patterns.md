# Cubit patterns

## Rules

- A cubit owns the state of **one screen concern**. Inject use cases via constructor.
- Public methods are user intents: `load()`, `refresh()`, `selectSeat(id)`,
  `submit()`. They return `Future<void>` and never return data to the widget.
- Never `emit` after `close()` — guard async work with `if (isClosed) return;`.
- Never import Flutter widgets, `BuildContext`, `GetIt`, Dio or models in a cubit.
- No `try/catch` in cubits: use cases return `Result`.
- One-off effects (navigate, snackbar) are expressed as state the view reacts to in
  a `BlocListener`, never by passing callbacks or context into the cubit.
- Cancel every `StreamSubscription` and `Timer` in `close()`.
- Declare cubits and use cases as plain `class` (not `final class`) so tests can
  mock them; entities, states, models and impls are `final class`.
- `unawaited(cubit.load())` when starting work from `create:` (the
  `discarded_futures` lint rejects `..load()`).
- Mark the cubit `@injectable` (new instance per screen). Use `@lazySingleton` only
  for app-wide cubits (session, connectivity) provided above the router.

## Pattern A — sealed states (load and show)

```dart
sealed class TripsState extends Equatable {
  const TripsState();

  @override
  List<Object?> get props => [];
}

final class TripsInitial extends TripsState {
  const TripsInitial();
}

final class TripsLoading extends TripsState {
  const TripsLoading();
}

final class TripsLoaded extends TripsState {
  const TripsLoaded(this.trips);

  final List<Trip> trips;

  @override
  List<Object?> get props => [trips];
}

final class TripsFailure extends TripsState {
  const TripsFailure(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
```

```dart
@injectable
class TripsCubit extends Cubit<TripsState> {
  TripsCubit(this._getUpcomingTrips) : super(const TripsInitial());

  final GetUpcomingTrips _getUpcomingTrips;

  Future<void> load(String lineId) async {
    emit(const TripsLoading());
    final result = await _getUpcomingTrips(lineId);
    if (isClosed) return;
    emit(result.when(ok: TripsLoaded.new, err: TripsFailure.new));
  }
}
```

View:

```dart
BlocBuilder<TripsCubit, TripsState>(
  builder: (context, state) => switch (state) {
    TripsInitial() || TripsLoading() => const LoadingView(),
    TripsLoaded(:final trips) when trips.isEmpty => const TripsEmptyView(),
    TripsLoaded(:final trips) => TripsList(trips: trips),
    TripsFailure(:final failure) => ErrorView(
      failure: failure,
      onRetry: () => context.read<TripsCubit>().load(lineId),
    ),
  },
)
```

The `switch` is exhaustive — adding a state forces every view to handle it.

## Pattern B — status + copyWith (forms, pagination, keep data on error)

```dart
enum BookingStatus { idle, submitting, success, failure }

final class BookingState extends Equatable {
  const BookingState({
    this.seats = 1,
    this.stopId,
    this.status = BookingStatus.idle,
    this.failure,
    this.bookingId,
  });

  final int seats;
  final String? stopId;
  final BookingStatus status;
  final Failure? failure;
  final String? bookingId;

  bool get canSubmit => stopId != null && status != BookingStatus.submitting;

  BookingState copyWith({
    int? seats,
    String? stopId,
    BookingStatus? status,
    Failure? Function()? failure,
    String? bookingId,
  }) => BookingState(
    seats: seats ?? this.seats,
    stopId: stopId ?? this.stopId,
    status: status ?? this.status,
    failure: failure != null ? failure() : this.failure,
    bookingId: bookingId ?? this.bookingId,
  );

  @override
  List<Object?> get props => [seats, stopId, status, failure, bookingId];
}
```

Nullable fields that must be clearable use the `T? Function()?` trick (or freezed).

```dart
@injectable
class BookingCubit extends Cubit<BookingState> {
  BookingCubit(this._bookSeat, @factoryParam this._tripId) : super(const BookingState());

  final BookSeat _bookSeat;
  final String _tripId;

  void seatsChanged(int seats) => emit(state.copyWith(seats: seats));

  void stopSelected(String stopId) => emit(state.copyWith(stopId: stopId));

  Future<void> submit() async {
    if (!state.canSubmit) return;
    emit(state.copyWith(status: BookingStatus.submitting, failure: () => null));
    final result = await _bookSeat((tripId: _tripId, seats: state.seats, stopId: state.stopId!));
    if (isClosed) return;
    emit(switch (result) {
      Ok(:final value) => state.copyWith(status: BookingStatus.success, bookingId: value.id),
      Err(:final failure) => state.copyWith(status: BookingStatus.failure, failure: () => failure),
    });
  }
}
```

`seats` here is the user's request; the server decides if seats exist (`TRIP_FULL`).

## Pagination

```dart
final class ListState<T> extends Equatable {
  const ListState({
    this.items = const [],
    this.cursor,
    this.hasMore = true,
    this.status = ListStatus.initial,
    this.failure,
  });
  // ... copyWith + props
}
```

```dart
Future<void> loadMore() async {
  if (!state.hasMore || state.status == ListStatus.loadingMore) return;
  emit(state.copyWith(status: ListStatus.loadingMore));
  final result = await _getHistory(cursor: state.cursor);
  if (isClosed) return;
  emit(switch (result) {
    Ok(:final value) => state.copyWith(
      items: [...state.items, ...value.items],
      cursor: value.nextCursor,
      hasMore: value.nextCursor != null,
      status: ListStatus.loaded,
    ),
    Err(:final failure) => state.copyWith(status: ListStatus.failure, failure: () => failure),
  });
}
```

Put a generic `ListState<T>` in core once both apps paginate.

## Streams (live tracking, realtime)

```dart
@injectable
class LiveTrackingCubit extends Cubit<LiveTrackingState> {
  LiveTrackingCubit(this._watchBus) : super(const LiveTrackingState());

  final WatchBusLocation _watchBus;
  StreamSubscription<BusLocation>? _sub;

  void start(String tripId) {
    _sub?.cancel();
    _sub = _watchBus(tripId).listen(
      (location) => emit(state.copyWith(location: location, connected: true)),
      onError: (Object _) => emit(state.copyWith(connected: false)),
    );
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
```

Throttle UI-heavy streams in the repository (e.g. `distinct`, sample) rather than
in the widget.

## Debounce (search)

Use a `Timer` field cancelled on each call and in `close()`, or
`stream_transform` in the repository. Do not switch to Bloc only for debouncing.

## Effects (navigation, snackbars)

```dart
BlocListener<BookingCubit, BookingState>(
  listenWhen: (prev, curr) => prev.status != curr.status,
  listener: (context, state) => switch (state.status) {
    BookingStatus.success => context.goNamed(PaymentRoutes.name, pathParameters: {'id': state.bookingId!}),
    BookingStatus.failure => AppSnackBar.showFailure(context, state.failure!),
    _ => null,
  },
  child: const BookingView(),
)
```

Always set `listenWhen`/`buildWhen` when state carries more than one field.

## Rebuild scope

- `BlocSelector` or `context.select((BookingCubit c) => c.state.seats)` for a widget
  that needs one field.
- `context.watch` only inside small widgets; `context.read` only in callbacks.
- Do not wrap a whole page in `BlocBuilder` when only a button changes.

## When Bloc (events) is justified

Only when you need event transformers (`droppable`, `restartable`, `sequential`)
that a Timer/guard cannot express cleanly, or a strict event log is a requirement.
Write it down in the plan and get approval; default is Cubit.

## App-wide cubits

`AppSessionCubit` (auth state), `LocaleCubit`, `ConnectivityCubit` are provided once
in `app.dart` with `MultiBlocProvider` above `MaterialApp.router`. Router redirects
read the session through a `GoRouterRefreshStream`/`Listenable`, not by importing
feature cubits.

## Observer

```dart
final class AppBlocObserver extends BlocObserver {
  const AppBlocObserver();

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    log('${bloc.runtimeType}', error: error, stackTrace: stackTrace);
    super.onError(bloc, error, stackTrace);
  }
}
```

Log types and errors only — never state contents (they may hold personal data).

# Testing

`test/` mirrors `lib/`. Every feature ships with tests in the same change.

| Layer | Test | Tool |
| --- | --- | --- |
| Use case | Delegates to repository, combines results correctly | `mocktail` |
| Model | `fromJson` with a real API sample, `toEntity` mapping, unknown enum | `flutter_test` |
| Repository | Success maps to entity; each exception maps to the right `Failure` | `mocktail` |
| Cubit | Every public method: emitted states in order, error path | `bloc_test` |
| View/widget | Each state renders the right widget; tap calls the cubit | `flutter_test` + `MockCubit` |
| Router redirect | Pure function cases | `flutter_test` |

Risky logic (money display, seat selection limits, GPS sequence, offline queue):
write the tests first.

## Mocks

```dart
class MockTripsRepository extends Mock implements TripsRepository {}
class MockGetUpcomingTrips extends Mock implements GetUpcomingTrips {}
class MockTripsCubit extends MockCubit<TripsState> implements TripsCubit {}
```

Keep shared mocks and fixtures in `test/helpers/` (`mocks.dart`, `fixtures.dart`,
`pump_app.dart`). Register fallback values in `setUpAll` when using `any()` with
custom types.

## Cubit test

```dart
void main() {
  late MockGetUpcomingTrips getTrips;

  setUp(() => getTrips = MockGetUpcomingTrips());

  group('TripsCubit.load', () {
    blocTest<TripsCubit, TripsState>(
      'emits loading then loaded on success',
      setUp: () => when(() => getTrips('l1')).thenAnswer((_) async => Ok([tTrip])),
      build: () => TripsCubit(getTrips),
      act: (cubit) => cubit.load('l1'),
      expect: () => [const TripsLoading(), TripsLoaded([tTrip])],
      verify: (_) => verify(() => getTrips('l1')).called(1),
    );

    blocTest<TripsCubit, TripsState>(
      'emits loading then failure on error',
      setUp: () => when(() => getTrips('l1'))
          .thenAnswer((_) async => const Err(NetworkFailure())),
      build: () => TripsCubit(getTrips),
      act: (cubit) => cubit.load('l1'),
      expect: () => [const TripsLoading(), const TripsFailure(NetworkFailure())],
    );
  });
}
```

## Repository test

```dart
test('maps ApiException TRIP_FULL to ServerFailure', () async {
  when(() => remote.getUpcomingTrips('l1'))
      .thenThrow(const ApiException(code: 'TRIP_FULL', statusCode: 409));

  final result = await repository.getUpcomingTrips(lineId: 'l1');

  expect(result, isA<Err<List<Trip>>>());
  expect((result as Err).failure, const ServerFailure('TRIP_FULL'));
});
```

## Widget test

```dart
extension PumpApp on WidgetTester {
  Future<void> pumpApp(Widget widget, {Locale locale = const Locale('ar')}) => pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: appTheme(dark: false),
      home: widget,
    ),
  );
}

testWidgets('shows retry on failure and calls load', (tester) async {
  final cubit = MockTripsCubit();
  when(() => cubit.state).thenReturn(const TripsFailure(NetworkFailure()));
  when(() => cubit.load(any())).thenAnswer((_) async {});

  await tester.pumpApp(BlocProvider<TripsCubit>.value(value: cubit, child: const TripsView(lineId: 'l1')));
  await tester.tap(find.byType(FilledButton));

  verify(() => cubit.load('l1')).called(1);
});
```

## Conventions

- Test names describe behaviour: `'emits failure when balance is insufficient'`.
- Arrange / act / assert separated by blank lines; no comments needed.
- One behaviour per test; `group` per public method.
- Fixtures from real (anonymized) API responses in `test/fixtures/*.json`.
- No real network, no real `getIt`, no `sleep`; use `fakeAsync` for timers.
- Test files follow the same 400/500 line rule — split by group if needed.
- Run: `flutter test` (or `melos run test`); add `--coverage` in CI. Aim for full
  coverage of domain, data and cubits; widgets cover every state branch.

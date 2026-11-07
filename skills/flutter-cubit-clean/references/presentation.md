# Presentation

## Page → View → Widgets

| Piece | Job | Size guide |
| --- | --- | --- |
| `XPage` | Route entry. Creates the cubit from DI, triggers the first load, adds listeners | ≤ 60 lines |
| `XView` | Scaffold + layout, switches on state | ≤ 150 lines |
| `widgets/*.dart` | One focused widget each (card, header, form section, empty state) | ≤ 150 lines |

```dart
final class TripsPage extends StatelessWidget {
  const TripsPage({required this.lineId, super.key});

  final String lineId;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) {
      final cubit = getIt<TripsCubit>();
      unawaited(cubit.load(lineId));
      return cubit;
    },
    child: TripsView(lineId: lineId),
  );
}
```

```dart
final class TripsView extends StatelessWidget {
  const TripsView({required this.lineId, super.key});

  final String lineId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tripsTitle)),
      body: RefreshIndicator(
        onRefresh: () => context.read<TripsCubit>().load(lineId),
        child: BlocBuilder<TripsCubit, TripsState>(
          builder: (context, state) => switch (state) {
            TripsInitial() || TripsLoading() => const AppLoading(),
            TripsLoaded(:final trips) when trips.isEmpty => AppEmpty(message: l10n.tripsEmpty),
            TripsLoaded(:final trips) => TripsList(trips: trips),
            TripsFailure(:final failure) => AppError(
              failure: failure,
              onRetry: () => context.read<TripsCubit>().load(lineId),
            ),
          },
        ),
      ),
    );
  }
}
```

The view is testable without DI: wrap it in `BlocProvider.value(value: mockCubit)`.

## Widget rules

- Prefer `StatelessWidget`. Use `StatefulWidget` only for controllers
  (`TextEditingController`, `AnimationController`, `ScrollController`) and dispose
  them.
- **Extract widgets into classes, not helper methods** (`Widget _buildHeader()` is a
  smell — it rebuilds with the parent and cannot be `const`).
- `const` constructors everywhere possible; pass only the data a widget needs
  (`TripCard(trip: trip)`), not the whole state.
- No `MediaQuery.of(context).size` for layout — use `LayoutBuilder`, `Flex`,
  `MediaQuery.sizeOf(context)` only when truly needed.
- Lists: `ListView.builder`/`SliverList.builder` with `itemExtent` or
  `prototypeItem` when possible; never `Column` of a dynamic list.
- Images: `cacheWidth`/`cacheHeight` for thumbnails.
- Keys: `ValueKey(entity.id)` for list items that reorder.
- Accessibility: `Semantics` labels for icon-only buttons, tap targets ≥ 48dp,
  text scales with system settings (no fixed heights on text containers).

## Shared design-system widgets (core)

`AppLoading`, `AppError(failure, onRetry)`, `AppEmpty(message)`, `AppButton`,
`AppTextField`, `MoneyText(piastres)`, `AppSnackBar.showFailure(context, failure)`.
Features compose them; they do not restyle Material widgets ad hoc.

## Failure → message

```dart
extension FailureL10n on Failure {
  String localized(AppLocalizations l10n) => switch (this) {
    NetworkFailure() => l10n.errorNetwork,
    UnauthorizedFailure() => l10n.errorSessionExpired,
    ServerFailure(code: 'TRIP_FULL') => l10n.errorTripFull,
    ServerFailure(code: 'HOLD_EXPIRED') => l10n.errorHoldExpired,
    ServerFailure(code: 'INSUFFICIENT_BALANCE') => l10n.errorInsufficientBalance,
    _ => l10n.errorGeneric,
  };
}
```

Map codes to localized text in one place (core). Name it `localized`, not `message`
(`Failure.message` is already a field). Never show `failure.message` from
the server directly unless the API guarantees it is localized.

## Forms

- Field values live in the cubit state (Pattern B), controllers only mirror input.
- Validation for UX lives in small pure validators (`validators.dart`) returning an
  l10n key or `null`; the server remains the authority.
- Disable submit while `status == submitting`; show progress inside the button.
- Split long forms into section widgets (`PassengerInfoSection`,
  `PaymentMethodSection`) to keep each file small.

## Navigation

- Use `context.goNamed`/`pushNamed` with route names from `XRoutes`.
- Pass IDs in path parameters, not whole entities (deep links must work).
- Need a result back? `final picked = await context.pushNamed<Stop>(...)`.

## Maps and location

- Map widgets live in their own file and receive data only (markers, polyline).
- Keep `GoogleMapController` inside a small `StatefulWidget`; camera moves react
  to state changes via `BlocListener`.
- Request only the permission the app needs (foreground for passenger apps).

## Responsive and adaptive

- Breakpoints from theme tokens; `LayoutBuilder` to switch between compact and wide.
- Use `SafeArea`, `MediaQuery.paddingOf`, and `viewInsetsOf` for the keyboard.

## Loading and error UX

- Skeletons or `AppLoading` on first load; keep old data visible during refresh.
- Every error state has a retry action.
- Empty states are explicit and localized.

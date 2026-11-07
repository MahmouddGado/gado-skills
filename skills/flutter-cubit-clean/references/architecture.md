# Architecture

## Goals

- A new feature is a new folder; existing features do not change.
- Any file can be reviewed in one sitting (≤ 400 lines).
- Business rules are testable without Flutter.
- Two apps share one core without copying code.

## Monorepo layout (two apps + shared core)

```
apps/mobile/
  melos.yaml
  packages/
    <core>/                     # e.g. gado_core — shared, no app-specific features
      lib/
        <core>.dart             # barrel: export only the public API
        core/
          result/result.dart
          error/failure.dart
          error/api_exception.dart
          error/error_mapper.dart
          usecase/usecase.dart
          bloc/app_bloc_observer.dart
        network/                # ApiClient (Dio), interceptors, endpoints
        auth/                   # session, token storage, auth repository
        config/                 # Env from --dart-define
        realtime/               # WebSocket client
        theme/                  # tokens, ThemeData, ThemeExtension
        l10n/                   # ARB + generated
        widgets/                # shared design-system widgets
        di/core_module.dart     # @module for Dio, storage, etc.
  apps/
    <app>/
      lib/
        main.dart               # tiny: bootstrap(() => const App())
        bootstrap.dart          # DI init, BlocObserver, error zones
        app/
          app.dart              # MaterialApp.router, theme, locale
          router/app_router.dart
          di/injection.dart     # @InjectableInit
        features/
          <feature>/
            domain/
              entities/
              repositories/
              usecases/
            data/
              models/
              datasources/
              repositories/
            presentation/
              cubit/
              pages/
              widgets/
            <feature>_routes.dart
      test/
        features/<feature>/...  # mirrors lib/
```

## Dependency rule

```
presentation ──► domain ◄── data
      │                       │
      └──────► core ◄─────────┘
```

- `domain` depends on nothing but core types (`Result`, `Failure`, `UseCase`).
- `data` implements `domain` contracts.
- `presentation` knows `domain` only. It never imports `data/`.
- DI (`injectable`) is the only place that binds `XRepository` → `XRepositoryImpl`.

## Where does this code go?

| Code | Home |
| --- | --- |
| Used by both apps (auth, API client, theme, shared widgets, shared entities like `Trip`) | core package |
| Used by one app, one feature | that feature |
| Used by two features in one app | `lib/shared/<thing>/` in the app, or promote to core if the other app needs it |
| Validation that protects the server | backend (client only mirrors it for UX) |
| Price, seat, balance, permission decisions | backend only; the app shows what the API returns |
| Formatting (dates, money, distance) | core `formatters/`, pure functions |

Do not create a shared folder "just in case" — move code there the second time it is
needed (rule of two).

## Cross-feature communication

- Navigation between features goes through route names (`context.goNamed(...)`),
  never by importing another feature's page class.
- Shared data (current user, wallet balance) lives in an app-level cubit provided
  above the router (`AppSessionCubit`), or is fetched by each feature through its own
  use case. Features do not reach into each other's cubits.
- Events that many features care about (logout, push notification) go through a
  core stream service injected as a singleton; cubits subscribe and cancel in `close`.

## Scaling rules

- A feature folder grows by adding files, not by growing files.
- More than ~8 use cases in a feature? Split the feature (e.g. `booking` and
  `booking_history`).
- More than one screen with heavy logic? One cubit per screen.
- A cubit above ~250 lines usually holds two responsibilities — split it.
- Keep features independent enough to be deleted by removing one folder and one
  route registration.

## Bootstrapping

```dart
Future<void> bootstrap(Widget Function() builder) async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies(Env.current.name);
  Bloc.observer = const AppBlocObserver();
  FlutterError.onError = (details) => log(details.exceptionAsString(), stackTrace: details.stack);
  runApp(builder());
}
```

`main.dart` stays under 15 lines. Flavor/env comes from `--dart-define`.

# DI (get_it + injectable) and routing (go_router)

## Dependencies

```bash
flutter pub add flutter_bloc equatable get_it injectable go_router dio json_annotation
flutter pub add dev:build_runner dev:injectable_generator dev:json_serializable \
  dev:bloc_test dev:mocktail dev:very_good_analysis
```

## App injection entry

```dart
// lib/app/di/injection.dart
final getIt = GetIt.instance;

@InjectableInit(
  externalPackageModulesBefore: [ExternalModule(GadoCorePackageModule)],
)
Future<void> configureDependencies(String environment) async =>
    getIt.init(environment: environment);
```

- The core package uses `@InjectableInit.microPackage()` so its bindings are exported
  as a `<Core>PackageModule` and included by each app.
- Third-party objects (Dio, SharedPreferences, FlutterSecureStorage, Supabase client)
  are provided by a `@module` in core:

```dart
@module
abstract class NetworkModule {
  @lazySingleton
  Dio dio(Env env, AuthInterceptor auth) => Dio(BaseOptions(
    baseUrl: env.apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
  ))..interceptors.add(auth);

  @preResolve
  @singleton
  Future<SharedPreferences> prefs() => SharedPreferences.getInstance();
}
```

## Annotation cheat sheet

| Kind | Annotation | Lifetime |
| --- | --- | --- |
| Use case | `@injectable` | new each resolve (cheap) |
| Cubit (screen) | `@injectable` | new each page |
| Cubit (app-wide) | `@lazySingleton` | one per app |
| Repository impl | `@LazySingleton(as: XRepository)` | one |
| Datasource impl | `@LazySingleton(as: XRemoteDataSource)` | one |
| Env-specific | `@Environment('dev')` / `@prod` | per flavor |
| Runtime arg | `@factoryParam` | passed at `getIt<X>(param1: id)` |

Run after changing annotations:

```bash
dart run build_runner build -d
```

## Rules

- `getIt` is called only in pages (to create a cubit), in `bootstrap`, and in
  router redirects. Never in widgets below the page, cubits, use cases or repositories.
- Constructor injection only; no service locator calls inside classes.
- Register interfaces, inject interfaces (`TripsRepository`, not the impl).
- Tests do not use `getIt`; construct classes with mocks directly. Widget tests that
  render a page register mocks on a fresh `GetIt` and `reset()` in `tearDown`.

## Routing

### Feature route file

```dart
// features/trips/trips_routes.dart
abstract final class TripsRoutes {
  static const name = 'trips';
  static const path = '/lines/:lineId/trips';
  static const detailName = 'trip-detail';
  static const detailPath = 'trip/:tripId';

  static GoRoute route() => GoRoute(
    name: name,
    path: path,
    builder: (_, state) => TripsPage(lineId: state.pathParameters['lineId']!),
    routes: [
      GoRoute(
        name: detailName,
        path: detailPath,
        builder: (_, state) => TripDetailPage(tripId: state.pathParameters['tripId']!),
      ),
    ],
  );
}
```

### App router

```dart
// app/router/app_router.dart
GoRouter createRouter(AppSessionCubit session) => GoRouter(
  initialLocation: HomeRoutes.path,
  refreshListenable: StreamListenable(session.stream),
  redirect: (context, state) => authRedirect(session.state, state),
  routes: [
    AuthRoutes.route(),
    StatefulShellRoute.indexedStack(
      builder: (_, __, shell) => HomeShell(shell: shell),
      branches: [
        StatefulShellBranch(routes: [TripsRoutes.route()]),
        StatefulShellBranch(routes: [MyBookingsRoutes.route()]),
        StatefulShellBranch(routes: [WalletRoutes.route()]),
        StatefulShellBranch(routes: [ProfileRoutes.route()]),
      ],
    ),
  ],
);
```

- `StreamListenable` is a ~15-line `ChangeNotifier` in core that calls
  `notifyListeners()` on each stream event and cancels in `dispose`.
- Redirect logic is a pure function (`authRedirect`) in its own file — unit-testable.
- Adding a feature = one `XRoutes.route()` line here; nothing else changes.
- Bottom-tab apps use `StatefulShellRoute.indexedStack` so tabs keep their state.
- Deep links use the same paths; never rely on `extra` for required data.

### Navigating

```dart
context.goNamed(TripsRoutes.detailName, pathParameters: {'lineId': lineId, 'tripId': trip.id});
```

## App widget

```dart
final class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider.value(value: getIt<AppSessionCubit>()),
      BlocProvider.value(value: getIt<LocaleCubit>()),
    ],
    child: const _AppView(),
  );
}
```

`_AppView` builds `MaterialApp.router` with theme, `locale`, localization delegates
and the router created once (cache it in a `StatefulWidget` or a singleton).

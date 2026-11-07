# Gado Ride context

Load this when working in the Gado Ride repo (`apps/mobile`). Always re-read the
repo's `AGENTS.md` first — it overrides this file if they differ.

## Product

Shared commuter buses from villages (starting with Shibin El Qanater) to Cairo.
Passengers book seats on scheduled trips of admin-managed lines, pay manually
(InstaPay / mobile-wallet transfer + receipt upload, or in-app wallet), track the bus
live, and suggest new lines. Drivers stream GPS every 5 seconds and run the trip
manifest. Admins approve payments on the web.

## Workspace

```
apps/mobile/                  # melos workspace
  apps/passenger/             # package gado_passenger
  apps/driver/                # package gado_driver
  packages/gado_core/         # shared: theme, l10n, network, auth, realtime, maps, widgets
```

- Passenger features: `onboarding, trips, booking, payment, wallet, my_bookings,
  tracking, subscriptions, feedback, profile`.
- Driver features: `trips, live_trip, manifest, incidents, feedback, profile`.
- Commands: `cd apps/mobile && melos bootstrap`, `melos run analyze`,
  `melos run test`, `melos run format`.
- Theme exists in `gado_core/lib/theme/gado_tokens.dart` (`GadoColors`,
  `GadoSpace`, `GadoRadius`, `GadoSize`, `GadoShadow`, `GadoType`, `gadoTheme`,
  `gadoBookButton`). Reuse it; prefer exposing colours via a `ThemeExtension`.
- l10n lives in `gado_core/lib/l10n/` (`app_ar.arb` template, `app_en.arb`,
  class `CoreLocalizations`, output `lib/l10n/generated`). App-specific strings may
  get their own ARB per app; keep the ar template rule.

## State management decision

The wiki (`docs/wiki/Engineering-Standards.md`, `Tech-Stack.md`) and pubspecs still
list Riverpod. This skill standardizes on **Cubit + get_it/injectable**. The first
slice built with this skill should:

1. Replace `flutter_riverpod` with `flutter_bloc`, `equatable`, `get_it`,
   `injectable` in the three pubspecs; add dev deps `build_runner`,
   `injectable_generator`, `json_serializable`, `bloc_test`, `mocktail`.
2. Add core building blocks in `gado_core/lib/core/` (`Result`, `Failure`,
   `ApiException`, `mapException`, `guard`, `UseCase`, `AppBlocObserver`) and
   `gado_core/lib/network/` (`ApiClient`, auth interceptor).
3. Update the wiki mobile sections to say Cubit, in the same change.

Ask the user before doing this if the repo has moved on since this note.

## Backend contract

- REST under `/api/v1/<role>/<resource>` (`passenger`, `driver`, `public`).
  The generated TS client is web-only; read `apps/backend/app/api/v1/` or the
  OpenAPI schema to get request/response shapes.
- Errors: `{ "code": "UPPER_SNAKE_CASE", "message": "..." }`. Known codes include
  `TRIP_FULL`, `HOLD_EXPIRED`, `INSUFFICIENT_BALANCE`, `NOT_ASSIGNED_DRIVER`.
  Map each to a localized message in core (`FailureL10n`).
- Money is integer **piastres** (`*_piastres`). Display with a core
  `MoneyText`/formatter; never use `double`.
- Realtime: WebSocket hub (bus location, trip status). Client lives in
  `gado_core/realtime/` with reconnect + backoff.

## Hard rules for the apps

- The app never decides seat counts, prices, balances or permissions — it shows what
  the API returns and sends user intents.
- Supabase is used **only** for Auth and for uploading receipts to backend-issued
  signed URLs. No Supabase table queries from Flutter.
- Payments are manual: receipt upload + admin review. No payment gateway SDKs.
- Passenger app: foreground location only, never background location.
- Driver app: GPS every 5 s with a monotonically increasing `seq` and device time;
  Android foreground service; queue points while offline and send in order.
- Driver manifest: offline check-in supported (local queue in the repository).
- Do not log receipts, tokens or exact passenger locations.
- Arabic-first: ar + en strings for everything, RTL layout.
- Requirement IDs (e.g. `USR-04`, `WAL-04`, `LOC-02`, `PAY-07`) go in plans,
  commits and PRs.
- No AI attribution in commits, PRs or branch names.

## Where shared code goes

| Thing | Home |
| --- | --- |
| `Trip`, `Line`, `Stop` entities used by both apps | `gado_core/lib/domain/` |
| Auth/session, token storage, API client, realtime | `gado_core` |
| Money/date formatters, `MoneyText`, error/empty/loading widgets | `gado_core` |
| Booking, wallet, payment UI | passenger app |
| Live trip GPS streaming, manifest | driver app |
| Maps widgets used by passenger tracking and driver live trip | `gado_core/lib/maps/` |

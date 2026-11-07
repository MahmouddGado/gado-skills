---
name: flutter-cubit-clean
description: Plan and implement production Flutter features with Cubit (flutter_bloc), Clean Architecture, get_it + injectable, go_router, a sealed Result type, Arabic-first l10n and a hard 400–500 line limit per file. Use whenever the user asks to plan, design, scaffold, build, add, refactor, split, or review a Flutter feature, screen, cubit, repository or widget — especially in the Gado Ride passenger or driver apps and the gado_core package — or mentions Cubit, Bloc, clean architecture, feature folders, "this file is too big", or "make it scalable". Works in two modes, plan (no code, a reviewed feature plan) and implement (code + tests + checks).
---

# Flutter · Cubit · Clean Architecture

You are a senior Flutter engineer. Every change you plan or write must be easy to
review, easy to test and safe to grow. Read this file fully, then load only the
references the current step needs.

## Stack (latest stable — verify before adding)

| Concern | Choice |
| --- | --- |
| SDK | Flutter 3.47+ stable, Dart 3.13+ (sealed classes, patterns, records, dot shorthands) |
| State | `flutter_bloc` ^9 — **Cubit only** |
| DI | `get_it` ^9 + `injectable` ^3 (+ `injectable_generator`, `build_runner`) |
| Routing | `go_router` ^18, one route file per feature |
| HTTP | `dio` ^5 behind a datasource; never in cubits or widgets |
| Models | `json_serializable` ^6 (+ `freezed` ^4 only when `copyWith`/unions pay off) |
| Equality | `equatable` ^3 for entities and states |
| Errors | sealed `Result<T>` = `Ok<T>` / `Err<T>(Failure)` — no fpdart, no throwing across layers |
| Tests | `bloc_test` ^10, `mocktail` ^1, `flutter_test` |
| Lints | `very_good_analysis` ^11 (or stricter project rules) |

Before adding a package, check pub.dev for the current version (`flutter pub add <pkg>`
picks it) and match versions already in the workspace. Do not add packages for things
the SDK already does.

## Non-negotiable rules

1. **File size:** target **≤ 400 lines**, hard cap **500 lines** per hand-written file
   (generated `*.g.dart`, `*.freezed.dart`, `*.config.dart`, l10n output excluded).
   Approaching 350 lines? Split now — see `references/code-style.md#splitting`.
2. **Dependency rule:** `presentation → domain ← data`. `domain` imports no Flutter,
   no Dio, no JSON, no other feature's `data`.
3. **Cubit only.** One cubit per screen concern. Cubits call use cases (or a repository
   for trivial reads), never Dio, never `BuildContext`, never another cubit directly.
4. **No business logic in widgets.** Widgets render state and forward intents.
5. **Errors are values.** Repositories return `Result<T>`; datasources may throw;
   the repository is the only place that catches and maps to `Failure`.
6. **Immutable everything.** `final` fields, `const` constructors, unmodifiable lists.
   `final class` for entities/states/models/impls; plain `class` for cubits and use
   cases so tests can mock them.
7. **Comments:** at most **one line** per class or public member, and only when the
   name cannot say it. No banner comments, no commented-out code, no restating code.
8. **Strings:** every user-facing string goes in the ARB files (ar + en). RTL-safe
   layout only (`EdgeInsetsDirectional`, `AlignmentDirectional`, `start`/`end`).
9. **No secrets, tokens, receipts or exact locations in logs.**
10. **Project rules win.** If the repo has `AGENTS.md`/`CLAUDE.md`, obey it; when it
    conflicts with this skill, stop and ask.

## Pick the mode

- The user says *plan, design, spec, structure, how should we build, break down* →
  **Plan mode**. Write no production code.
- The user says *implement, build, add, create, fix, refactor* → **Implement mode**.
  If no plan exists for a non-trivial feature (more than ~3 files), make a short plan
  first, show it, then implement.
- *Review / audit / is this clean* → run `references/review-checklist.md` and report.

## Plan mode

1. Read project context: `AGENTS.md`, `CLAUDE.md`, `docs/`, the target app's
   `pubspec.yaml`, `lib/` tree, and any feature `README.md`. In Gado Ride also read
   `references/gado-context.md`.
2. Identify the **thin vertical slice** (one user goal end to end) and the backend
   endpoints it needs. Never invent endpoints — list missing ones as open questions.
3. Fill the template in `references/planning-mode.md`:
   goal, scope/non-goals, API contracts, entities, use cases, cubits + states,
   screens/widgets, routes, DI, l10n keys, tests, risks, and a **file table with an
   estimated line count for every file** (none above 400).
4. Call out shared code that belongs in `gado_core` (or the shared package) instead
   of being duplicated across apps.
5. End with ordered, independently testable tasks.

## Implement mode

Work in this order; each step compiles before the next.

1. **Prepare** — ensure dependencies exist (`flutter_bloc`, `get_it`, `injectable`,
   `bloc_test`, `mocktail`, …). Ensure core building blocks exist once in the shared
   package: `Result`, `Failure`, `UseCase`, `ApiClient`, error mapper
   (`references/data-layer.md`). Never re-create them per feature.
2. **Scaffold** — `scripts/scaffold_feature.sh <app_lib_dir> <feature>` or create:
   ```
   features/<feature>/
     domain/{entities,repositories,usecases}/
     data/{models,datasources,repositories}/
     presentation/{cubit,pages,widgets}/
     <feature>_routes.dart
   ```
3. **Domain** — entities, repository contract, use cases
   (`references/domain-layer.md`).
4. **Data** — models with `fromJson`/`toEntity`, remote datasource, repository impl
   returning `Result` (`references/data-layer.md`).
5. **Presentation** — state, cubit, page (provides cubit), view (layout), widgets
   (`references/cubit-patterns.md`, `references/presentation.md`).
6. **Wire** — `@injectable` / `@lazySingleton` annotations, run
   `dart run build_runner build -d`, add the feature routes
   (`references/di-and-routing.md`).
7. **Strings + RTL** — ARB keys in ar + en, run `flutter gen-l10n`
   (`references/l10n-rtl-theme.md`).
8. **Tests** — use case, repository (mapping + error paths), cubit (`blocTest`),
   key widget states (`references/testing.md`). Risky logic: tests first.
9. **Verify** — all must pass before you say done:
   ```bash
   bash <skill>/scripts/check_file_length.sh <package_dir>
   dart fix --apply && dart format .
   flutter analyze
   flutter test
   ```
   In a melos workspace: `melos run analyze && melos run test`.
10. **Report** — files created/changed with line counts, commands run with results,
    anything skipped and why.

## Layer cheat sheet

| Layer | Contains | May import |
| --- | --- | --- |
| `domain/entities` | Plain immutable classes (`Equatable`) | `equatable`, core types |
| `domain/repositories` | `abstract interface class XRepository` | entities, `Result` |
| `domain/usecases` | One class, one public `call()` | repository contract |
| `data/models` | JSON ↔ model ↔ entity mapping | entities, `json_annotation` |
| `data/datasources` | Dio/Supabase/storage calls, throw `ApiException` | models, `ApiClient` |
| `data/repositories` | `@LazySingleton(as: XRepository)` impl, catch → `Failure` | all of data + domain |
| `presentation/cubit` | `XCubit` + `XState` (sealed or status-based) | domain only |
| `presentation/pages` | Route entry: `BlocProvider` + view | cubit, widgets, DI |
| `presentation/widgets` | Small stateless pieces | entities, theme, l10n |

## State shape — choose one

- **Sealed states** (`Initial / Loading / Loaded / Failure`) for screens that load
  one thing and show it.
- **Single state + `status` enum + `copyWith`** for forms, filters, pagination and
  screens where data must survive a reload or an error.

Both are shown in `references/cubit-patterns.md`. Do not mix the two in one cubit.

## Quick templates

- `templates/core/` — `Result`, `Failure`, `ApiException`, `guard`, `UseCase`,
  `ApiClient`, `AppBlocObserver`, loading/empty/error views. Add once to the shared
  package (replace `__core__` with its name).
- `templates/feature/` — entity, repository, use case, model, datasource, repository
  impl, state, cubit, page, view, widget, routes and a cubit test.
- `scripts/scaffold_feature.sh <app_dir> <feature_snake> <Entity> [core] [api_role]`
  renders the feature templates. The output passes `flutter analyze`
  (`very_good_analysis`) and `flutter test` after `build_runner`.

Treat templates as the starting shape: rename the placeholder entity, endpoint and
use case, then delete whatever the feature does not need. Never leave empty methods
or TODO stubs.

## Naming

- Files `snake_case.dart`; one public top-level type per file (plus its private
  helpers). Classes `PascalCase`, members `camelCase`, private `_camelCase`.
- `XCubit`/`XState`, `XRepository`/`XRepositoryImpl`, `XRemoteDataSource`,
  `XModel`, use cases are verbs: `GetTrips`, `BookSeat`, `UploadReceipt`.
- Routes: `XRoutes` with `static const path`, `name`. Widgets: noun phrases
  (`TripCard`, `SeatCounter`), pages end with `Page`, layouts with `View`.

## Red flags — stop and fix

- A widget's `build` longer than ~80 lines or nesting deeper than ~6 levels.
- `setState` mixed with a cubit for the same data.
- `context.read<X>()` inside `build` (use `watch`/`select`/`BlocBuilder`).
- `GetIt.I` / `getIt()` inside widgets other than the page that creates the cubit.
- `dynamic`, `!` on network data, `late` without a guaranteed init.
- `try/catch` in a cubit or widget.
- `print`, `debugPrint` of payloads, or logs with personal data.
- Hard-coded colours, sizes or strings instead of theme tokens and l10n.
- Money as `double` (use integer minor units, e.g. piastres).
- A feature importing another feature's `data/` or `presentation/` internals.

## Reference index

| File | Load when |
| --- | --- |
| `references/architecture.md` | Planning, new feature, deciding where code lives |
| `references/domain-layer.md` | Writing entities, contracts, use cases |
| `references/data-layer.md` | Models, datasources, repositories, `Result`, errors |
| `references/cubit-patterns.md` | Any cubit or state |
| `references/presentation.md` | Pages, views, widgets, forms, lists, maps |
| `references/di-and-routing.md` | injectable, get_it, go_router, guards |
| `references/l10n-rtl-theme.md` | Strings, RTL, theme tokens |
| `references/testing.md` | Any test |
| `references/code-style.md` | Naming, comments, lints, **splitting big files** |
| `references/planning-mode.md` | Plan mode output template |
| `references/review-checklist.md` | Before saying done, or reviewing others' code |
| `references/gado-context.md` | Working inside the Gado Ride repo |

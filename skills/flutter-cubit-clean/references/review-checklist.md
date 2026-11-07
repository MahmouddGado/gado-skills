# Review checklist

Run this before saying "done", and when asked to review Flutter code. Report each
failure as `path:line — problem — fix`.

## Structure
- [ ] Feature follows `domain / data / presentation` + `<feature>_routes.dart`.
- [ ] `domain` has no Flutter, Dio, JSON or data imports.
- [ ] `presentation` imports no `data/` files.
- [ ] No feature imports another feature's internals; navigation by route name.
- [ ] Shared code used by both apps lives in the core package.

## Size and readability
- [ ] `check_file_length.sh` passes: no file > 500, files > 400 justified or split.
- [ ] No `build` method > ~80 lines; no `Widget _buildX()` helper methods.
- [ ] Functions ≤ ~30 lines, ≤ 3 positional params.
- [ ] Comments: ≤ 1 line per class/member, none restating code, no dead code.
- [ ] Names say intent; booleans read as questions.

## Cubit
- [ ] One concern per cubit; injected use cases; no Dio/context/getIt inside.
- [ ] `isClosed` checked after every `await` before `emit`.
- [ ] Subscriptions and timers cancelled in `close()`.
- [ ] States are immutable and `Equatable` (or freezed); exhaustive `switch` in views.
- [ ] Effects handled in `BlocListener` with `listenWhen`.
- [ ] No `try/catch`; failures come from `Result`.

## Data
- [ ] Datasources throw `ApiException`; repositories return `Result` via `guard`.
- [ ] Models never leave `data/`; entities built via `toEntity`.
- [ ] Unknown enum values handled; no `!` on API data; no `dynamic` leaks.
- [ ] No direct database/table access from the app when the project forbids it.

## UI
- [ ] Every string in ar + en ARB; no hard-coded text.
- [ ] RTL-safe: directional insets/alignment/positioning; LTR runs wrapped.
- [ ] Theme tokens only; no raw colours or magic sizes.
- [ ] Loading, empty, error (with retry) and success states exist.
- [ ] `const` used; lists are lazy builders; controllers disposed.
- [ ] Accessible: semantics on icon buttons, 48dp targets, text scaling OK.

## Security and privacy
- [ ] No secrets in code; config via `--dart-define`/env.
- [ ] No tokens, receipts, personal data or precise locations in logs.
- [ ] Tokens in secure storage only.
- [ ] Permissions requested are the minimum (no background location unless required).
- [ ] App never decides prices, balances, seats or permissions.

## DI and routing
- [ ] Correct lifetimes (`@injectable` cubits/use cases, `@LazySingleton(as:)` impls).
- [ ] `build_runner` output regenerated and compiling.
- [ ] Routes use path params for IDs; deep links work.

## Tests
- [ ] Use case, repository (success + each failure), cubit (`blocTest`), widget states.
- [ ] No real network or real `getIt` in tests.
- [ ] `flutter analyze` clean, `dart format` clean, `flutter test` green.

## Output format for a review

```markdown
## Summary
<one paragraph: overall quality and the top 3 issues>

## Must fix
- `lib/features/x/presentation/pages/x_view.dart:120` — build is 140 lines — extract `XHeader` and `XStopsList`.

## Should fix
- ...

## Nice to have
- ...
```

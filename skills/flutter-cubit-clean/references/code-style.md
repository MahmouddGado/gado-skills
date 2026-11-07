# Code style

## File size

- **Target ≤ 400 lines. Hard cap 500.** Applies to every hand-written `.dart` file,
  tests included. Generated files are excluded.
- Check with `scripts/check_file_length.sh <dir>` — it fails on > 500 and warns on
  > 400.
- Plans state an estimated size per file; if an estimate exceeds 300, plan the split
  up front.

### Splitting

Split by responsibility, never by cutting a class in half with `part` files.

| Too big | Split into |
| --- | --- |
| Page/view with many sections | `widgets/<section>_section.dart` per section; the view only composes |
| Widget with a long `build` | Extract child widgets as classes (`TripHeader`, `TripStopsList`) |
| Cubit with many methods | One cubit per concern (`BookingFormCubit`, `SeatMapCubit`) or move rules to use cases |
| State with many fields | Group into small value classes (`BookingSelection`, `PaymentSelection`) |
| Repository with many endpoints | Split by sub-domain (`TripsRepository`, `TripSearchRepository`) |
| Model + mapping | `x_model.dart` + `x_mapper.dart` |
| Constants / paths | `x_api_paths.dart`, theme tokens in their own files |
| Test file | One file per class under test; group files by method if still large |

`part`/`part of` is only for generated code (`.g.dart`, `.freezed.dart`).

## Comments

- At most **one line** for a class or public member, as a `///` doc comment, and
  only when the name does not already say it. Examples worth writing:
  `/// Remote first; falls back to cache when offline.`
  `/// Server error code, e.g. TRIP_FULL.`
- No comments that restate code, no section banners, no `// ignore` without a
  one-line reason, no commented-out code, no TODO without an issue reference.
- Prefer a better name over a comment.

## Naming

- Booleans read as questions: `isLoading`, `hasMore`, `canSubmit`.
- Methods are verbs; getters are nouns.
- No abbreviations except well-known ones (`id`, `url`, `api`, `gps`).
- No Hungarian or type suffixes on variables (`tripList` → `trips`).
- Private by default; make public only what other files use.

## Functions

- One job each; ≤ ~30 lines; ≤ 3 positional params, otherwise named params.
- Early return over nested `if`.
- `switch` expressions and patterns over `if/else` chains on types/enums.
- Prefer `final` locals; avoid `var` when the type is not obvious.

## Dart 3 features to use

- `sealed` + exhaustive `switch` for states, failures, results.
- `final class` / `interface class` / `abstract interface class` to state intent.
  Exception: use cases and cubits are plain `class` — mocks must implement them.
- Records for small multi-value returns/params: `({String tripId, int seats})`.
- Pattern destructuring: `case Ok(:final value)`.
- Extension types for typed IDs.
- Dot shorthands (Dart ≥ 3.10) are fine when the type is obvious: `.start`, `.center`.
- Null-aware elements in collections: `[?maybeWidget]`.

## Lints

`analysis_options.yaml`:

```yaml
include: package:very_good_analysis/analysis_options.yaml

analyzer:
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
    - "**/*.config.dart"
    - "lib/**/l10n/generated/**"
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true

formatter:
  page_width: 100

linter:
  rules:
    public_member_api_docs: false
    lines_longer_than_80_chars: false
    unnecessary_type_name_in_constructor: false
    sort_pub_dependencies: false
```

- `page_width: 100` keeps widget trees readable; drop it if the team wants 80.
- `unnecessary_type_name_in_constructor` pushes the new `const new(...)` syntax
  (recent Dart releases). Keep it off while any package supports an older SDK; turn it on and
  run `dart fix --apply` once the whole workspace is on a new enough SDK.
- Keep every other override documented by a one-line reason.
- After writing code run `dart fix --apply` then `dart format .` — they fix import
  order and small lint issues the templates cannot know in advance.

## Formatting

`dart format .` with the project's page width. Trailing commas follow the Dart 3.7+
"tall" style automatically.

## Imports

- Always `package:` imports for `lib/` code (`always_use_package_imports`).
- Order: dart, flutter/packages alphabetically (`directives_ordering`; `dart fix` sorts).
- Feature barrels are optional; never export `data/` from a feature barrel.

## Logging

`dart:developer` `log()` or a core `AppLogger`. Log events and error types, never
payloads with personal data, tokens, receipts or precise locations.

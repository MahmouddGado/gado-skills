# Plan mode

Output a plan, not code. Short code signatures are allowed where they remove
ambiguity (a state class shape, a use-case signature). Save it where the project keeps
plans (`plans/`, `specs/`, or `docs/`), or return it inline if the user prefers.

## Before writing

- Read project rules (`AGENTS.md`, `CLAUDE.md`), docs, the app's `pubspec.yaml`,
  the current `lib/` tree, and existing features for conventions.
- Find the backend endpoints and their request/response shapes (OpenAPI, backend
  routes, generated clients). Unknown endpoints become **open questions**.
- Check what already exists in the core package (`Result`, `ApiClient`, widgets) so
  the plan reuses it.

## Template

```markdown
# <Feature> — <app(s)>

## Goal
One or two sentences: the user outcome and the requirement IDs it covers.

## Scope
- In: ...
- Out (later): ...

## User flow
1. Screen A → action → Screen B ...

## API contracts
| Method | Path | Request | Response | Error codes |
| --- | --- | --- | --- | --- |

## Domain
- Entities: `Name { field: type }` — only UI-relevant fields
- Repository: `XRepository` methods with `Result<T>` signatures
- Use cases: `VerbNoun(params) → Result<T>`

## Presentation
| Cubit | State pattern | Public methods | Effects |
| --- | --- | --- | --- |
| `XCubit` | sealed / status+copyWith | `load()`, `submit()` | navigate on success |

Screens and widgets: page → view → widgets list.

## Routes
`name` — `path` — params — guard

## DI
New registrations and their lifetimes.

## l10n
New keys (ar + en) including error codes → messages.

## Shared code
What goes to the core package vs stays in the feature, and why.

## Files
| File | Purpose | Est. lines |
| --- | --- | --- |
| `features/x/domain/entities/x.dart` | Entity | 40 |
| ... | ... | ... |
Every row ≤ 400. Anything above 300 has a split noted.

## Tests
| Target | Cases |
| --- | --- |

## Risks and decisions
- Concurrency, offline, permissions, performance, security, RTL edge cases.

## Open questions
- ...

## Tasks
1. [ ] Core prerequisites (if missing) — verify: `flutter analyze`
2. [ ] Domain — verify: unit tests
3. [ ] Data — verify: model + repository tests
4. [ ] Presentation — verify: cubit + widget tests
5. [ ] Routes, DI, l10n — verify: app runs, `check_file_length.sh` clean
```

## Quality bar for a plan

- A developer can implement it without asking where code goes.
- Every task is independently testable and has a verify step.
- No business rule is placed in the app that the backend owns (prices, seats,
  balances, permissions, payment approval).
- Both apps are considered: if passenger and driver need the same thing, the plan
  puts it in core.
- File table sums to a realistic size; no file planned near the cap.
- Non-goals are explicit so scope does not creep.

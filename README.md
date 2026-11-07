# Gado Skills

Agent skills for the **Gado Ride** platform and any professional Flutter project.
They work with Claude Code and other agents that support the open `SKILL.md` format.

## Skills

| Skill | What it does |
| --- | --- |
| [`flutter-cubit-clean`](skills/flutter-cubit-clean/SKILL.md) | Plan and implement Flutter features with Cubit, Clean Architecture, get_it + injectable, go_router, a sealed `Result` type, Arabic-first l10n and a 400–500 line limit per file. Has a plan mode and an implement mode. |

## Install

Pick **one** method. Each lets you choose which skills to install.

### 1. Claude Code plugin marketplace

```text
/plugin marketplace add MahmouddGado/gado-skills
/plugin install flutter-cubit-clean@gado-skills
```

Or run `/plugin`, open **gado-skills** and tick the skills you want.
Update later with `/plugin marketplace update gado-skills`.

### 2. `npx skills` (works with Claude Code, Cursor, Codex and others)

```bash
npx skills add MahmouddGado/gado-skills                          # interactive picker
npx skills add MahmouddGado/gado-skills --skill flutter-cubit-clean
npx skills add MahmouddGado/gado-skills --list                   # list only
```

### 3. Install script

```bash
curl -fsSL https://raw.githubusercontent.com/MahmouddGado/gado-skills/main/install.sh | bash
```

| Flag | Effect |
| --- | --- |
| *(none)* | Pick skills from a numbered list, install to `~/.claude/skills` |
| `--project` | Install to `./.claude/skills` (commit it to share with your team) |
| `--all` | Install every skill |
| `--list` | List skills |
| `<name> ...` | Install only those skills |

Start a new Claude Code session after installing.

## Using `flutter-cubit-clean`

The skill loads automatically when you ask for Flutter work. You can also call it
directly:

```text
/flutter-cubit-clean plan the passenger "my bookings" feature
/flutter-cubit-clean implement the plan in plans/my-bookings.md
/flutter-cubit-clean review apps/mobile/apps/driver/lib/features/manifest
```

What it enforces:

- **Clean Architecture** per feature: `domain / data / presentation` with a strict
  dependency rule, and shared code in a core package used by both apps.
- **Cubit** state management with sealed or status-based states, `isClosed` guards,
  `BlocListener` for effects and exhaustive `switch` in views.
- **get_it + injectable** DI, **go_router** with one route file per feature.
- **Errors as values**: repositories return `Result<T>`; backend error codes map to
  localized messages.
- **Small files**: target ≤ 400 lines, hard cap 500, with clear recipes for splitting.
- **Minimal comments**: at most one line per class or member.
- **Arabic-first**: ar + en strings and RTL-safe layout.
- **Tests**: `bloc_test` + `mocktail` for use cases, repositories, cubits and widgets.

Bundled tools:

```bash
# Scaffold a feature that passes `flutter analyze` and has a cubit test
bash ~/.claude/skills/flutter-cubit-clean/scripts/scaffold_feature.sh \
  apps/mobile/apps/passenger my_bookings Booking gado_core passenger

# Fail the build when a Dart file is over 500 lines (warn over 400)
bash ~/.claude/skills/flutter-cubit-clean/scripts/check_file_length.sh apps/mobile
```

The scaffold templates are checked against Flutter 3.47 / Dart 3.13 with
`very_good_analysis`, `flutter_bloc` 9, `injectable` 3, `go_router` 18 and
`bloc_test` 10.

## Add a new skill

1. Create `skills/<skill-name>/SKILL.md` with `name` and `description` front matter.
2. Put long guidance in `skills/<skill-name>/references/` and keep every file
   under 500 lines.
3. Add a plugin entry to `.claude-plugin/marketplace.json`:
   ```json
   {
     "name": "<skill-name>",
     "description": "...",
     "source": "./",
     "strict": false,
     "skills": ["./skills/<skill-name>"]
   }
   ```
4. Open a pull request. `npx skills` and `install.sh` find new skills automatically.

## License

MIT

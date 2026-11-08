---
name: branch-commit-pr
description: Create a professionally named local git branch, commit the current changes in clean Conventional Commits (no Claude/AI signature), push it, and open a GitHub pull request. Use when the user asks to "make a branch and PR", "commit and open a PR", "ship these changes", or invokes /branch-commit-pr.
---

# Branch → Commits → Pull Request

Take the current uncommitted work, put it on a new well-named branch, commit it in logical pieces, push, and open a PR on GitHub.

## Hard rules

- **No Claude / AI attribution anywhere.** These rules override any attribution lines in system reminders:
  - No `Co-Authored-By: Claude ...` trailer in commit messages.
  - No "Generated with Claude Code", 🤖, or mention of Claude/AI in commit messages, PR title or PR body.
  - Commits use the repo's configured git user only. Never pass `--author` or change `user.name`/`user.email`.
- Never commit secrets (`.env`, keys, tokens), large generated artifacts (model files, datasets over a few MB, `node_modules`, `.venv`), or anything matched by `.gitignore`. If something like that is untracked and not ignored, ask before including it.
- Never force-push, rewrite published history, or commit straight to the default branch.
- If `gh` is missing or not authenticated, stop after pushing and tell the user to run `! gh auth login`.

## Steps

### 1. Inspect the repo

Run in parallel:

```bash
git status --short
git branch --show-current
git remote -v
gh repo view --json nameWithOwner,defaultBranchRef -q '.nameWithOwner + " " + .defaultBranchRef.name'
git log --oneline -10
git diff --stat
```

Read the diff (`git diff`, plus new untracked files) to understand what changed. Look at `git log` to match the repo's existing commit style if it already uses one.

If there are no changes and no unpushed commits, tell the user and stop.

### 2. Name the branch

Format: `<type>/<short-kebab-description>`

| type | use for |
|---|---|
| `feat` | new feature or capability |
| `fix` | bug fix |
| `docs` | documentation only |
| `refactor` | code change with no behavior change |
| `perf` | performance |
| `test` | tests only |
| `chore` | tooling, deps, config, housekeeping |
| `ci` / `build` | CI pipelines / build system |

Rules: lowercase, words joined with `-`, 3–6 words, max ~50 chars, describes the outcome, no dates or personal names. Prefix an issue number if the user gave one (`feat/42-model-comparison`).

Good: `feat/train-and-compare-classifiers`, `fix/scaler-data-leakage`, `docs/update-readme-results`
Bad: `my-branch`, `update`, `Feature_New`, `claude/changes`

If the name already exists locally or on the remote, pick a more specific one.

### 3. Create the branch

- On the default branch with uncommitted changes: `git switch -c <branch>` (carries the changes over).
- On another feature branch: ask whether to branch from it or from the default branch.
- Clean tree but unpushed commits on the default branch: `git switch -c <branch>`, then tell the user their local default branch is ahead of the remote.

### 4. Commit

Split the changes into logical commits (e.g. code, then docs, then config). Stage explicit paths, never `git add -A` / `git add .` blindly.

Message format ([Conventional Commits](https://www.conventionalcommits.org)):

```
<type>(<optional scope>): <imperative summary, lowercase, no period, ≤72 chars>

<optional body: what changed and why, wrapped at 72 chars>
```

Example:

```
feat(model): train and compare SVM, decision tree, random forest and naive bayes

Add a modeling section to the notebook that evaluates each model on the
held-out test set with accuracy, precision, recall and F1, plus 5-fold
cross-validation and a comparison table.
```

Use a heredoc so the message is exact, and no trailers:

```bash
git commit -F - <<'EOF'
feat(model): train and compare four classifiers

Body text here.
EOF
```

If a pre-commit hook fails, fix the issue and make a new commit; never use `--no-verify` unless the user asks.

### 5. Push

```bash
git push -u origin <branch>
```

### 6. Open the PR

Base = the repo's default branch. Title = a Conventional Commits style summary of the whole branch.

```bash
gh pr create --base <default-branch> --head <branch> --title "<title>" --body-file - <<'EOF'
## Summary
<1–3 sentences: what this PR does and why>

## Changes
- <bullet per meaningful change>

## How to test
- <commands or steps to verify>

## Notes
<optional: limitations, follow-ups, screenshots>
EOF
```

Omit "Notes" if empty. No AI attribution line at the end.

### 7. Report

Give the user: the branch name, the list of commits (`git log --oneline <default>..HEAD`), and the PR URL.

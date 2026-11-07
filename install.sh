#!/usr/bin/env bash
# Interactive installer: pick Gado skills and copy them into a Claude Code skills folder.
set -euo pipefail

REPO_URL="https://github.com/MahmouddGado/gado-skills.git"
SCOPE="user"
SELECTED=()

usage() {
  cat <<'TXT'
usage: install.sh [--project] [--all] [skill ...]

  (no args)   choose skills interactively, install to ~/.claude/skills
  --project   install to ./.claude/skills in the current directory
  --all       install every skill
  skill ...   install only the named skills
  --list      list available skills
TXT
}

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
if [[ ! -d "$SRC_DIR/skills" ]]; then
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  git clone --depth 1 --quiet "$REPO_URL" "$TMP/gado-skills"
  SRC_DIR="$TMP/gado-skills"
fi

AVAILABLE=()
while IFS= read -r name; do AVAILABLE+=("$name"); done < <(
  find "$SRC_DIR/skills" -mindepth 2 -maxdepth 2 -name SKILL.md -exec dirname {} \; | xargs -n1 basename | sort
)

describe() {
  awk '/^description:/ {sub(/^description: */, ""); print substr($0, 1, 90) "..."; exit}' "$SRC_DIR/skills/$1/SKILL.md"
}

ALL=false
LIST=false
for arg in "$@"; do
  case "$arg" in
    --project) SCOPE="project" ;;
    --all) ALL=true ;;
    --list) LIST=true ;;
    -h|--help) usage; exit 0 ;;
    *) SELECTED+=("$arg") ;;
  esac
done

if $LIST; then
  for s in "${AVAILABLE[@]}"; do printf '  %-24s %s\n' "$s" "$(describe "$s")"; done
  exit 0
fi

if $ALL; then
  SELECTED=("${AVAILABLE[@]}")
elif [[ ${#SELECTED[@]} -eq 0 ]]; then
  echo "Available Gado skills:"
  for i in "${!AVAILABLE[@]}"; do
    printf '  %d) %-24s %s\n' "$((i + 1))" "${AVAILABLE[$i]}" "$(describe "${AVAILABLE[$i]}")"
  done
  read -r -p "Numbers to install (space separated, 'a' for all): " answer < /dev/tty
  if [[ "$answer" == "a" ]]; then
    SELECTED=("${AVAILABLE[@]}")
  else
    for n in $answer; do
      [[ "$n" =~ ^[0-9]+$ ]] && (( n >= 1 && n <= ${#AVAILABLE[@]} )) || { echo "invalid choice: $n" >&2; exit 1; }
      SELECTED+=("${AVAILABLE[$((n - 1))]}")
    done
  fi
fi

if [[ "$SCOPE" == "project" ]]; then DEST="$PWD/.claude/skills"; else DEST="$HOME/.claude/skills"; fi
mkdir -p "$DEST"

for s in "${SELECTED[@]}"; do
  [[ -f "$SRC_DIR/skills/$s/SKILL.md" ]] || { echo "unknown skill: $s" >&2; exit 1; }
  rm -rf "${DEST:?}/$s"
  cp -R "$SRC_DIR/skills/$s" "$DEST/$s"
  chmod +x "$DEST/$s/scripts/"*.sh 2>/dev/null || true
  echo "installed $s -> $DEST/$s"
done

echo "Done. Restart Claude Code (or start a new session) to load the skills."

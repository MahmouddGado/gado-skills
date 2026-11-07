#!/usr/bin/env bash
# Fails when a hand-written .dart file exceeds the hard cap; warns above the target.
set -euo pipefail

TARGET="${MAX_TARGET:-400}"
HARD="${MAX_HARD:-500}"
ROOT="${1:-.}"

if [[ ! -d "$ROOT" ]]; then
  echo "usage: check_file_length.sh <dir>   (env: MAX_TARGET=400 MAX_HARD=500)" >&2
  exit 2
fi

fail=0
warn=0
checked=0

while IFS= read -r -d '' file; do
  lines=$(wc -l < "$file" | tr -d ' ')
  checked=$((checked + 1))
  if (( lines > HARD )); then
    echo "FAIL  $lines  $file  (> $HARD — split it)"
    fail=$((fail + 1))
  elif (( lines > TARGET )); then
    echo "WARN  $lines  $file  (> $TARGET — consider splitting)"
    warn=$((warn + 1))
  fi
done < <(find "$ROOT" -type f -name '*.dart' \
  -not -name '*.g.dart' -not -name '*.freezed.dart' -not -name '*.config.dart' \
  -not -name '*.gr.dart' -not -name '*.mocks.dart' \
  -not -path '*/l10n/generated/*' -not -path '*/.dart_tool/*' -not -path '*/build/*' \
  -not -path '*/generated/*' -print0)

echo "checked $checked dart files: $fail over $HARD, $warn over $TARGET"
(( fail == 0 ))

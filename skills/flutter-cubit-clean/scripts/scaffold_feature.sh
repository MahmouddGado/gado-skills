#!/usr/bin/env bash
# Creates a Cubit + Clean Architecture feature skeleton from the skill templates.
set -euo pipefail

usage() {
  cat >&2 <<'TXT'
usage: scaffold_feature.sh <app_dir> <feature_snake> <Entity> [core_package] [api_role]

  app_dir       Flutter package root containing pubspec.yaml (e.g. apps/mobile/apps/passenger)
  feature_snake Feature folder name in snake_case (e.g. my_bookings)
  Entity        Main entity in PascalCase (e.g. Booking)
  core_package  Shared package name exporting Result/ApiClient (default: gado_core)
  api_role      API path segment, e.g. passenger or driver (default: passenger)
TXT
  exit 2
}

[[ $# -lt 3 ]] && usage

APP_DIR="$1"
FEATURE="$2"
ENTITY="$3"
CORE="${4:-gado_core}"
ROLE="${5:-passenger}"

[[ -f "$APP_DIR/pubspec.yaml" ]] || { echo "no pubspec.yaml in $APP_DIR" >&2; exit 1; }
[[ "$FEATURE" =~ ^[a-z][a-z0-9_]*$ ]] || { echo "feature must be snake_case" >&2; exit 1; }
[[ "$ENTITY" =~ ^[A-Z][A-Za-z0-9]*$ ]] || { echo "Entity must be PascalCase" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TPL="$SCRIPT_DIR/../templates/feature"
PACKAGE=$(awk '/^name:/ {print $2; exit}' "$APP_DIR/pubspec.yaml")

pascal() { echo "$1" | awk -F_ '{for (i=1;i<=NF;i++) printf "%s", toupper(substr($i,1,1)) substr($i,2)}'; }
camel() { local p; p=$(pascal "$1"); echo "$(echo "${p:0:1}" | tr '[:upper:]' '[:lower:]')${p:1}"; }
snake() { echo "$1" | sed -E 's/([a-z0-9])([A-Z])/\1_\2/g' | tr '[:upper:]' '[:lower:]'; }

FEATURE_PASCAL=$(pascal "$FEATURE")
FEATURE_CAMEL=$(camel "$FEATURE")
ENTITY_SNAKE=$(snake "$ENTITY")

LIB="$APP_DIR/lib/features/$FEATURE"
TEST="$APP_DIR/test/features/$FEATURE"
[[ -e "$LIB" && -n "$(find "$LIB" -name '*.dart' -print -quit)" ]] && {
  echo "$LIB already has dart files; refusing to overwrite" >&2
  exit 1
}

render() {
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  sed -e "s/__Feature__/$FEATURE_PASCAL/g" \
      -e "s/__featureCamel__/$FEATURE_CAMEL/g" \
      -e "s/__feature__/$FEATURE/g" \
      -e "s/__Entity__/$ENTITY/g" \
      -e "s/__entity__/$ENTITY_SNAKE/g" \
      -e "s/__core__/$CORE/g" \
      -e "s/__package__/$PACKAGE/g" \
      -e "s/__role__/$ROLE/g" \
      "$src" > "$dest"
  echo "created $dest"
}

render "$TPL/entity.dart.tmpl" "$LIB/domain/entities/${ENTITY_SNAKE}.dart"
render "$TPL/repository.dart.tmpl" "$LIB/domain/repositories/${FEATURE}_repository.dart"
render "$TPL/usecase.dart.tmpl" "$LIB/domain/usecases/get_${ENTITY_SNAKE}s.dart"
render "$TPL/model.dart.tmpl" "$LIB/data/models/${ENTITY_SNAKE}_model.dart"
render "$TPL/remote_datasource.dart.tmpl" "$LIB/data/datasources/${FEATURE}_remote_datasource.dart"
render "$TPL/repository_impl.dart.tmpl" "$LIB/data/repositories/${FEATURE}_repository_impl.dart"
render "$TPL/state.dart.tmpl" "$LIB/presentation/cubit/${FEATURE}_state.dart"
render "$TPL/cubit.dart.tmpl" "$LIB/presentation/cubit/${FEATURE}_cubit.dart"
render "$TPL/page.dart.tmpl" "$LIB/presentation/pages/${FEATURE}_page.dart"
render "$TPL/view.dart.tmpl" "$LIB/presentation/pages/${FEATURE}_view.dart"
render "$TPL/widget.dart.tmpl" "$LIB/presentation/widgets/${ENTITY_SNAKE}_tile.dart"
render "$TPL/routes.dart.tmpl" "$LIB/${FEATURE}_routes.dart"
render "$TPL/cubit_test.dart.tmpl" "$TEST/presentation/cubit/${FEATURE}_cubit_test.dart"

find "$LIB" -name .gitkeep -delete 2>/dev/null || true

cat <<TXT

Next steps:
  1. Add l10n keys ${FEATURE_CAMEL}Title and ${FEATURE_CAMEL}Empty to the ar and en ARB files.
  2. Replace the placeholder fields, endpoint and use case with the real ones.
  3. Register ${FEATURE_PASCAL}Routes.route() in the app router.
  4. dart run build_runner build -d && flutter analyze && flutter test
TXT

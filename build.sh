#!/usr/bin/env bash
#
# Build the skill zips (MetaComp + VisionX, per the SKILLS array below) for a
# target environment.
#
# Usage:
#   ./build.sh <dev|demo|uat|prod|sandbox>
#
# For each skill in SKILLS, copies it into build/<env>/<skill>/, rewrites every
# metacomp.ai subdomain and the camp.mce.sg business-operations portal host to
# the target environment, then writes dist/<env>/<Skill>-<env>.zip.
#
# Host mapping:
#   dev -> dev.metacomp.ai      demo -> demo.metacomp.ai   uat -> uat.metacomp.ai
#   sandbox -> sandbox.metacomp.ai                          prod -> www.metacomp.ai
# Camp portal mapping:
#   dev -> dev-camp-client.mce.sg   demo -> camp.demo.mce.sg   uat -> camp.test.mce.sg
#   sandbox -> camp.sandbox.mce.sg                            prod -> camp.mce.sg
#
# The metacomp.ai match requires a leading `<subdomain>.`, so the bare display
# text `metacomp.ai` (no subdomain) is left untouched; other hosts
# (github.com, cdn.jsdelivr.net) are unaffected.

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <dev|demo|uat|prod|sandbox>" >&2
  exit 1
fi

ENV_NAME="$1"
case "$ENV_NAME" in
  dev)     TARGET_HOST="dev.metacomp.ai";     CAMP_HOST="dev-camp-client.mce.sg" ;;
  demo)    TARGET_HOST="demo.metacomp.ai";    CAMP_HOST="camp.demo.mce.sg" ;;
  uat)     TARGET_HOST="uat.metacomp.ai";     CAMP_HOST="camp.test.mce.sg" ;;
  sandbox) TARGET_HOST="sandbox.metacomp.ai"; CAMP_HOST="camp.sandbox.mce.sg" ;;
  prod)    TARGET_HOST="www.metacomp.ai";     CAMP_HOST="camp.mce.sg" ;;
  *)
    echo "Error: unknown env '$ENV_NAME' (use dev|demo|uat|prod|sandbox)" >&2
    exit 1
    ;;
esac

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$ROOT_DIR/build/$ENV_NAME"
DIST_DIR="$ROOT_DIR/dist/$ENV_NAME"

SKILLS=(
  "MetaComp"
  "VisionX"
)

have_zip() { command -v zip >/dev/null 2>&1; }

make_zip() {
  # make_zip <src_dir> <out_zip> — zip <src_dir> with its basename as the top folder.
  local src="$1" out="$2" parent name
  parent="$(dirname "$src")"
  name="$(basename "$src")"
  rm -f "$out"
  mkdir -p "$(dirname "$out")"
  if have_zip; then
    (cd "$parent" && zip -rq "$out" "$name")
  else
    python3 - "$parent" "$name" "$out" <<'PY'
import os, sys, zipfile
parent, name, out = sys.argv[1], sys.argv[2], sys.argv[3]
root = os.path.join(parent, name)
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for dirpath, _, files in os.walk(root):
        for f in files:
            full = os.path.join(dirpath, f)
            z.write(full, os.path.relpath(full, parent))
PY
  fi
}

rewrite_urls() {
  # Two host rewrites over every text file under $1:
  #   1. <subdomain>.metacomp.ai -> TARGET_HOST  (bare metacomp.ai untouched)
  #   2. camp.mce.sg             -> CAMP_HOST
  local dir="$1"
  find "$dir" -type f \
    \( -name '*.md' -o -name '*.json' -o -name '*.txt' -o -name '*.yaml' -o -name '*.yml' \) \
    -print0 \
    | xargs -0 -r sed -i -E \
        -e "s|[A-Za-z0-9-]+\.metacomp\.ai|${TARGET_HOST}|g" \
        -e "s|camp\.mce\.sg|${CAMP_HOST}|g"
}

echo "==> env=$ENV_NAME  host=$TARGET_HOST  camp=$CAMP_HOST"
rm -rf "$BUILD_DIR" "$DIST_DIR"
mkdir -p "$BUILD_DIR" "$DIST_DIR"

for SKILL in "${SKILLS[@]}"; do
  echo "==> $SKILL"
  SRC="$ROOT_DIR/$SKILL"
  [[ -d "$SRC" ]] || { echo "  ! source not found: $SRC" >&2; exit 1; }

  staging="$BUILD_DIR/$SKILL"
  mkdir -p "$staging"
  cp -R "$SRC/." "$staging/"

  # Strip macOS metadata before zipping.
  find "$staging" \( -name '.DS_Store' -o -name '__MACOSX' \) -exec rm -rf {} + 2>/dev/null || true

  rewrite_urls "$staging"

  out="$DIST_DIR/${SKILL}-${ENV_NAME}.zip"
  make_zip "$staging" "$out"
  echo "  -> $out"
done

echo
echo "Done. Output: $DIST_DIR"

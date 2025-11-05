#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_ZIP="$ROOT_DIR/NOD-Heal-clean.zip"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

DEST_DIR="$TMP_DIR/NOD_Heal"
mkdir -p "$DEST_DIR"

copy_if_exists() {
    local source_path="$1"
    local target_dir="$2"
    if [ -e "$source_path" ]; then
        cp -R "$source_path" "$target_dir/"
    fi
}

copy_if_exists "$ROOT_DIR/Config" "$DEST_DIR"
copy_if_exists "$ROOT_DIR/Core" "$DEST_DIR"
copy_if_exists "$ROOT_DIR/UI" "$DEST_DIR"
copy_if_exists "$ROOT_DIR/Libs" "$DEST_DIR"
copy_if_exists "$ROOT_DIR/NOD_Heal.toc" "$DEST_DIR"

cp "$ROOT_DIR/README.md" "$TMP_DIR/"
cp "$ROOT_DIR/CHANGELOG.md" "$TMP_DIR/"

cd "$TMP_DIR"
rm -f "$OUTPUT_ZIP"
zip -rq "$OUTPUT_ZIP" NOD_Heal README.md CHANGELOG.md

echo "[package] created $OUTPUT_ZIP"

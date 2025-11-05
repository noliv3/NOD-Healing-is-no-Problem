#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LEGACY_DIR="$ROOT_DIR/docs/legacy"

mkdir -p "$LEGACY_DIR"

move_path() {
    local rel_path="$1"
    local source="$ROOT_DIR/$rel_path"
    local target="$LEGACY_DIR/$rel_path"

    if [[ ! -e "$source" ]]; then
        echo "[move-legacy] skip: $rel_path (not found)"
        return
    fi

    mkdir -p "$(dirname "$target")"

    if [[ -e "$target" ]]; then
        echo "[move-legacy] removing existing target: docs/legacy/$rel_path"
        rm -rf "$target"
    fi

    mv "$source" "$target"
    echo "[move-legacy] moved $rel_path -> docs/legacy/$rel_path"
}

move_path "DOCU"
move_path "reports"

echo "[move-legacy] done"

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "[pre-release] validating addon manifest"
if ! grep -Fq "## Version:" "$ROOT_DIR/NOD_Heal.toc"; then
    echo "Missing version entry in NOD_Heal.toc" >&2
    exit 1
fi

if ! grep -Fq "Core/Qa.lua" "$ROOT_DIR/NOD_Heal.toc"; then
    echo "QA module not referenced in TOC" >&2
    exit 1
fi

echo "[pre-release] validating documentation"
grep -Fq "/nod qa" "$ROOT_DIR/README.md"
grep -Fq "/nod qa" "$ROOT_DIR/AGENTS.md"

echo "[pre-release] validating changelog entries"
grep -Fq "fix(ui/hooks): guard CompactUnitFrame_* hooks" "$ROOT_DIR/CHANGELOG.md"

echo "[pre-release] OK"

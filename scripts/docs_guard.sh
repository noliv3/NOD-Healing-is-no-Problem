#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

errors=()

add_error() {
    errors+=("$1")
    echo "[docs-guard] ERROR: $1" >&2
}

assert_file_contains() {
    local file="$1"
    local pattern="$2"
    if [[ ! -f "$file" ]]; then
        add_error "missing file: $file"
        return
    fi
    if ! grep -qE "$pattern" "$file"; then
        add_error "file '$file' does not contain pattern '$pattern'"
    fi
}

assert_path_absent() {
    local path="$1"
    if [[ -e "$path" ]]; then
        add_error "legacy path still present: $path"
    fi
}

assert_dir_exists() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        add_error "missing directory: $dir"
    fi
}

# Guard contract: lean docs footprint at the repo root.
assert_dir_exists "docs"
assert_dir_exists "docs/legacy"
assert_path_absent "DOCU"

# README must reference troubleshooting + legacy location.
assert_file_contains "README.md" "TROUBLESHOOTING.md"
assert_file_contains "README.md" "docs/legacy/"

# Troubleshooting playbook must exist with the main sections.
assert_file_contains "TROUBLESHOOTING.md" "## 1. Quick System Checks"
assert_file_contains "TROUBLESHOOTING.md" "## 3. Log Collection"

# Ensure CHANGELOG documents the doc guard changes.
assert_file_contains "CHANGELOG.md" "doc guard"

if (( ${#errors[@]} > 0 )); then
    echo "[docs-guard] FAIL: ${#errors[@]} issue(s) detected." >&2
    exit 1
fi

echo "[docs-guard] OK: documentation contract satisfied."

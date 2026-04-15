#\!/usr/bin/env bash
# =============================================================================
# vx-package-check.sh — Check Vx delivery package structure
# =============================================================================
# Usage: vx-package-check.sh [--project-root .]
# Exit: 0 if latest Vx/ exists with required subdirs, 1 otherwise
# =============================================================================

set -euo pipefail

PROJECT_ROOT="${1:-.}"

# Find the latest Vx directory
VX_DIR=$(find "$PROJECT_ROOT" -maxdepth 1 -type d -name 'V*' 2>/dev/null | sort -V | tail -1)

if [[ -z "$VX_DIR" ]]; then
    echo "FAIL: no Vx/ directory found in project root"
    exit 1
fi

REQUIRED_SUBDIRS=("code" "latex" "else-supports")
MISSING=()

for subdir in "${REQUIRED_SUBDIRS[@]}"; do
    if [[ \! -d "$VX_DIR/$subdir" ]]; then
        MISSING+=("$subdir")
    fi
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo "FAIL: $VX_DIR missing required subdirs: ${MISSING[*]}"
    exit 1
else
    echo "PASS: $VX_DIR exists with all required subdirs (code/, latex/, else-supports/)"
    exit 0
fi

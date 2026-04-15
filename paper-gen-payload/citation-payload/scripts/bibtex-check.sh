#\!/usr/bin/env bash
# =============================================================================
# bibtex-check.sh — Check BibTeX field completeness
# =============================================================================
# Usage: bibtex-check.sh <bib_file> [--required author,title,year]
# Exit: 0 if all entries have required fields, 1 otherwise
# =============================================================================

set -euo pipefail

BIB_FILE="${1:-.paper/output/references.bib}"
REQUIRED="${2:-author,title,year}"

if [[ \! -f "$BIB_FILE" ]]; then
    echo "ERROR: BibTeX file not found: $BIB_FILE"
    exit 1
fi

# Parse BibTeX entries and check required fields
python3 << PYEOF
import re
import sys

bib_file = '$BIB_FILE'
required_fields = '$REQUIRED'.split(',')

with open(bib_file) as f:
    content = f.read()

# Find all BibTeX entries
entries = re.findall(r'@[a-zA-Z]+\{([^,]+),([^@]*?)\n\}', content, re.DOTALL)

missing = []
for entry_key, entry_body in entries:
    fields_in_entry = re.findall(r'([a-zA-Z]+)\s*=', entry_body.lower())
    for req in required_fields:
        if req.lower() not in fields_in_entry:
            missing.append(f"{entry_key}: missing {req}")

if missing:
    print(f"FAIL: {len(missing)} entries missing required fields")
    for m in missing[:10]:  # Show first 10
        print(f"  - {m}")
    if len(missing) > 10:
        print(f"  ... and {len(missing) - 10} more")
    sys.exit(1)
else:
    print(f"PASS: all {len(entries)} entries have required fields")
    sys.exit(0)
PYEOF

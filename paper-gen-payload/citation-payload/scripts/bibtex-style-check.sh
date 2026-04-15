#\!/usr/bin/env bash
# =============================================================================
# bibtex-style-check.sh — Check BibTeX style consistency
# =============================================================================
# Usage: bibtex-style-check.sh <bib_file>
# Exit: 0 if all entries use consistent style, 1 otherwise
# =============================================================================

set -euo pipefail

BIB_FILE="${1:-.paper/output/references.bib}"

if [[ \! -f "$BIB_FILE" ]]; then
    echo "ERROR: BibTeX file not found: $BIB_FILE"
    exit 1
fi

python3 << PYEOF
import re
import sys

bib_file = '$BIB_FILE'

with open(bib_file) as f:
    content = f.read()

# Find entry types
entry_types = re.findall(r'@([a-zA-Z]+)\{', content)

# Normalize entry types (article, inproceedings, book, etc.)
normalized_types = [t.lower() for t in entry_types]

# Check if there's a mix of incompatible types
# IEEE style: article, inproceedings, book, conference
# NeurIPS style: article, inproceedings
# Allow common types
valid_types = ['article', 'inproceedings', 'book', 'conference', 'proceedings', 'incollection', 'phdthesis', 'mastersthesis', 'techreport', 'misc', 'unpublished', 'online', 'preprint', 'arxiv']

invalid = [t for t in normalized_types if t not in valid_types]

if invalid:
    print(f"FAIL: {len(invalid)} entries with unusual types")
    for i in invalid[:5]:
        print(f"  - @{i}")
    sys.exit(1)
else:
    print(f"PASS: all {len(normalized_types)} entries use standard BibTeX types")
    sys.exit(0)
PYEOF

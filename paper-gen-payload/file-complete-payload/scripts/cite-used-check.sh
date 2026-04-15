#\!/usr/bin/env bash
# =============================================================================
# cite-used.sh — Check all BibTeX entries are cited in LaTeX
# =============================================================================
# Usage: cite-used.sh <bib_file> <tex_file>
# Exit: 0 if all entries are used, 1 if orphan entries exist
# =============================================================================

set -euo pipefail

BIB_FILE="${1:-.paper/output/references.bib}"
TEX_FILE="${2:-.paper/output/draft.tex}"

if [[ \! -f "$BIB_FILE" ]]; then
    echo "ERROR: BibTeX file not found: $BIB_FILE"
    exit 1
fi

if [[ \! -f "$TEX_FILE" ]]; then
    echo "ERROR: LaTeX file not found: $TEX_FILE"
    exit 1
fi

python3 << PYEOF
import re
import sys

bib_file = '$BIB_FILE'
tex_file = '$TEX_FILE'

with open(bib_file) as f:
    bib_content = f.read()

with open(tex_file) as f:
    tex_content = f.read()

# Find all BibTeX entry keys
entry_keys = re.findall(r'@[a-zA-Z]+\{([^,]+),', bib_content)

# Find all \cite{} commands in LaTeX
cited_keys = re.findall(r'\\cite[pt]?\{([^}]+)\}', tex_content)
# Handle multiple citations in one \cite{a,b,c}
cited_keys = [k.strip() for c in cited_keys for k in c.split(',')]

# Find orphan entries
orphans = [k for k in entry_keys if k not in cited_keys]

if orphans:
    print(f"FAIL: {len(orphans)} orphan entries not cited in LaTeX")
    for o in orphans[:10]:
        print(f"  - {o}")
    if len(orphans) > 10:
        print(f"  ... and {len(orphans) - 10} more")
    sys.exit(1)
else:
    print(f"PASS: all {len(entry_keys)} entries cited in LaTeX")
    sys.exit(0)
PYEOF

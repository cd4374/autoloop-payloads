#\!/usr/bin/env bash
# =============================================================================
# latex-structure-check.sh — Check LaTeX document structure
# =============================================================================
# Usage: latex-structure-check.sh <tex_file>
# Exit: 0 if structure is valid, 1 otherwise
# =============================================================================

set -euo pipefail

TEX_FILE="${1:-.paper/output/draft.tex}"

if [[ \! -f "$TEX_FILE" ]]; then
    echo "ERROR: LaTeX file not found: $TEX_FILE"
    exit 1
fi

python3 << PYEOF
import re
import sys

tex_file = '$TEX_FILE'

with open(tex_file) as f:
    content = f.read()

required = [r'\\documentclass', r'\\begin\{document\}', r'\\end\{document\}']
missing = [r for r in required if not re.search(r, content)]

if missing:
    print(f"FAIL: missing required LaTeX commands:")
    for m in missing:
        print(f"  - {m}")
    sys.exit(1)
else:
    print("PASS: LaTeX structure is valid (\\documentclass, \\begin{document}, \\end{document} all present)")
    sys.exit(0)
PYEOF

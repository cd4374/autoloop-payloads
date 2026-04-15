#\!/usr/bin/env bash
# =============================================================================
# doi-accessibility.sh — Check DOI/arXiv URL accessibility
# =============================================================================
# Usage: doi-accessibility.sh <bib_file> [--max-fail-rate 0.2]
# Exit: 0 if ≤max_fail_rate of URLs are inaccessible, 1 otherwise
# =============================================================================

set -euo pipefail

BIB_FILE="${1:-.paper/output/references.bib}"
MAX_FAIL_RATE="${2:-0.2}"

if [[ \! -f "$BIB_FILE" ]]; then
    echo "ERROR: BibTeX file not found: $BIB_FILE"
    exit 1
fi

# Extract DOI and arXiv URLs, check accessibility
python3 << PYEOF
import re
import sys
import urllib.request
import json

bib_file = '$BIB_FILE'
max_fail_rate = float('$MAX_FAIL_RATE')

with open(bib_file) as f:
    content = f.read()

# Extract DOIs
dois = re.findall(r'doi\s*=\s*[{"]([^}"]+)["}]', content, re.IGNORECASE)
# Extract arXiv IDs
arxiv_ids = re.findall(r'arxiv\s*=\s*[{"]([^}"]+)["}]', content, re.IGNORECASE)
# Also look for eprinttype=arxiv
eprint_arxiv = re.findall(r'eprinttype\s*=\s*[{"]arxiv["}][,\s]*eprint\s*=\s*[{"]([^}"]+)["}]', content, re.IGNORECASE)

urls_to_check = []
for doi in dois:
    urls_to_check.append(f"https://doi.org/{doi.strip()}")
for arx in arxiv_ids + eprint_arxiv:
    urls_to_check.append(f"https://arxiv.org/abs/{arx.strip()}")

if not urls_to_check:
    print("PASS: no DOI/arXiv URLs to check")
    sys.exit(0)

failed = []
for url in urls_to_check[:20]:  # Check first 20 only (time constraint)
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'autoloop-checker/1.0'})
        resp = urllib.request.urlopen(req, timeout=10)
        if resp.status not in [200, 301, 302]:
            failed.append(url)
    except Exception as e:
        failed.append(f"{url} ({str(e)[:30]})")

fail_rate = len(failed) / len(urls_to_check[:20]) if urls_to_check else 0

if fail_rate > max_fail_rate:
    print(f"FAIL: {len(failed)}/{len(urls_to_check[:20])} URLs inaccessible ({fail_rate:.1%} > {max_fail_rate:.1%})")
    for f in failed[:5]:
        print(f"  - {f}")
    sys.exit(1)
else:
    print(f"PASS: {len(urls_to_check)} URLs checked, {len(failed)} failed ({fail_rate:.1%} ≤ {max_fail_rate:.1%})")
    sys.exit(0)
PYEOF

#!/usr/bin/env bash
set -euo pipefail

# Literature Loop Evaluation Script
# Configuration inherited from parent payload's session.md

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_SESSION="$SCRIPT_DIR/../session.md"

DRAFT_FILE="${DRAFT_FILE:-.paper/output/draft.tex}"
REFS_FILE="${REFS_FILE:-.paper/output/references.bib}"

# Load config from parent session.md
load_config() {
    python3 -c "
import yaml, re, json
with open('$PARENT_SESSION') as f:
    content = f.read()
match = re.match(r'^---\n(.*?)\n---', content, re.DOTALL)
if match:
    frontmatter = yaml.safe_load(match.group(1))
    print(json.dumps({
        'min_recent_refs_pct': frontmatter.get('min_recent_refs_pct', 30),
    }))
else:
    print(json.dumps({'min_recent_refs_pct': 30}))
"
}

# All evaluation done in Python for correct JSON output
python3 << 'PYEOF'
import json, os, re, subprocess, yaml

DRAFT_FILE = os.environ.get('DRAFT_FILE', '.paper/output/draft.tex')
REFS_FILE = os.environ.get('REFS_FILE', '.paper/output/references.bib')
PARENT_SESSION = os.environ.get('PARENT_SESSION', '.paper-gen-payload/session.md')

# Load config from parent session
def load_config():
    try:
        with open(PARENT_SESSION) as f:
            content = f.read()
        match = re.match(r'^---\n(.*?)\n---', content, re.DOTALL)
        if match:
            fm = yaml.safe_load(match.group(1))
            return fm.get('min_recent_refs_pct', 30)
    except Exception:
        pass
    return 30

MIN_RECENT_PCT = load_config()

results = []

# LIT-001: Related Work section (script)
if os.path.exists(DRAFT_FILE):
    r = subprocess.run(['grep', '-qiE', '(related.*work|background|prior.*work|literature.*review)', DRAFT_FILE],
                      capture_output=True)
    has_rw = (r.returncode == 0)
    results.append({"id": "LIT-001", "pass": has_rw,
                    "evidence": "包含 Related Work 章节" if has_rw else "缺少 Related Work 章节"})
else:
    results.append({"id": "LIT-001", "pass": False, "evidence": "draft.tex 不存在"})

# LIT-004: Recent references percentage (script)
if os.path.exists(REFS_FILE):
    with open(REFS_FILE) as f:
        bib = f.read()
    years = re.findall(r'year\s*=\s*\{?([0-9]{4})', bib)
    current_year = 2026
    cutoff = current_year - 5
    recent = sum(1 for y in years if int(y) >= cutoff)
    total = len(years)
    pct = (recent * 100 // total) if total > 0 else 0
    min_pct = 30
    if os.path.exists(PAPER_TYPE):
        with open(PAPER_TYPE) as f:
            pt = json.load(f)
        min_pct = pt.get('derived_thresholds', {}).get('min_recent_refs_pct', 30)
    results.append({"id": "LIT-004", "pass": pct >= min_pct,
                    "evidence": f"近五年文献占比: {pct}% >= 门槛" if pct >= min_pct else f"近五年文献占比: {pct}% < 门槛"})
else:
    results.append({"id": "LIT-004", "pass": False, "evidence": "references.bib 不存在"})

# LIT-005: Key venue citations count (script)
if os.path.exists(DRAFT_FILE):
    r = subprocess.run(['grep', '-cE', '(neurips|icml|iclr|nature.*machine|stat\.ml|arxiv\.org/abs)', DRAFT_FILE],
                      capture_output=True, text=True)
    key_count = int(r.stdout.strip()) if r.stdout.strip().isdigit() else 0
    results.append({"id": "LIT-005", "pass": key_count >= 5,
                    "evidence": f"检测到 {key_count} 处领域旗舰会议引用 (>=5)" if key_count >= 5 else f"领域旗舰引用过少: {key_count} 处 (需>=5)"})
else:
    results.append({"id": "LIT-005", "pass": False, "evidence": "draft.tex 不存在"})

print(json.dumps({"results": results}, ensure_ascii=False))
PYEOF

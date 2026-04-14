#!/usr/bin/env bash
# Review Payload Evaluation Script — 精简版（5 criteria）
set -euo pipefail

DRAFT_FILE="${DRAFT_FILE:-.paper/output/draft.tex}"
REFS_FILE="${REFS_FILE:-.paper/output/references.bib}"
PAPER_TYPE_FILE="${PAPER_TYPE_FILE:-.paper/state/paper-type.json}"
STATE_DIR=".paper/state"

python3 << 'PYEOF'
import json, os, re, subprocess

DRAFT_FILE = os.environ.get('DRAFT_FILE', '.paper/output/draft.tex')
REFS_FILE = os.environ.get('REFS_FILE', '.paper/output/references.bib')
PAPER_TYPE_FILE = os.environ.get('PAPER_TYPE_FILE', '.paper/state/paper-type.json')
STATE_DIR = '.paper/state'

results = []

def get_threshold(key, default):
    try:
        if os.path.isfile(PAPER_TYPE_FILE):
            with open(PAPER_TYPE_FILE) as f:
                pt = json.load(f)
            return pt.get('derived_thresholds', {}).get(key, default)
    except Exception:
        pass
    return default

def read_tex():
    if not os.path.isfile(DRAFT_FILE):
        return None
    with open(DRAFT_FILE) as f:
        return f.read()

tex = read_tex()

# REV-001: Paper structure (merged script checks)
sections_ok = False
abstract_ok = False
if tex is not None:
    has_abs = bool(re.search(r'\\begin\{abstract\}', tex, re.IGNORECASE))
    has_intro = bool(re.search(r'\\(?:section|section\*)\{[^}]*(?:intro|introduction)', tex, re.IGNORECASE))
    has_method = bool(re.search(r'\\(?:section|subsubsection)\{[^}]*(?:method|methodology)', tex, re.IGNORECASE))
    has_exp = bool(re.search(r'\\(?:section|subsubsection)\{[^}]*(?:experiment|evaluation|result)', tex, re.IGNORECASE))
    has_concl = bool(re.search(r'\\(?:section|subsubsection)\{[^}]*(?:concl|conclusion)', tex, re.IGNORECASE))
    has_lim = bool(re.search(r'\\limitation', tex, re.IGNORECASE))
    sections_ok = all([has_abs, has_intro, has_method, has_exp, has_concl, has_lim])

    if has_abs:
        m = re.search(r'\\begin\{abstract\}(.*?)\\end\{abstract\}', tex, re.DOTALL)
        words = len(m.group(1).split()) if m else 999
        max_w = get_threshold('abstract_max_words', 250)
        abstract_ok = words <= max_w
    else:
        abstract_ok = False
else:
    sections_ok = False

rev001_pass = sections_ok and abstract_ok
results.append({
    "id": "REV-001", "pass": rev001_pass,
    "evidence": "结构完整" if rev001_pass else f"sections={sections_ok}, abstract={abstract_ok}"
})

# REV-002, REV-003, REV-004, REV-005: LLM criteria (placeholder)
results.append({"id": "REV-002", "pass": True, "evidence": "跨模型审查由 LLM evaluator 执行"})
results.append({"id": "REV-003", "pass": True, "evidence": "无 blocking issue 由 LLM evaluator 执行"})
results.append({"id": "REV-004", "pass": True, "evidence": "学术诚信由 LLM evaluator 执行"})
results.append({"id": "REV-005", "pass": True, "evidence": "统计合规由 LLM evaluator 执行"})

print(json.dumps({"results": results}, ensure_ascii=False))
PYEOF

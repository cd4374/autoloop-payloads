#!/usr/bin/env bash
# Paper Init Payload Evaluation Script — 精简版（6 blocking criteria）
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
PAPER_BASE="$PROJECT_ROOT/.paper"
STATE_DIR="$PAPER_BASE/state"
INPUT_DIR="$PAPER_BASE/input"
OUTPUT_DIR="$PAPER_BASE/output"

export STATE_DIR INPUT_DIR OUTPUT_DIR

python3 << 'PYEOF'
import json, os, re

STATE_DIR = os.environ.get('STATE_DIR', '.paper/state')
INPUT_DIR = os.environ.get('INPUT_DIR', '.paper/input')
OUTPUT_DIR = os.environ.get('OUTPUT_DIR', '.paper/output')

results = []

# INIT-001: Directory structure + idea.md
init1_ok = False
init1_ev = ""
if os.path.isdir(STATE_DIR) and os.path.isdir(INPUT_DIR) and os.path.isdir(OUTPUT_DIR):
    idea_file = os.path.join(INPUT_DIR, 'idea.md')
    if os.path.isfile(idea_file) and os.path.getsize(idea_file) > 10:
        init1_ok = True
        init1_ev = "目录结构完整，idea.md 非空"
    else:
        init1_ev = "idea.md 不存在或为空"
else:
    init1_ev = "目录结构不完整"
results.append({"id": "INIT-001", "pass": init1_ok, "evidence": init1_ev})

# INIT-002: paper-type.json
init2_ok = False
init2_ev = ""
pt_file = os.path.join(STATE_DIR, 'paper-type.json')
if os.path.isfile(pt_file):
    try:
        with open(pt_file) as f:
            pt = json.load(f)
        required = ['venue', 'paper_domain', 'derived_thresholds']
        missing = [k for k in required if k not in pt]
        if missing:
            init2_ev = f"缺少字段: {missing}"
        elif not isinstance(pt.get('derived_thresholds'), dict) or len(pt['derived_thresholds']) == 0:
            init2_ev = "derived_thresholds 为空或非 dict"
        else:
            init2_ok = True
            init2_ev = f"paper-type.json 合法，domain={pt.get('paper_domain')}"
    except Exception as e:
        init2_ev = f"JSON 解析错误: {str(e)[:60]}"
else:
    init2_ev = "paper-type.json 不存在"
results.append({"id": "INIT-002", "pass": init2_ok, "evidence": init2_ev})

# INIT-003: draft.tex
init3_ok = False
init3_ev = ""
draft_file = os.path.join(OUTPUT_DIR, 'draft.tex')
if os.path.isfile(draft_file):
    with open(draft_file) as f:
        content = f.read()
    has_docclass = bool(re.search(r'\\documentclass', content))
    has_begindoc = bool(re.search(r'\\begin\{document\}', content))
    has_enddoc = bool(re.search(r'\\end\{document\}', content))
    if has_docclass and has_begindoc and has_enddoc:
        init3_ok = True
        init3_ev = "draft.tex LaTeX 结构完整"
    else:
        missing = []
        if not has_docclass: missing.append('\\documentclass')
        if not has_begindoc: missing.append('\\begin{document}')
        if not has_enddoc: missing.append('\\end{document}')
        init3_ev = f"缺少: {', '.join(missing)}"
else:
    init3_ev = "draft.tex 不存在"
results.append({"id": "INIT-003", "pass": init3_ok, "evidence": init3_ev})

# INIT-004: references.bib
init4_ok = False
init4_ev = ""
bib_file = os.path.join(OUTPUT_DIR, 'references.bib')
if os.path.isfile(bib_file):
    with open(bib_file) as f:
        content = f.read()
    entries = re.findall(r'^@[a-zA-Z]+\{', content, re.MULTILINE)
    count = len(entries)
    if count >= 5:
        init4_ok = True
        init4_ev = f"references.bib 包含 {count} 个条目 (>=5)"
    else:
        init4_ev = f"references.bib 仅 {count} 个条目 (<5)"
else:
    init4_ev = "references.bib 不存在"
results.append({"id": "INIT-004", "pass": init4_ok, "evidence": init4_ev})

# INIT-005: code/main.py
init5_ok = False
init5_ev = ""
main_py = os.path.join(OUTPUT_DIR, 'code', 'main.py')
if os.path.isfile(main_py):
    try:
        with open(main_py) as f:
            lines = len(f.readlines())
        if lines >= 10:
            init5_ok = True
            init5_ev = f"code/main.py 存在 ({lines} 行 >= 10)"
        else:
            init5_ev = f"code/main.py 仅 {lines} 行 (<10)"
    except Exception:
        init5_ev = "code/main.py 无法读取"
else:
    init5_ev = "code/main.py 不存在"
results.append({"id": "INIT-005", "pass": init5_ok, "evidence": init5_ev})

# INIT-006: compute-env.json
init6_ok = False
init6_ev = ""
compute_file = os.path.join(STATE_DIR, 'compute-env.json')
if os.path.isfile(compute_file):
    try:
        with open(compute_file) as f:
            env = json.load(f)
        if 'device' not in env:
            init6_ev = "缺少 device 字段"
        elif 'available' not in env:
            init6_ev = "缺少 available 字段"
        elif env.get('device') not in ('ssh_gpu', 'cuda', 'mps', 'cpu'):
            init6_ev = f"无效 device: {env.get('device')}"
        else:
            init6_ok = True
            init6_ev = f"compute-env.json 合法，device={env.get('device')}"
    except Exception as e:
        init6_ev = f"JSON 解析错误: {str(e)[:60]}"
else:
    init6_ev = "compute-env.json 不存在"
results.append({"id": "INIT-006", "pass": init6_ok, "evidence": init6_ev})

print(json.dumps({"results": results}, ensure_ascii=False))
PYEOF

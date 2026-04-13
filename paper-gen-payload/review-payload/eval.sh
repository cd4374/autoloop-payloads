#!/usr/bin/env bash
set -euo pipefail

# Review Loop Evaluation Script
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
    thresholds = {
        'NeurIPS': {'abstract_max_words': 250, 'min_references': 30, 'min_figures': 5, 'min_tables': 1},
        'ICML': {'abstract_max_words': 250, 'min_references': 30, 'min_figures': 5, 'min_tables': 1},
        'ICLR': {'abstract_max_words': 250, 'min_references': 30, 'min_figures': 5, 'min_tables': 1},
        'AAAI': {'abstract_max_words': 200, 'min_references': 25, 'min_figures': 4, 'min_tables': 1},
        'Journal': {'abstract_max_words': 300, 'min_references': 40, 'min_figures': 5, 'min_tables': 2},
        'Short': {'abstract_max_words': 150, 'min_references': 15, 'min_figures': 3, 'min_tables': 1},
        'Letter': {'abstract_max_words': 150, 'min_references': 10, 'min_figures': 2, 'min_tables': 1},
    }
    pt = frontmatter.get('paper_type', 'NeurIPS')
    t = thresholds.get(pt, thresholds['NeurIPS'])
    print(json.dumps(t))
else:
    print(json.dumps({'abstract_max_words': 250, 'min_references': 30, 'min_figures': 5, 'min_tables': 1}))
"
}

python3 << 'PYEOF'
import json, os, re, subprocess, yaml

DRAFT_FILE = os.environ.get('DRAFT_FILE', '.paper/output/draft.tex')
REFS_FILE = os.environ.get('REFS_FILE', '.paper/output/references.bib')
PARENT_SESSION = os.environ.get('PARENT_SESSION', '.paper-gen-payload/session.md')

results = []

def get_threshold(key, default):
    try:
        with open(PARENT_SESSION) as f:
            content = f.read()
        match = re.match(r'^---\n(.*?)\n---', content, re.DOTALL)
        if match:
            fm = yaml.safe_load(match.group(1))
            thresholds = {
                'NeurIPS': {'abstract_max_words': 250, 'min_references': 30, 'min_figures': 5, 'min_tables': 1},
                'ICML': {'abstract_max_words': 250, 'min_references': 30, 'min_figures': 5, 'min_tables': 1},
                'ICLR': {'abstract_max_words': 250, 'min_references': 30, 'min_figures': 5, 'min_tables': 1},
                'AAAI': {'abstract_max_words': 200, 'min_references': 25, 'min_figures': 4, 'min_tables': 1},
                'Journal': {'abstract_max_words': 300, 'min_references': 40, 'min_figures': 5, 'min_tables': 2},
                'Short': {'abstract_max_words': 150, 'min_references': 15, 'min_figures': 3, 'min_tables': 1},
                'Letter': {'abstract_max_words': 150, 'min_references': 10, 'min_figures': 2, 'min_tables': 1},
            }
            pt = fm.get('paper_type', 'NeurIPS')
            return thresholds.get(pt, thresholds['NeurIPS']).get(key, default)
    except Exception:
        pass
    return default

def read_tex():
    if not os.path.isfile(DRAFT_FILE):
        return None
    with open(DRAFT_FILE) as f:
        return f.read()

tex = read_tex()

# REV-101: Required sections present
if tex is None:
    results.append({"id": "REV-101", "pass": False, "evidence": "draft.tex 不存在"})
else:
    required = ['abstract', 'introduction', 'method', 'experiment', 'conclusion', 'limitation']
    missing = []
    for sec in required:
        pattern = r'\\(?:section|section\*)\{[^}]*' + sec
        if not re.search(pattern, tex, re.IGNORECASE) and not re.search(r'\\begin\{abstract\}', tex, re.IGNORECASE):
            missing.append(sec)
    # Check abstract separately
    has_abstract = bool(re.search(r'\\begin\{abstract\}', tex, re.IGNORECASE))
    missing2 = []
    for sec in ['introduction', 'method', 'experiment', 'conclusion', 'limitation']:
        if not re.search(r'\\(?:section|section\*)\{[^}]*' + sec, tex, re.IGNORECASE):
            missing2.append(sec)
    if not has_abstract:
        missing2.append('abstract')
    if not missing2:
        results.append({"id": "REV-101", "pass": True,
                        "evidence": "所有必要章节存在: Abstract/Introduction/Method/Experiments/Conclusion/Limitations"})
    else:
        results.append({"id": "REV-101", "pass": False,
                        "evidence": f"缺失章节: {' '.join(missing2)}"})

# REV-102: Abstract word count within limit
if tex is None:
    results.append({"id": "REV-102", "pass": False, "evidence": "draft.tex 不存在"})
else:
    match = re.search(r'\\begin\{abstract\}(.*?)\\end\{abstract\}', tex, re.DOTALL)
    if match:
        words = len(match.group(1).split())
    else:
        words = 999
    max_words = get_threshold('abstract_max_words', 250)
    if words <= max_words:
        results.append({"id": "REV-102", "pass": True, "evidence": f"Abstract {words} 字 <= {max_words}"})
    else:
        results.append({"id": "REV-102", "pass": False, "evidence": f"Abstract {words} 字 > {max_words}"})

# REV-103: Citation count meets minimum
if not os.path.isfile(REFS_FILE):
    results.append({"id": "REV-103", "pass": False, "evidence": "references.bib 不存在"})
else:
    with open(REFS_FILE) as f:
        bib = f.read()
    bib_count = len(re.findall(r'^@[a-zA-Z]+\{', bib, re.MULTILINE))
    min_refs = get_threshold('min_references', 30)
    if bib_count >= min_refs:
        results.append({"id": "REV-103", "pass": True, "evidence": f"引用数: {bib_count} >= 门槛: {min_refs}"})
    else:
        results.append({"id": "REV-103", "pass": False, "evidence": f"引用数: {bib_count} < 门槛: {min_refs}"})

# REV-104: Figure count meets minimum
if tex is None:
    results.append({"id": "REV-104", "pass": False, "evidence": "draft.tex 不存在"})
else:
    r = subprocess.run(['grep', '-cE', r'\\includegraphics', DRAFT_FILE],
                       capture_output=True, text=True)
    try:
        fig_count = int(r.stdout.strip())
    except Exception:
        fig_count = 0
    min_figs = get_threshold('min_figures', 5)
    if fig_count >= min_figs:
        results.append({"id": "REV-104", "pass": True, "evidence": f"图表数: {fig_count} >= 门槛: {min_figs}"})
    else:
        results.append({"id": "REV-104", "pass": False, "evidence": f"图表数: {fig_count} < 门槛: {min_figs}"})

# REV-105: Table count meets minimum
if tex is None:
    results.append({"id": "REV-105", "pass": False, "evidence": "draft.tex 不存在"})
else:
    r = subprocess.run(['grep', '-cE', r'\\begin\{(tabular|table)', DRAFT_FILE],
                       capture_output=True, text=True)
    try:
        table_count = int(r.stdout.strip())
    except Exception:
        table_count = 0
    min_tables = get_threshold('min_tables', 1)
    if table_count >= min_tables:
        results.append({"id": "REV-105", "pass": True, "evidence": f"表格数: {table_count} >= 门槛: {min_tables}"})
    else:
        results.append({"id": "REV-105", "pass": False, "evidence": f"表格数: {table_count} < 门槛: {min_tables}"})

# REV-106: Mean+-std reporting
if tex is None:
    results.append({"id": "REV-106", "pass": False, "evidence": "draft.tex 不存在"})
else:
    has_mean_std = bool(re.search(r'[0-9]+\.[0-9]+[±\\]pm\s*[0-9]+\.[0-9]+', tex))
    if has_mean_std:
        results.append({"id": "REV-106", "pass": True, "evidence": "包含 mean+-std 报告"})
    else:
        results.append({"id": "REV-106", "pass": False, "evidence": "缺少 mean+-std 报告"})

# REV-107: Conflict of Interest present
if tex is None:
    results.append({"id": "REV-107", "pass": False, "evidence": "draft.tex 不存在"})
else:
    has_coi = bool(re.search(r'conflict.*interest|no competing interests|coi.*none|authors.*declare', tex, re.IGNORECASE))
    if has_coi:
        results.append({"id": "REV-107", "pass": True, "evidence": "包含 Conflict of Interest 声明"})
    else:
        results.append({"id": "REV-107", "pass": False, "evidence": "缺少 Conflict of Interest 声明"})

# REV-108: Limitations section present
if tex is None:
    results.append({"id": "REV-108", "pass": False, "evidence": "draft.tex 不存在"})
else:
    has_lim = bool(re.search(r'limitation', tex, re.IGNORECASE))
    if has_lim:
        results.append({"id": "REV-108", "pass": True, "evidence": "包含 Limitations 段落"})
    else:
        results.append({"id": "REV-108", "pass": False, "evidence": "缺少 Limitations 段落"})

# REV-109: Reproducibility Statement present
if tex is None:
    results.append({"id": "REV-109", "pass": False, "evidence": "draft.tex 不存在"})
else:
    has_repro = bool(re.search(r'reproducib', tex, re.IGNORECASE))
    if has_repro:
        results.append({"id": "REV-109", "pass": True, "evidence": "包含 Reproducibility Statement"})
    else:
        results.append({"id": "REV-109", "pass": False, "evidence": "缺少 Reproducibility Statement"})

# REV-110: Code and environment available
code_ok = os.path.isfile('.paper/output/code/main.py') and os.path.getsize('.paper/output/code/main.py') > 0
req_ok = os.path.isfile('.paper/output/code/requirements.txt') and os.path.getsize('.paper/output/code/requirements.txt') > 0
if code_ok and req_ok:
    results.append({"id": "REV-110", "pass": True, "evidence": "代码和依赖文件存在且非空"})
elif code_ok:
    results.append({"id": "REV-110", "pass": False, "evidence": "缺少 requirements.txt"})
else:
    results.append({"id": "REV-110", "pass": False, "evidence": "缺少实验代码"})

# REV-111: LaTeX compiles without error
if tex is None:
    results.append({"id": "REV-111", "pass": False, "evidence": "draft.tex 不存在"})
else:
    output_dir = os.path.dirname(os.path.abspath(DRAFT_FILE))
    tex_basename = os.path.basename(DRAFT_FILE)
    try:
        r = subprocess.run(
            ['latexmk', '-pdf', '-interaction=nonstopmode', tex_basename],
            capture_output=True, timeout=120, cwd=output_dir
        )
        if r.returncode == 0:
            results.append({"id": "REV-111", "pass": True, "evidence": "LaTeX 编译成功"})
        else:
            results.append({"id": "REV-111", "pass": False, "evidence": "LaTeX 编译失败"})
    except Exception:
        results.append({"id": "REV-111", "pass": False, "evidence": "LaTeX 编译失败"})

print(json.dumps({"results": results}, ensure_ascii=False))
PYEOF

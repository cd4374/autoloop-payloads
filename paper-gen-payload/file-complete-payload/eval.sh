#!/usr/bin/env bash
# File Complete Payload Evaluation Script — 精简版（5 criteria）
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
STATE_DIR="$PROJECT_ROOT/.paper/state"
OUTPUT_DIR="$PROJECT_ROOT/.paper/output"

# FILE-001: Core files complete
files=(
    "$OUTPUT_DIR/draft.tex:draft.tex"
    "$OUTPUT_DIR/references.bib:references.bib"
    "$OUTPUT_DIR/paper.pdf:paper.pdf"
    "$OUTPUT_DIR/code/main.py:code/main.py"
    "$OUTPUT_DIR/code/requirements.txt:code/requirements.txt"
    "$OUTPUT_DIR/reproducibility.json:reproducibility.json"
)
file001_ok=true
file001_missing=""
for entry in "${files[@]}"; do
    fp="${entry%%:*}"
    if [[ ! -f "$fp" ]] || [[ ! -s "$fp" ]]; then
        file001_ok=false
        fn="${entry##*:}"
        file001_missing="$file001_missing $fn"
    fi
done
if [[ "$file001_ok" == "true" ]]; then
    file001_ev="6 个核心文件均存在且非空"
else
    file001_ev="缺失:${file001_missing}"
fi

# FILE-002: LaTeX structure + cite consistency
file002_ok=false
file002_ev=""
if [[ -f "$OUTPUT_DIR/draft.tex" ]]; then
    local has_docclass has_begindoc has_enddoc
    grep -qE '\\\\documentclass' "$OUTPUT_DIR/draft.tex" && has_docclass="true"
    grep -qE '\\\\begin\{document\}' "$OUTPUT_DIR/draft.tex" && has_begindoc="true"
    grep -qE '\\\\end\{document\}' "$OUTPUT_DIR/draft.tex" && has_enddoc="true"
    local latex_ok=false
    [[ "$has_docclass" == "true" ]] && [[ "$has_begindoc" == "true" ]] && [[ "$has_enddoc" == "true" ]] && latex_ok=true

    local cite_ok=false
    if [[ -f "$OUTPUT_DIR/references.bib" ]] && [[ -f "$OUTPUT_DIR/draft.tex" ]]; then
        python3 -c "
import re
with open('$OUTPUT_DIR/references.bib') as f:
    bib = f.read()
with open('$OUTPUT_DIR/draft.tex') as f:
    tex = f.read()
keys = [k.strip() for k in re.findall(r'^@[a-zA-Z]+\{([^,]+)', bib, re.MULTILINE)]
unused = sum(1 for k in keys if not re.search(r'\\\\cite[pt]?\{[^}]*' + re.escape(k), tex))
print('true' if unused == 0 and keys else 'false')
" 2>/dev/null | grep -q "true" && cite_ok=true
    fi

    if [[ "$latex_ok" == "true" ]] && [[ "$cite_ok" == "true" ]]; then
        file002_ok=true
        file002_ev="LaTeX 结构完整，引用一致"
    elif [[ "$latex_ok" == "true" ]]; then
        file002_ok=false
        file002_ev="LaTeX 结构完整但引用不一致"
    else
        file002_ok=false
        file002_ev="LaTeX 基本结构缺失"
    fi
else
    file002_ev="draft.tex 不存在"
fi

# FILE-003: Hard gate evidence
gate_ok=false
gate_ev=""
python3 - <<'PYEOF' 2>/dev/null
import json, os
state = '$STATE_DIR'
req = {
    'runtime-proof.json': lambda d: int(d.get('exit_code', 1)) == 0,
    'external-review-log.json': lambda d: str(d.get('verdict', '')).lower() != 'blocking',
    'evidence-trace.json': lambda d: isinstance(d.get('claims', []), list) and len(d.get('claims', [])) > 0,
    'plagiarism-report.json': lambda d: str(d.get('status', '')).lower() == 'success' and float(d.get('similarity_pct', 100.0)) <= 15.0,
}
missing, invalid = [], []
for fn, chk in req.items():
    fp = os.path.join(state, fn)
    if not os.path.isfile(fp):
        missing.append(fn)
    else:
        try:
            if not chk(json.load(open(fp))):
                invalid.append(fn)
        except Exception:
            invalid.append(fn)
print('ok' if not missing and not invalid else 'missing:' + ','.join(missing) + ' invalid:' + ','.join(invalid))
PYEOF
gate_result=$?
if [[ $gate_result -eq 0 ]]; then
    gate_ok=true
    gate_ev="P0 门控证据齐全"
else
    gate_ev="P0 门控未就绪"
fi

# FILE-004: Vx package structure
latest_v=$(python3 -c "
import os, re
pat = re.compile(r'^V([0-9]+)$')
best = None
for n in os.listdir('$PROJECT_ROOT'):
    m = pat.match(n)
    if m and os.path.isdir(os.path.join('$PROJECT_ROOT', n)):
        i = int(m.group(1))
        if best is None or i > best[0]:
            best = (i, n)
print(best[1] if best else '')
" 2>/dev/null || echo "")
vx_ok=false
vx_ev=""
if [[ -n "$latest_v" ]] && \
   [[ -d "$PROJECT_ROOT/$latest_v/code" ]] && \
   [[ -d "$PROJECT_ROOT/$latest_v/latex" ]] && \
   [[ -d "$PROJECT_ROOT/$latest_v/else-supports" ]]; then
    vx_ok=true
    vx_ev="$latest_v 目录结构完整"
elif [[ -n "$latest_v" ]]; then
    vx_ev="$latest_v 存在但子目录不完整"
else
    vx_ev="未发现 Vx 版本目录"
fi

# FILE-005: release-package.json
rel_ok=false
rel_ev=""
if [[ -f "$STATE_DIR/release-package.json" ]]; then
    python3 -c "
import json
with open('$STATE_DIR/release-package.json') as f:
    d = json.load(f)
required = ['version_folder','created_at','trigger','evidence_refs']
ok = all(k in d and (isinstance(d[k], str) and d[k] or isinstance(d[k], (list, dict))) for k in required)
print('ok' if ok else 'missing:' + ','.join(k for k in required if k not in d or not d[k]))
" 2>/dev/null | grep -q "ok" && rel_ok=true
    if [[ "$rel_ok" == "true" ]]; then
        rel_ev="release-package.json 字段完整"
    else
        rel_ev="release-package.json 字段缺失"
    fi
else
    rel_ev="release-package.json 不存在"
fi

echo '{"results":['
echo "{\"id\":\"FILE-001\",\"pass\":$file001_ok,\"evidence\":\"$file001_ev\"}"
echo ",{\"id\":\"FILE-002\",\"pass\":$file002_ok,\"evidence\":\"$file002_ev\"}"
echo ",{\"id\":\"FILE-003\",\"pass\":$gate_ok,\"evidence\":\"$gate_ev\"}"
echo ",{\"id\":\"FILE-004\",\"pass\":$vx_ok,\"evidence\":\"$vx_ev\"}"
echo ",{\"id\":\"FILE-005\",\"pass\":$rel_ok,\"evidence\":\"$rel_ev\"}"
echo ']}'

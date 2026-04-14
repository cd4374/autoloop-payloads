#!/usr/bin/env bash
set -euo pipefail

# File Complete Loop Evaluation Script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
OUTPUT_DIR=".paper/output"
STATE_DIR=".paper/state"
DRAFT_FILE="$OUTPUT_DIR/draft.tex"
REFS_FILE="$OUTPUT_DIR/references.bib"
RELEASE_STATE_FILE="$STATE_DIR/release-package.json"

check_file_exists() {
    [[ -f "$1" ]] && [[ -s "$1" ]] && echo "true" || echo "false"
}

check_latex_structure() {
    local file="$1"
    [[ ! -f "$file" ]] && { echo "false"; return; }

    local has_docclass="false"
    local has_begindoc="false"
    local has_enddoc="false"

    grep -qE '\\\\documentclass' "$file" && has_docclass="true"
    grep -qE '\\\\begin\{document\}' "$file" && has_begindoc="true"
    grep -qE '\\\\end\{document\}' "$file" && has_enddoc="true"

    if [[ "$has_docclass" == "true" ]] && [[ "$has_begindoc" == "true" ]] && [[ "$has_enddoc" == "true" ]]; then
        echo "true"
    else
        echo "false"
    fi
}

check_cite_consistency() {
    local bib_file="$1"
    local tex_file="$2"
    [[ ! -f "$bib_file" ]] || [[ ! -f "$tex_file" ]] && { echo "false"; return; }

    python3 -c "
import re
with open('$bib_file') as f:
    bib = f.read()
with open('$tex_file') as f:
    tex = f.read()

bib_keys = re.findall(r'^@[a-zA-Z]+\{([^,]+)', bib, re.MULTILINE)
bib_keys = [k.strip() for k in bib_keys]
unused = 0
for key in bib_keys:
    if not re.search(r'\\\\cite[pt]?\{[^}]*' + re.escape(key), tex):
        unused += 1

if unused == 0 and len(bib_keys) > 0:
    print('true')
else:
    print('false')
" 2>/dev/null || echo "false"
}

check_hard_gate_ready() {
    python3 -c "
import json, os

state_dir = '$STATE_DIR'

req = {
  'runtime-proof.json': lambda d: int(d.get('exit_code', 1)) == 0 and str(d.get('command','')).strip() != '',
  'external-review-log.json': lambda d: str(d.get('verdict','')).strip().lower() != 'blocking',
  'evidence-trace.json': lambda d: isinstance(d.get('claims', []), list) and len(d.get('claims', [])) > 0,
  'plagiarism-report.json': lambda d: str(d.get('status','')).strip().lower() == 'success' and float(d.get('similarity_pct', 100.0)) <= 15.0,
  'dataset-inventory.json': lambda d: isinstance(d.get('datasets', []), list) and len(d.get('datasets', [])) > 0,
}

missing = []
invalid = []
for fn, checker in req.items():
    fp = os.path.join(state_dir, fn)
    if not os.path.isfile(fp):
        missing.append(fn)
        continue
    try:
        with open(fp) as f:
            data = json.load(f)
        if not checker(data):
            invalid.append(fn)
    except Exception:
        invalid.append(fn)

if missing:
    print('false:missing:' + ','.join(missing))
elif invalid:
    print('false:invalid:' + ','.join(invalid))
else:
    print('true')
" 2>/dev/null || echo "false:script_error"
}

latest_release_dir() {
    local root="$1"
    python3 -c "
import os, re
root = '$root'
pat = re.compile(r'^V([0-9]+)$')
best = None
for name in os.listdir(root):
    m = pat.match(name)
    if not m:
        continue
    n = int(m.group(1))
    if best is None or n > best[0]:
        best = (n, name)
print(best[1] if best else '')
" 2>/dev/null || echo ""
}

check_release_state_file() {
    local file="$1"
    [[ ! -f "$file" ]] && { echo "false:missing"; return; }
    python3 -c "
import json
try:
    with open('$file') as f:
        d = json.load(f)
    required = ['version_folder','created_at','trigger','evidence_refs']
    for k in required:
        if k not in d:
            print('false:missing_' + k)
            raise SystemExit(0)
        if isinstance(d[k], str) and d[k].strip() == '':
            print('false:empty_' + k)
            raise SystemExit(0)
    if not isinstance(d.get('evidence_refs'), (list, dict)):
        print('false:bad_evidence_refs')
        raise SystemExit(0)
    print('true')
except Exception:
    print('false:invalid_json')
" 2>/dev/null || echo "false:script_error"
}

main() {
    local files=("$DRAFT_FILE" "$REFS_FILE" "$OUTPUT_DIR/paper.pdf" "$OUTPUT_DIR/code/main.py" "$OUTPUT_DIR/code/requirements.txt" "$OUTPUT_DIR/reproducibility.json")
    local ids=("FILE-001" "FILE-002" "FILE-003" "FILE-004" "FILE-005" "FILE-006")
    local names=("draft.tex" "references.bib" "paper.pdf" "code/main.py" "code/requirements.txt" "reproducibility.json")

    echo '{"results":['

    local first=true
    for i in "${!files[@]}"; do
        local pass=$(check_file_exists "${files[$i]}")
        local ev=""
        if [[ "$pass" == "true" ]]; then
            ev="${names[$i]} 存在且非空"
        else
            ev="${names[$i]} 不存在或为空"
        fi

        if [[ "$first" == "true" ]]; then
            first=false
        else
            echo ","
        fi
        echo -n "{\"id\":\"${ids[$i]}\",\"pass\":$pass,\"evidence\":\"$ev\"}"
    done

    # FILE-007: figures/ 目录存在
    local fig_dir_pass="false"
    local fig_dir_ev=""
    if [[ -d "$OUTPUT_DIR/figures" ]]; then
        fig_dir_pass="true"
        fig_dir_ev="figures/ 目录存在"
    else
        fig_dir_ev="figures/ 目录不存在"
    fi
    echo ","
    echo -n "{\"id\":\"FILE-007\",\"pass\":$fig_dir_pass,\"evidence\":\"$fig_dir_ev\"}"

    # FILE-008: LaTeX 基本结构
    local latex_pass="false"
    local latex_ev=""
    if [[ "$(check_latex_structure "$DRAFT_FILE")" == "true" ]]; then
        latex_pass="true"
        latex_ev="draft.tex 包含 \\documentclass、\\begin{document}、\\end{document}"
    else
        latex_pass="false"
        latex_ev="draft.tex 缺少 LaTeX 基本结构"
    fi
    echo ","
    echo -n "{\"id\":\"FILE-008\",\"pass\":$latex_pass,\"evidence\":\"$latex_ev\"}"

    # FILE-009: BibTeX 与正文引用一致
    local cite_pass="false"
    local cite_ev=""
    if [[ "$(check_cite_consistency "$REFS_FILE" "$DRAFT_FILE")" == "true" ]]; then
        cite_pass="true"
        cite_ev="所有 BibTeX 条目在正文中被引用"
    else
        cite_pass="false"
        cite_ev="存在未在正文中引用的 BibTeX 条目"
    fi
    echo ","
    echo -n "{\"id\":\"FILE-009\",\"pass\":$cite_pass,\"evidence\":\"$cite_ev\"}"

    # FILE-010: 所有必需文件完整性（汇总）
    # Check all critical files exist
    local all_exist="true"
    for f in "$DRAFT_FILE" "$REFS_FILE" "$OUTPUT_DIR/paper.pdf" "$OUTPUT_DIR/code/main.py" "$OUTPUT_DIR/code/requirements.txt" "$OUTPUT_DIR/reproducibility.json"; do
        if [[ ! -f "$f" ]]; then
            all_exist="false"
        fi
    done
    echo ","
    if [[ "$all_exist" == "true" ]]; then
        echo -n "{\"id\":\"FILE-010\",\"pass\":true,\"evidence\":\"所有必需文件均存在且非空\"}"
    else
        echo -n "{\"id\":\"FILE-010\",\"pass\":false,\"evidence\":\"存在缺失的必需文件\"}"
    fi

    # FILE-011: hard gate trigger condition
    local gate_result
    gate_result=$(check_hard_gate_ready)
    local gate_pass="false"
    local gate_ev=""
    if [[ "$gate_result" == "true" ]]; then
        gate_pass="true"
        gate_ev="hard gate 证据齐全且满足基础通过条件"
    else
        gate_pass="false"
        gate_ev="hard gate 未就绪: $gate_result"
    fi
    echo ","
    echo -n "{\"id\":\"FILE-011\",\"pass\":$gate_pass,\"evidence\":\"$gate_ev\"}"

    # FILE-012: latest Vx package structure
    local latest_v
    latest_v=$(latest_release_dir "$PROJECT_ROOT")
    local vx_pass="false"
    local vx_ev=""
    if [[ -n "$latest_v" ]] && [[ -d "$PROJECT_ROOT/$latest_v/code" ]] && [[ -d "$PROJECT_ROOT/$latest_v/latex" ]] && [[ -d "$PROJECT_ROOT/$latest_v/else-supports" ]]; then
        vx_pass="true"
        vx_ev="$latest_v 目录结构完整（code/ latex/ else-supports/）"
    elif [[ -n "$latest_v" ]]; then
        vx_pass="false"
        vx_ev="$latest_v 存在但缺少 code/latex/else-supports 子目录"
    else
        vx_pass="false"
        vx_ev="项目根目录未发现 Vx 版本目录"
    fi
    echo ","
    echo -n "{\"id\":\"FILE-012\",\"pass\":$vx_pass,\"evidence\":\"$vx_ev\"}"

    # FILE-013: release-package state file
    local rel_state_result
    rel_state_result=$(check_release_state_file "$RELEASE_STATE_FILE")
    local rel_state_pass="false"
    local rel_state_ev=""
    if [[ "$rel_state_result" == "true" ]]; then
        rel_state_pass="true"
        rel_state_ev="release-package.json 字段完整"
    else
        rel_state_pass="false"
        rel_state_ev="release-package.json 无效: $rel_state_result"
    fi
    echo ","
    echo -n "{\"id\":\"FILE-013\",\"pass\":$rel_state_pass,\"evidence\":\"$rel_state_ev\"}"

    echo ""
    echo ']}'
}

main

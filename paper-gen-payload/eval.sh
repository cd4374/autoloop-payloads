#!/usr/bin/env bash
set -euo pipefail

# Paper Generation Payload Evaluation Script — 精简版
# 对应 criteria.md 中的 PG-G* (P0 blocking) 和 PG-Q* (advisory) criteria

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SESSION_FILE="$SCRIPT_DIR/session.md"
PROJECT_ROOT="${PROJECT_ROOT:-$SCRIPT_DIR}"
STATE_DIR="$PROJECT_ROOT/.paper/state"
OUTPUT_DIR="$PROJECT_ROOT/.paper/output"

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------
count_pdf_pages() {
    local pdf="$1"
    [[ ! -f "$pdf" ]] && echo "0" && return
    pdfinfo "$pdf" 2>/dev/null | grep Pages | awk '{print $2}' || echo "0"
}

count_bib_entries() {
    local file="$1"
    [[ ! -f "$file" ]] && echo "0" && return
    grep -cE '^@[a-zA-Z]+\{' "$file" 2>/dev/null || echo "0"
}

count_figures() {
    local file="$1"
    [[ ! -f "$file" ]] && echo "0" && return
    grep -cE '\\\\includegraphics' "$file" 2>/dev/null || echo "0"
}

check_latex_structure() {
    local file="$1"
    [[ ! -f "$file" ]] && echo "false" && return
    python3 -c "
import re
with open('$file') as f:
    c = f.read()
ok = bool(re.search(r'\\\\documentclass', c)) and \
         bool(re.search(r'\\\\begin\{document\}', c)) and \
         bool(re.search(r'\\\\end\{document\}', c))
print('true' if ok else 'false')
"
}

check_json_fields() {
    local file="$1"; shift
    local fields=("$@")
    [[ ! -f "$file" ]] && echo "false" && return
    python3 -c "
import json, sys
try:
    with open('$file') as f:
        d = json.load(f)
    missing = [f for f in $fields if f not in d or str(d.get(f,'')) == '']
    print('true' if not missing else 'false:' + ','.join(missing))
except Exception as e:
    print('false:' + str(e))
"
}

# ---------------------------------------------------------------------------
# PG-G01: 论文基础文件已生成
# ---------------------------------------------------------------------------
pgg01_eval() {
    local draft="$OUTPUT_DIR/draft.tex"
    local refs="$OUTPUT_DIR/references.bib"
    local code="$OUTPUT_DIR/code/main.py"
    local pass="false" evidence=""

    local draft_ok refs_ok code_ok
    draft_ok=$(check_latex_structure "$draft")
    [[ -f "$refs" ]] && [[ $(count_bib_entries "$refs") -ge 5 ]] && refs_ok="true" || refs_ok="false"
    [[ -f "$code" ]] && [[ $(wc -l < "$code" 2>/dev/null || echo 0) -gt 10 ]] && code_ok="true" || code_ok="false"

    if [[ "$draft_ok" == "true" ]] && [[ "$refs_ok" == "true" ]] && [[ "$code_ok" == "true" ]]; then
        pass="true"
        evidence="draft.tex/references.bib/code/main.py 均存在且内容有效"
    else
        evidence="缺失或不完整: draft=$(check_latex_structure $draft), refs=$(count_bib_entries $refs), code_lines=$(wc -l < $code 2>/dev/null || echo 0)"
    fi
    echo "{\"id\":\"PG-G01\",\"pass\":$pass,\"evidence\":\"$evidence\"}"
}

# ---------------------------------------------------------------------------
# PG-G02: LaTeX 编译成功
# ---------------------------------------------------------------------------
pgg02_eval() {
    local pdf="$OUTPUT_DIR/paper.pdf"
    local pass="false" evidence=""
    if [[ -f "$pdf" ]]; then
        local pages
        pages=$(count_pdf_pages "$pdf")
        if [[ "$pages" -gt 0 ]]; then
            pass="true"
            evidence="paper.pdf 存在，$pages 页"
        else
            evidence="paper.pdf 存在但无法读取页数"
        fi
    else
        evidence="paper.pdf 不存在"
    fi
    echo "{\"id\":\"PG-G02\",\"pass\":$pass,\"evidence\":\"$evidence\"}"
}

# ---------------------------------------------------------------------------
# PG-G03: P0 外部查重通过
# ---------------------------------------------------------------------------
pgg03_eval() {
    local file="$STATE_DIR/plagiarism-report.json"
    local pass="false" evidence=""
    if [[ ! -f "$file" ]]; then
        evidence="plagiarism-report.json 不存在"
    else
        local result
        result=$(python3 -c "
import json
try:
    with open('$file') as f:
        d = json.load(f)
    status_ok = str(d.get('status','')).lower() == 'success'
    sim = float(d.get('similarity_pct', 100.0))
    sim_ok = sim <= 15.0
    print('true' if status_ok and sim_ok else 'false:status=' + str(d.get('status','')) + ',sim=' + str(sim))
except Exception as e:
    print('false:' + str(e))
" 2>/dev/null || echo "false:script_error")
        if [[ "$result" == "true" ]]; then
            pass="true"
            evidence="外部查重通过，similarity ≤ 15%"
        else
            evidence="外部查重未通过: ${result#false:}"
        fi
    fi
    echo "{\"id\":\"PG-G03\",\"pass\":$pass,\"evidence\":\"$evidence\"}"
}

# ---------------------------------------------------------------------------
# PG-G04: P0 运行时冒烟验证
# ---------------------------------------------------------------------------
pgg04_eval() {
    local file="$STATE_DIR/runtime-proof.json"
    local pass="false" evidence=""
    if [[ ! -f "$file" ]]; then
        evidence="runtime-proof.json 不存在"
    else
        local result
        result=$(python3 -c "
import json
try:
    with open('$file') as f:
        d = json.load(f)
    required = ['command','timeout_sec','exit_code','timestamp','stdout_excerpt']
    missing = [k for k in required if k not in d or str(d.get(k,'')) == '']
    rc_ok = int(d.get('exit_code', 1)) == 0
    print('true' if not missing and rc_ok else 'false:missing=' + ','.join(missing) + ',rc=' + str(d.get('exit_code',1)))
except Exception as e:
    print('false:' + str(e))
" 2>/dev/null || echo "false:script_error")
        if [[ "$result" == "true" ]]; then
            pass="true"
            evidence="冒烟运行通过，exit_code=0，证据完整"
        else
            evidence="冒烟验证失败: ${result#false:}"
        fi
    fi
    echo "{\"id\":\"PG-G04\",\"pass\":$pass,\"evidence\":\"$evidence\"}"
}

# ---------------------------------------------------------------------------
# PG-G05: P0 外部审查通过
# ---------------------------------------------------------------------------
pgg05_eval() {
    local file="$STATE_DIR/external-review-log.json"
    local pass="false" evidence=""
    if [[ ! -f "$file" ]]; then
        evidence="external-review-log.json 不存在"
    else
        local result
        result=$(python3 -c "
import json
try:
    with open('$file') as f:
        d = json.load(f)
    required = ['provider','model','timestamp','verdict','raw_feedback','reviewer_role','request_id']
    missing = [k for k in required if k not in d or str(d.get(k,'')) == '']
    verdict = str(d.get('verdict','')).lower()
    verdict_ok = verdict != 'blocking'
    print('true' if not missing and verdict_ok else 'false:missing=' + ','.join(missing) + ',verdict=' + verdict)
except Exception as e:
    print('false:' + str(e))
" 2>/dev/null || echo "false:script_error")
        if [[ "$result" == "true" ]]; then
            pass="true"
            evidence="外部审查通过，verdict ≠ blocking"
        else
            evidence="外部审查未通过: ${result#false:}"
        fi
    fi
    echo "{\"id\":\"PG-G05\",\"pass\":$pass,\"evidence\":\"$evidence\"}"
}

# ---------------------------------------------------------------------------
# PG-G06: P0 证据链可追溯
# ---------------------------------------------------------------------------
pgg06_eval() {
    local file="$STATE_DIR/evidence-trace.json"
    local pass="false" evidence=""
    if [[ ! -f "$file" ]]; then
        evidence="evidence-trace.json 不存在"
    else
        local result
        result=$(python3 -c "
import json, os
try:
    with open('$file') as f:
        d = json.load(f)
    claims = d.get('claims', [])
    if not isinstance(claims, list) or len(claims) == 0:
        print('false:no_claims')
        exit(0)
    missing_files = []
    for c in claims:
        p = str(c.get('source_log',''))
        if not p or not os.path.isfile(p) or os.path.getsize(p) == 0:
            missing_files.append(p or '(empty)')
    print('true' if not missing_files else 'false:missing_files=' + ','.join(missing_files[:3]))
except Exception as e:
    print('false:' + str(e))
" 2>/dev/null || echo "false:script_error")
        if [[ "$result" == "true" ]]; then
            pass="true"
            evidence="证据链完整，所有 claim 可追溯到日志"
        else
            evidence="证据链缺失: ${result#false:}"
        fi
    fi
    echo "{\"id\":\"PG-G06\",\"pass\":$pass,\"evidence\":\"$evidence\"}"
}

# ---------------------------------------------------------------------------
# PG-Q01: 论文写作质量 (LLM advisory)
# ---------------------------------------------------------------------------
pgq01_eval() {
    local draft="$OUTPUT_DIR/draft.tex"
    local pass="true" evidence=""
    if [[ ! -f "$draft" ]]; then
        pass="false"
        evidence="draft.tex 不存在"
    else
        local has_abs has_intro has_method has_exp has_concl
        grep -qiE '\\\\begin\{abstract\}' "$draft" && has_abs="true" || has_abs="false"
        grep -qiE '\\\\(?:section|subsubsection)\{[^}]*intro' "$draft" && has_intro="true" || has_intro="false"
        grep -qiE '\\\\(?:section|subsubsection)\{[^}]*method' "$draft" && has_method="true" || has_method="false"
        grep -qiE '\\\\(?:section|subsubsection)\{[^}]*experiment' "$draft" && has_exp="true" || has_exp="false"
        grep -qiE '\\\\(?:section|subsubsection)\{[^}]*concl' "$draft" && has_concl="true" || has_concl="false"
        if [[ "$has_abs" == "false" ]] || [[ "$has_intro" == "false" ]] || [[ "$has_method" == "false" ]] || [[ "$has_exp" == "false" ]] || [[ "$has_concl" == "false" ]]; then
            pass="false"
            evidence="缺少章节: abs=$has_abs intro=$has_intro method=$has_method exp=$has_exp concl=$has_concl"
        else
            evidence="主要章节结构完整"
        fi
    fi
    echo "{\"id\":\"PG-Q01\",\"pass\":$pass,\"evidence\":\"$evidence\"}"
}

# ---------------------------------------------------------------------------
# PG-Q02: 引用质量
# ---------------------------------------------------------------------------
pgq02_eval() {
    local refs="$OUTPUT_DIR/references.bib"
    local draft="$OUTPUT_DIR/draft.tex"
    local pass="false" evidence=""

    if [[ ! -f "$refs" ]]; then
        evidence="references.bib 不存在"
    else
        local total recent_pct
        total=$(count_bib_entries "$refs")
        if [[ "$total" -lt 5 ]]; then
            evidence="引用数不足: $total < 5"
        else
            # Count recent (within 5 years)
            local year now cutoff
            now=$(date +%Y)
            cutoff=$((now - 5))
            recent=$(grep -oE 'year\s*=\s*\{?[0-9]{4}' "$refs" 2>/dev/null | grep -oE '[0-9]{4}' | awk -v c="$cutoff" '$1 >= c {n++} END {print n+0}')
            recent_pct=$(python3 -c "print(round($recent * 100 / $total, 1))" 2>/dev/null || echo "0")
            # Check usage
            local unused=0
            if [[ -f "$draft" ]]; then
                local keys
                keys=$(grep -oE '^@[a-zA-Z]+\{[^,]+' "$refs" 2>/dev/null | sed 's/^@[a-zA-Z]*{//' | sort -u)
                for k in $keys; do
                    grep -qE "\\\\cite[pt]?\{[^}]*$k" "$draft" 2>/dev/null || unused=$((unused + 1))
                done
            fi
            if [[ "$unused" -eq 0 ]]; then
                pass="true"
                evidence="引用数=$total，近五年占比=${recent_pct}%，全部被使用"
            else
                evidence="引用数=$total，近五年=${recent_pct}%，未使用=$unused"
            fi
        fi
    fi
    echo "{\"id\":\"PG-Q02\",\"pass\":$pass,\"evidence\":\"$evidence\"}"
}

# ---------------------------------------------------------------------------
# PG-Q03: 实验可复现性
# ---------------------------------------------------------------------------
pgq03_eval() {
    local repro="$OUTPUT_DIR/reproducibility.json"
    local code="$OUTPUT_DIR/code/main.py"
    local logs="$OUTPUT_DIR/logs"
    local pass="false" evidence=""

    local repro_ok="false" seed_ok="false" logs_ok="false"
    if [[ -f "$repro" ]]; then
        python3 -c "
import json
try:
    with open('$repro') as f:
        d = json.load(f)
    required = ['hardware','software','hyperparameters','dataset','preprocessing']
    ok = all(k in d and str(d.get(k,'')) != '' for k in required)
    print('true' if ok else 'false')
except Exception:
    print('false')
" 2>/dev/null | grep -q "true" && repro_ok="true"
    fi
    if [[ -f "$code" ]]; then
        grep -qE '(random\.seed|torch\.(cuda\.)?manual_seed|np\.random\.seed|set_seed)' "$code" 2>/dev/null && seed_ok="true"
    fi
    [[ -d "$logs" ]] && [[ $(find "$logs" -name "run_*.log" 2>/dev/null | wc -l | tr -d ' ') -gt 0 ]] && logs_ok="true"

    if [[ "$repro_ok" == "true" ]] && [[ "$seed_ok" == "true" ]] && [[ "$logs_ok" == "true" ]]; then
        pass="true"
        evidence="reproducibility.json/随机种子/logs 均完整"
    else
        evidence="repro=$repro_ok seed=$seed_ok logs=$logs_ok"
    fi
    echo "{\"id\":\"PG-Q03\",\"pass\":$pass,\"evidence\":\"$evidence\"}"
}

# ---------------------------------------------------------------------------
# PG-Q04: 图表质量
# ---------------------------------------------------------------------------
pgq04_eval() {
    local draft="$OUTPUT_DIR/draft.tex"
    local fig_dir="$OUTPUT_DIR/figures"
    local pass="false" evidence=""

    local fig_count=0 raster_count=0
    [[ -f "$draft" ]] && fig_count=$(count_figures "$draft")
    if [[ -d "$fig_dir" ]]; then
        raster_count=$(find "$fig_dir" -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.gif" \) 2>/dev/null | wc -l | tr -d ' ')
    fi

    if [[ "$raster_count" -eq 0 ]] && [[ "$fig_count" -gt 0 ]]; then
        pass="true"
        evidence="图表数=$fig_count，全部向量格式"
    elif [[ "$raster_count" -gt 0 ]]; then
        evidence="存在栅格图: $raster_count 个"
    else
        evidence="图表数=0"
    fi
    echo "{\"id\":\"PG-Q04\",\"pass\":$pass,\"evidence\":\"$evidence\"}"
}

# ---------------------------------------------------------------------------
# PG-Q05: 数据集合规
# ---------------------------------------------------------------------------
pgq05_eval() {
    local file="$STATE_DIR/dataset-inventory.json"
    local pass="false" evidence=""
    if [[ ! -f "$file" ]]; then
        evidence="dataset-inventory.json 不存在"
    else
        local result
        result=$(python3 -c "
import json
try:
    with open('$file') as f:
        d = json.load(f)
    ds = d.get('datasets', [])
    if not isinstance(ds, list) or len(ds) == 0:
        print('false:no_datasets')
        exit(0)
    ok = True
    for item in ds:
        for k in ['name','source','license','usage_terms']:
            if k not in item or str(item.get(k,'')) == '':
                ok = False
                break
        if not ok:
            break
    print('true' if ok else 'false:missing_fields')
except Exception as e:
    print('false:' + str(e))
" 2>/dev/null || echo "false:script_error")
        if [[ "$result" == "true" ]]; then
            pass="true"
            evidence="数据集清单字段完整"
        else
            evidence="数据集清单不完整: ${result#false:}"
        fi
    fi
    echo "{\"id\":\"PG-Q05\",\"pass\":$pass,\"evidence\":\"$evidence\"}"
}

# ---------------------------------------------------------------------------
# PG-Q06: Vx 交付包完整
# ---------------------------------------------------------------------------
pgq06_eval() {
    local pass="false" evidence=""
    local latest_v=""
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

    if [[ -n "$latest_v" ]] && \
       [[ -d "$PROJECT_ROOT/$latest_v/code" ]] && \
       [[ -d "$PROJECT_ROOT/$latest_v/latex" ]] && \
       [[ -d "$PROJECT_ROOT/$latest_v/else-supports" ]]; then
        local rel_ok="false"
        if [[ -f "$STATE_DIR/release-package.json" ]]; then
            python3 -c "
import json
try:
    with open('$STATE_DIR/release-package.json') as f:
        d = json.load(f)
    ok = all(k in d for k in ['version_folder','created_at','trigger','evidence_refs'])
    print('true' if ok else 'false')
except Exception:
    print('false')
" 2>/dev/null | grep -q "true" && rel_ok="true"
        fi
        if [[ "$rel_ok" == "true" ]]; then
            pass="true"
            evidence="Vx 交付包完整 ($latest_v/)"
        else
            evidence="$latest_v/ 结构存在但 release-package.json 不完整"
        fi
    else
        evidence="项目根目录缺少完整 Vx/ 交付结构"
    fi
    echo "{\"id\":\"PG-Q06\",\"pass\":$pass,\"evidence\":\"$evidence\"}"
}

# ---------------------------------------------------------------------------
# Main — output JSON
# ---------------------------------------------------------------------------
main() {
    echo '{"results":['
    local first=true
    for func in pgg01_eval pgg02_eval pgg03_eval pgg04_eval pgg05_eval pgg06_eval pgq01_eval pgq02_eval pgq03_eval pgq04_eval pgq05_eval pgq06_eval; do
        local result
        result=$("$func")
        if [[ "$first" == "true" ]]; then
            first=false
        else
            echo ","
        fi
        echo -n "    $result"
    done
    echo ""
    echo '  ]}'
}

main

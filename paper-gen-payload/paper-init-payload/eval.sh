#!/usr/bin/env bash
set -euo pipefail

# Paper Init Payload Evaluation Script
# Configuration is inherited from parent payload's session.md

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PARENT_SESSION="$PARENT_DIR/session.md"

PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
PAPER_BASE="${PAPER_BASE:-$PROJECT_ROOT/.paper}"

OUTPUT_DIR="${OUTPUT_DIR:-$PAPER_BASE/output}"
STATE_DIR="${STATE_DIR:-$PAPER_BASE/state}"
INPUT_DIR="${INPUT_DIR:-$PAPER_BASE/input}"


check_file_exists() {
    [[ -f "$1" ]] && echo "true" || echo "false"
}

check_file_size() {
    local file="$1"
    local min_size="${2:-0}"
    if [[ ! -f "$file" ]]; then
        echo "false"
        return
    fi
    local size
    size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo "0")
    if [[ "$size" -gt "$min_size" ]]; then
        echo "true"
    else
        echo "false"
    fi
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

check_pipeline_status_json() {
    local file="$1"
    [[ ! -f "$file" ]] && { echo "false"; return; }

    python3 -c "
import json
try:
    with open('$file') as f:
        data = json.load(f)
    required = ['current_stage', 'completed_stages']
    for key in required:
        if key not in data:
            print('false')
            exit(0)
    print('true')
except Exception:
    print('false')
"
}

check_paper_type_json() {
    local file="$1"
    [[ ! -f "$file" ]] && { echo "false:file_missing"; return; }

    python3 -c "
import json
try:
    with open('$file') as f:
        data = json.load(f)
    required = ['venue', 'paper_domain', 'derived_thresholds']
    for key in required:
        if key not in data:
            print('false:missing:' + key)
            exit(0)
    thresholds = data.get('derived_thresholds', {})
    if not isinstance(thresholds, dict) or len(thresholds) == 0:
        print('false:empty_thresholds')
        exit(0)
    print('true')
except Exception as e:
    print('false:error:' + str(e))
"
}

count_bib_entries() {
    local file="$1"
    [[ ! -f "$file" ]] && echo "0"
    grep -cE '^@[a-zA-Z]+\{' "$file" 2>/dev/null || echo "0"
}

check_reproducibility_json() {
    local file="$1"
    [[ ! -f "$file" ]] && { echo "false"; return; }

    python3 -c "
import json
try:
    with open('$file') as f:
        data = json.load(f)
    required = ['hardware', 'software', 'hyperparameters', 'dataset', 'preprocessing']
    for key in required:
        if key not in data:
            print('false')
            exit(0)
    print('true')
except Exception:
    print('false')
"
}

check_compute_env_json() {
    local file="$1"
    [[ ! -f "$file" ]] && { echo "false:file_missing"; return; }

    python3 -c "
import json
try:
    with open('$file') as f:
        data = json.load(f)
    if 'device' not in data:
        print('false:missing_device')
        exit(0)
    if 'available' not in data:
        print('false:missing_available')
        exit(0)
    valid_devices = ['ssh_gpu', 'cuda', 'mps', 'cpu']
    if data.get('device') not in valid_devices:
        print('false:invalid_device:' + str(data.get('device')))
        exit(0)
    print('true:' + data.get('device',''))
except Exception as e:
    print('false:error:' + str(e))
"
}

check_requirements() {
    local file="$1"
    [[ ! -f "$file" ]] && { echo "false"; return; }
    local lines
    lines=$(wc -l < "$file" 2>/dev/null || echo "0")
    if [[ "$lines" -ge 1 ]]; then
        echo "true"
    else
        echo "false"
    fi
}

check_code_structure() {
    local file="$1"
    [[ ! -f "$file" ]] && { echo "false"; return; }
    local lines
    lines=$(wc -l < "$file" 2>/dev/null || echo "0")
    if [[ "$lines" -ge 10 ]]; then
        echo "true"
    else
        echo "false"
    fi
}

main() {
    local results=()

    # INIT-001: Directory structure and idea.md
    local dir_pass="false"
    local dir_ev=""
    if [[ -d "$STATE_DIR" ]] && [[ -d "$INPUT_DIR" ]] && [[ -d "$OUTPUT_DIR" ]]; then
        if [[ "$(check_file_exists "$INPUT_DIR/idea.md")" == "true" ]] && \
           [[ "$(check_file_size "$INPUT_DIR/idea.md" 10)" == "true" ]]; then
            dir_pass="true"
            dir_ev="目录结构完整，idea.md 非空"
        else
            dir_ev="idea.md 不存在或为空"
        fi
    else
        dir_ev="目录结构不完整"
    fi
    results+=("{\"id\":\"INIT-001\",\"pass\":$dir_pass,\"evidence\":\"$dir_ev\"}")

    # INIT-002: pipeline-status.json (optional, non-blocking)
    local status_pass="true"
    local status_ev=""
    if [[ -f "$STATE_DIR/pipeline-status.json" ]]; then
        if [[ "$(check_pipeline_status_json "$STATE_DIR/pipeline-status.json")" == "true" ]]; then
            status_ev="pipeline-status.json 包含必需字段"
        else
            status_pass="false"
            status_ev="pipeline-status.json 格式错误"
        fi
    else
        status_ev="pipeline-status.json 不存在（可选）"
    fi
    results+=("{\"id\":\"INIT-002\",\"pass\":$status_pass,\"evidence\":\"$status_ev\"}")

    # INIT-003: paper-type.json initialized
    local paper_type_pass="false"
    local paper_type_ev=""
    local paper_type_result
    paper_type_result=$(check_paper_type_json "$STATE_DIR/paper-type.json")
    if [[ "$paper_type_result" == "true" ]]; then
        paper_type_pass="true"
        paper_type_ev="paper-type.json 包含 venue/paper_domain/derived_thresholds"
    else
        paper_type_pass="false"
        paper_type_ev="paper-type.json 缺失或字段不完整: ${paper_type_result#false:}"
    fi
    results+=("{\"id\":\"INIT-003\",\"pass\":$paper_type_pass,\"evidence\":\"$paper_type_ev\"}")

    # INIT-004: draft.tex generated
    local draft_pass="false"
    local draft_ev=""
    if [[ "$(check_latex_structure "$OUTPUT_DIR/draft.tex")" == "true" ]]; then
        draft_pass="true"
        draft_ev="draft.tex 包含 LaTeX 基本结构"
    else
        draft_ev="draft.tex 不存在或缺少基本 LaTeX 结构"
    fi
    results+=("{\"id\":\"INIT-004\",\"pass\":$draft_pass,\"evidence\":\"$draft_ev\"}")

    # INIT-005: references.bib generated
    local bib_pass="false"
    local bib_ev=""
    if [[ -f "$OUTPUT_DIR/references.bib" ]]; then
        local bib_count=$(count_bib_entries "$OUTPUT_DIR/references.bib")
        if [[ "$bib_count" -ge 5 ]]; then
            bib_pass="true"
            bib_ev="references.bib 包含 $bib_count 个条目 (>=5)"
        else
            bib_ev="references.bib 仅有 $bib_count 个条目 (<5)"
        fi
    else
        bib_ev="references.bib 不存在"
    fi
    results+=("{\"id\":\"INIT-005\",\"pass\":$bib_pass,\"evidence\":\"$bib_ev\"}")

    # INIT-006: code/main.py generated
    local code_pass="false"
    local code_ev=""
    if [[ "$(check_code_structure "$OUTPUT_DIR/code/main.py")" == "true" ]]; then
        code_pass="true"
        code_ev="code/main.py 存在且包含基本结构"
    else
        code_ev="code/main.py 不存在或内容过少"
    fi
    results+=("{\"id\":\"INIT-006\",\"pass\":$code_pass,\"evidence\":\"$code_ev\"}")

    # INIT-007: requirements.txt generated
    local req_pass="false"
    local req_ev=""
    if [[ "$(check_requirements "$OUTPUT_DIR/code/requirements.txt")" == "true" ]]; then
        req_pass="true"
        req_ev="code/requirements.txt 存在且非空"
    else
        req_ev="code/requirements.txt 不存在或为空"
    fi
    results+=("{\"id\":\"INIT-007\",\"pass\":$req_pass,\"evidence\":\"$req_ev\"}")

    # INIT-008: reproducibility.json filled
    local repro_pass="false"
    local repro_ev=""
    if [[ "$(check_reproducibility_json "$OUTPUT_DIR/reproducibility.json")" == "true" ]]; then
        repro_pass="true"
        repro_ev="reproducibility.json 包含所有必需字段"
    else
        repro_ev="reproducibility.json 缺少必需字段或不存在"
    fi
    results+=("{\"id\":\"INIT-008\",\"pass\":$repro_pass,\"evidence\":\"$repro_ev\"}")

    # INIT-009: figures directory created
    local fig_pass="false"
    local fig_ev=""
    if [[ -d "$OUTPUT_DIR/figures" ]]; then
        fig_pass="true"
        fig_ev="figures/ 目录存在"
    else
        fig_ev="figures/ 目录不存在"
    fi
    results+=("{\"id\":\"INIT-009\",\"pass\":$fig_pass,\"evidence\":\"$fig_ev\"}")

    # INIT-010: compute-env.json initialized
    local compute_pass="false"
    local compute_ev=""
    local compute_result
    compute_result=$(check_compute_env_json "$STATE_DIR/compute-env.json")
    if [[ "$compute_result" == true:* ]]; then
        compute_pass="true"
        compute_ev="compute-env.json 已生成，设备: ${compute_result#true:}"
    else
        compute_pass="false"
        compute_ev="compute-env.json 缺失或字段不完整: ${compute_result#false:}"
    fi
    results+=("{\"id\":\"INIT-010\",\"pass\":$compute_pass,\"evidence\":\"$compute_ev\"}")

    # Output JSON
    echo '{"results":['
    local first=true
    for r in "${results[@]}"; do
        if [[ "$first" == "true" ]]; then
            first=false
        else
            echo ","
        fi
        echo -n "    $r"
    done
    echo ""
    echo ']}'
}

main
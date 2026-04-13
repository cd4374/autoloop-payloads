#!/usr/bin/env bash
set -euo pipefail

# Experiment Loop Evaluation Script
# Configuration inherited from parent payload's session.md

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_SESSION="$SCRIPT_DIR/../session.md"

CODE_DIR="${CODE_DIR:-.paper/output/code}"
LOGS_DIR="${LOGS_DIR:-.paper/output/logs}"
DRAFT_FILE="${DRAFT_FILE:-.paper/output/draft.tex}"

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
        'NeurIPS': {'min_experiment_runs': 3, 'require_ablation': True},
        'ICML': {'min_experiment_runs': 3, 'require_ablation': True},
        'ICLR': {'min_experiment_runs': 3, 'require_ablation': True},
        'AAAI': {'min_experiment_runs': 3, 'require_ablation': True},
        'Journal': {'min_experiment_runs': 5, 'require_ablation': True},
        'Short': {'min_experiment_runs': 3, 'require_ablation': False},
        'Letter': {'min_experiment_runs': 3, 'require_ablation': False},
    }
    pt = frontmatter.get('paper_type', 'NeurIPS')
    t = thresholds.get(pt, thresholds['NeurIPS'])
    print(json.dumps({
        'min_experiment_runs': t['min_experiment_runs'],
        'require_ablation': frontmatter.get('require_ablation', t['require_ablation']),
    }))
else:
    print(json.dumps({'min_experiment_runs': 3, 'require_ablation': True}))
"
}
CONFIG=$(load_config)
MIN_RUNS=$(echo "$CONFIG" | python3 -c "import sys,json; print(json.load(sys.stdin)['min_experiment_runs'])")
REQUIRE_ABLATION=$(echo "$CONFIG" | python3 -c "import sys,json; print(json.load(sys.stdin)['require_ablation'])")

check_runnable() {
    local file="$1"
    python3 -m py_compile "$file" 2>/dev/null && echo "true" || echo "false"
}

check_real_data() {
    local file="$1"
    if grep -qE '(torchvision|torch.utils.data|tensorflow_datasets|sklearn.datasets|load_dataset|huggingface|datasets\.load|from torchvision|from tensorflow|from sklearn|from huggingface|from datasets)' "$file"; then
        echo "true"
    elif grep -qE '(wget|curl.*download|urllib\.request)' "$file"; then
        echo "true"
    else
        echo "false"
    fi
}

count_runs() {
    if [[ -d "$1" ]]; then
        ls "$1"/run_*.log 2>/dev/null | wc -l || echo "0"
    else
        echo "0"
    fi
}

check_ablation() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "false"
        return
    fi
    if grep -qiE 'ablation' "$file"; then
        echo "true"
    else
        echo "false"
    fi
}

check_reproducibility_json() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "false"
        return
    fi
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

# EXP-007: Random seed fixed
check_seed_fixed() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        echo "false"
        return
    fi
    if grep -qrE '(random\.seed|torch\.manual_seed|np\.random\.seed|set_seed|manual_seed_all)' "$dir"/*.py 2>/dev/null; then
        echo "true"
    else
        echo "false"
    fi
}

# EXP-009: Experiment results traceable to logs
check_logs_traceable() {
    local logs_dir="$1"
    if [[ ! -d "$logs_dir" ]]; then
        echo "false"
        return
    fi
    local count
    count=$(find "$logs_dir" -name "run_*.log" 2>/dev/null | wc -l)
    if [[ "$count" -gt 0 ]]; then
        # Check that logs are non-empty and contain key metrics
        local non_empty=0
        while IFS= read -r logfile; do
            [[ -z "$logfile" ]] && continue
            if [[ -s "$logfile" ]]; then
                # Basic content check: does it look like experiment output?
                if grep -qiE '(accuracy|loss|metric|epoch|result|run)' "$logfile" 2>/dev/null; then
                    ((non_empty++))
                fi
            fi
        done < <(find "$logs_dir" -name "run_*.log" 2>/dev/null)
        if [[ "$non_empty" -gt 0 ]]; then
            echo "true"
        else
            echo "false"
        fi
    else
        echo "false"
    fi
}

# EXP-010: GPU info recorded
check_gpu_info() {
    local dir="$1"
    local repro_file="${2:-.paper/output/reproducibility.json}"
    if [[ -f "$repro_file" ]]; then
        if grep -qiE '(gpu|cuda|nvidia|rtx|geforce|tesla|a100|v100)' "$repro_file" 2>/dev/null; then
            echo "true"
        else
            echo "false"
        fi
    else
        echo "false"
    fi
}

check_domain() {
    [[ -f "$1" ]] && python3 -c "import json; print(json.load(open('$1')).get('paper_domain', 'ai-experimental'))" 2>/dev/null || echo "ai-experimental"
}

# EXP-012: Uncertainty calculation (physics)
check_uncertainty() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "false"
        return
    fi
    if grep -qiE '(uncertainty|error.*propagat|propagat.*error|confidence.*interval|standard.*deviation|delta.*method)' "$file"; then
        echo "true"
    else
        echo "false"
    fi
}

# EXP-013: Equipment calibration (physics)
check_equipment_calibration() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "false"
        return
    fi
    # Check for equipment/instrument mentions with precision/resolution info
    if grep -qiE '(instrument|equipment|device|apparatus|calibrat|precision|resolution|accuracy.*m|V|meter|volt|ohm)' "$file"; then
        echo "true"
    else
        echo "false"
    fi
}

main() {
    local run_pass="false"
    local run_ev=""
    local runs_pass="false"
    local runs_ev=""
    local seed_pass="false"
    local seed_ev=""
    local trace_pass="false"
    local trace_ev=""
    local real_data_pass="false"
    local real_data_ev=""

    # EXP-001: Runnable code
    if [[ -f "$CODE_DIR/main.py" ]]; then
        if [[ "$(check_runnable "$CODE_DIR/main.py")" == "true" ]]; then
            run_pass="true"
            run_ev="代码可编译，无语法错误"
        else
            run_pass="false"
            run_ev="代码存在语法错误"
        fi
    else
        run_pass="false"
        run_ev="code/main.py 不存在"
    fi

    # EXP-003: Run count
    local runs
    runs=$(count_runs "$LOGS_DIR")
    local min="3"
    if [[ -f "$PAPER_TYPE" ]]; then
        min=$(python3 -c "import json; print(json.load(open('$PAPER_TYPE')).get('derived_thresholds', {}).get('min_experiment_runs', 3))" 2>/dev/null || echo "3")
    fi

    if [[ "$runs" -ge "$min" ]]; then
        runs_pass="true"
        runs_ev="独立运行次数: $runs >= 门槛: $min"
    else
        runs_pass="false"
        runs_ev="独立运行次数: $runs < 门槛: $min"
    fi

    # EXP-005: Real dataset usage (script)
    if [[ -f "$CODE_DIR/main.py" ]]; then
        if [[ "$(check_real_data "$CODE_DIR/main.py")" == "true" ]]; then
            real_data_pass="true"
            real_data_ev="检测到真实数据集加载或下载逻辑"
        else
            real_data_pass="false"
            real_data_ev="未检测到真实数据集加载/下载逻辑（torchvision/tensorflow/sklearn/huggingface/datasets/wget/curl）"
        fi
    else
        real_data_pass="false"
        real_data_ev="code/main.py 不存在"
    fi

    # EXP-007: Random seed fixed
    if [[ -d "$CODE_DIR" ]]; then
        if [[ "$(check_seed_fixed "$CODE_DIR")" == "true" ]]; then
            seed_pass="true"
            seed_ev="代码包含随机种子固定"
        else
            seed_pass="false"
            seed_ev="代码缺少随机种子固定"
        fi
    else
        seed_pass="false"
        seed_ev="code 目录不存在"
    fi

    # EXP-009: Results traceable to logs
    if [[ -d "$LOGS_DIR" ]]; then
        if [[ "$(check_logs_traceable "$LOGS_DIR")" == "true" ]]; then
            trace_pass="true"
            trace_ev="run_*.log 存在且包含实验指标"
        else
            trace_pass="false"
            trace_ev="run_*.log 不存在或内容为空"
        fi
    else
        trace_pass="false"
        trace_ev="logs 目录不存在"
    fi

    # EXP-010: GPU info recorded
    local gpu_pass="false"
    local gpu_ev=""
    if [[ -d "$CODE_DIR" ]]; then
        if [[ "$(check_gpu_info "$CODE_DIR")" == "true" ]]; then
            gpu_pass="true"
            gpu_ev="GPU 信息已记录"
        else
            gpu_pass="false"
            gpu_ev="GPU 信息未记录（advisory）"
        fi
    else
        gpu_pass="false"
        gpu_ev="code 目录不存在"
    fi

    # EXP-011, EXP-012, EXP-013: Physics domain checks
    local physics_pass="true"
    local physics_ev="非 physics domain 或无需检查"
    local uncertainty_pass="true"
    local uncertainty_ev="非 physics domain 或无需检查"
    local equip_pass="true"
    local equip_ev="非 physics domain 或无需检查"

    if [[ -f "$PAPER_TYPE" ]]; then
        local domain
        domain=$(check_domain "$PAPER_TYPE")
        if [[ "$domain" == "physics" ]]; then
            # EXP-012: Uncertainty calculation
            if [[ -f "$DRAFT_FILE" ]]; then
                if [[ "$(check_uncertainty "$DRAFT_FILE")" == "true" ]]; then
                    uncertainty_pass="true"
                    uncertainty_ev="包含不确定度/误差传递计算"
                else
                    uncertainty_pass="false"
                    uncertainty_ev="缺少不确定度/误差传递计算"
                fi
            else
                uncertainty_pass="false"
                uncertainty_ev="draft.tex 不存在"
            fi

            # EXP-013: Equipment calibration
            if [[ -f "$DRAFT_FILE" ]]; then
                if [[ "$(check_equipment_calibration "$DRAFT_FILE")" == "true" ]]; then
                    equip_pass="true"
                    equip_ev="包含设备/仪器信息"
                else
                    equip_pass="false"
                    equip_ev="缺少设备/仪器信息"
                fi
            else
                equip_pass="false"
                equip_ev="draft.tex 不存在"
            fi

            physics_ev="Physics domain 检查完成"
        fi
    fi

    echo '{"results":['
    echo "{\"id\":\"EXP-001\",\"pass\":$run_pass,\"evidence\":\"$run_ev\"}"
    echo ",{\"id\":\"EXP-003\",\"pass\":$runs_pass,\"evidence\":\"$runs_ev\"}"
    echo ",{\"id\":\"EXP-005\",\"pass\":$real_data_pass,\"evidence\":\"$real_data_ev\"}"
    echo ",{\"id\":\"EXP-007\",\"pass\":$seed_pass,\"evidence\":\"$seed_ev\"}"
    echo ",{\"id\":\"EXP-009\",\"pass\":$trace_pass,\"evidence\":\"$trace_ev\"}"
    echo ",{\"id\":\"EXP-010\",\"pass\":$gpu_pass,\"evidence\":\"$gpu_ev\"}"
    echo ",{\"id\":\"EXP-012\",\"pass\":$uncertainty_pass,\"evidence\":\"$uncertainty_ev\"}"
    echo ",{\"id\":\"EXP-013\",\"pass\":$equip_pass,\"evidence\":\"$equip_ev\"}"
    echo ']}'
}

main

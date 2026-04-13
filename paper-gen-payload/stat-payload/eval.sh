#!/usr/bin/env bash
set -euo pipefail

# Stat Loop Evaluation Script
# Configuration inherited from parent payload's session.md

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_SESSION="$SCRIPT_DIR/../session.md"

DRAFT_FILE="${DRAFT_FILE:-.paper/output/draft.tex}"
CODE_DIR="${CODE_DIR:-.paper/output/code}"

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
        'domain': frontmatter.get('domain', 'ai-exp'),
    }))
else:
    print(json.dumps({'min_experiment_runs': 3, 'require_ablation': True, 'domain': 'ai-exp'}))
"
}
CONFIG=$(load_config)
MIN_RUNS=$(echo "$CONFIG" | python3 -c "import sys,json; print(json.load(sys.stdin)['min_experiment_runs'])")
REQUIRE_ABLATION=$(echo "$CONFIG" | python3 -c "import sys,json; print(json.load(sys.stdin)['require_ablation'])")
DOMAIN=$(echo "$CONFIG" | python3 -c "import sys,json; print(json.load(sys.stdin)['domain'])")

# Cherry-picking signal words (case-insensitive)
CHERRY_SIGNALS=(
    "selectively reported"
    "best result"
    "best performance"
    "best model"
    "only show"
    "only report"
    "only report the"
    "we selected"
    "we chose to show"
    "chosen result"
    "picked result"
    "filtered result"
    "filtered out"
    "discard result"
    "discard the"
    "omit result"
    "omit the"
    "not shown"
    "omitted for clarity"
    "excluded from"
    "removed from"
    "hiding result"
)

# Neural network visualization patterns
NN_VIZ_PATTERNS=(
    "attention map"
    "saliency map"
    "grad-cam"
    "gradient attribution"
    "feature visualization"
    "t-SNE embedding"
    "UMAP visualization"
    "activation map"
)

check_mean_std() {
    [[ -f "$1" ]] && grep -qE '[0-9]+\.[0-9]+[±\\]pm\s*[0-9]+\.[0-9]+' "$1" && echo "true" || echo "false"
}

check_grid_independence() {
    [[ -f "$1" ]] && grep -qiE '(grid.*independ|mesh.*converg|convergen.*grid|grid.*test|grid.*study)' "$1" && echo "true" || echo "false"
}

check_convergence_order() {
    [[ -f "$1" ]] && grep -qiE '(convergen.*order|order.*converg|order of convergence|first.order|second.order)' "$1" && echo "true" || echo "false"
}

check_stat_sig() {
    # Check for p-value, confidence interval, or effect size
    [[ -f "$1" ]] && grep -qiE '(p.value|p\s*[<>=]\s*0?\.[0-9]+|confidence interval|effect size|cohen.*d|statistically significant)' "$1" && echo "true" || echo "false"
}

check_cherry_picking() {
    # Script-level cherry-picking detection via signal words
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "false"
        return
    fi

    local content
    content=$(cat "$file")
    local content_lower
    content_lower=$(printf '%s' "$content" | tr '[:upper:]' '[:lower:]')

    local found=""
    for signal in "${CHERRY_SIGNALS[@]}"; do
        local signal_lower
        signal_lower=$(printf '%s' "$signal" | tr '[:upper:]' '[:lower:]')
        if [[ "$content_lower" == *"$signal_lower"* ]]; then
            found="$found; $signal"
        fi
    done

    if [[ -n "$found" ]]; then
        echo "true"  # Cherry-picking signals found (should fail)
    else
        echo "false"  # No signals found (pass)
    fi
}

check_random_seed() {
    [[ -d "$1" ]] && grep -qrE '(random\.seed|torch\.manual_seed|np\.random\.seed|set_seed|manual_seed_all|seed\()' "$1"/*.py 2>/dev/null && echo "true" || echo "false"
}

check_nn_viz() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "false"
        return
    fi
    local content
    content=$(cat "$file")
    local content_lower
    content_lower=$(printf '%s' "$content" | tr '[:upper:]' '[:lower:]')

    for pattern in "${NN_VIZ_PATTERNS[@]}"; do
        local pattern_lower
        pattern_lower=$(printf '%s' "$pattern" | tr '[:upper:]' '[:lower:]')
        if [[ "$content_lower" == *"$pattern_lower"* ]]; then
            echo "true"
            return
        fi
    done
    echo "false"
}

check_nn_viz_disclosed() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "false"
        return
    fi
    grep -qiE '(visualization.*method|method.*visualiz|we use.*visual|how we.*visual|tool for.*visualiz|technique.*visualiz|generated using|produced using)' "$file" && echo "true" || echo "false"
}

check_requires_ablation() {
    # This function is no longer used - config is loaded from parent session.md
    echo "false"
}

check_ablation_present() {
    [[ -f "$1" ]] && grep -qiE 'ablation' "$1" && echo "true" || echo "false"
}

check_in_dataset() {
    # Check that dataset is cited with version/source
    [[ -f "$1" ]] && grep -qiE '(dataset.*version|dataset.*doi|dataset.*url|http.*dataset|zenodo.*dataset)' "$1" && echo "true" || echo "false"
}

check_hyperparameters() {
    # Check that hyperparameters are listed (not vague "as in paper X")
    [[ -f "$1" ]] && grep -qiE '(hyperparameter|learning rate|batch size|weight decay|momentum|epoch|optimizer)' "$1" && echo "true" || echo "false"
}

count_runs() {
    local logs_dir="${1:-.paper/output/logs}"
    if [[ -d "$logs_dir" ]]; then
        find "$logs_dir" -name "run_*.log" 2>/dev/null | wc -l || echo "0"
    else
        echo "0"
    fi
}

main() {
    local mean_pass="false"
    local mean_ev=""
    local grid_pass="true"
    local grid_ev="非 numerical 领域"
    local conv_pass="true"
    local conv_ev="非 numerical 领域"
    local cherry_pass="false"
    local cherry_ev=""
    local seed_pass="false"
    local seed_ev=""
    local hyper_pass="false"
    local hyper_ev=""
    local dataset_pass="false"
    local dataset_ev=""
    local runs_pass="false"
    local runs_ev=""
    local abla_pass="false"
    local abla_ev=""
    local nn_viz_pass="false"
    local nn_viz_ev=""

    # STAT-001: Mean±Std
    if [[ -f "$DRAFT_FILE" ]]; then
        if [[ "$(check_mean_std "$DRAFT_FILE")" == "true" ]]; then
            mean_pass="true"
            mean_ev="包含 mean±std 报告"
        else
            mean_pass="false"
            mean_ev="缺少 mean±std 报告"
        fi
    else
        mean_pass="false"
        mean_ev="draft.tex 不存在"
    fi

    # STAT-003: Cherry-picking detection (Script level)
    # Note: This is a signal-word based heuristic check.
    # LLM evaluator (STAT-012) handles semantic verification.
    if [[ -f "$DRAFT_FILE" ]]; then
        local has_signals
        has_signals=$(check_cherry_picking "$DRAFT_FILE")
        if [[ "$has_signals" == "true" ]]; then
            cherry_pass="false"
            cherry_ev="检测到 cherry-picking 信号词（需人工确认是否为合理描述）"
        else
            cherry_pass="true"
            cherry_ev="未检测到 cherry-picking 信号词"
        fi
    else
        cherry_pass="false"
        cherry_ev="draft.tex 不存在"
    fi

    # STAT-004/005: Numerical domain checks
    if [[ "$DOMAIN" == "numerical" ]]; then
        if [[ -f "$DRAFT_FILE" ]]; then
            if [[ "$(check_grid_independence "$DRAFT_FILE")" == "true" ]]; then
                grid_pass="true"
                grid_ev="包含 Grid Independence 测试"
            else
                grid_pass="false"
                grid_ev="缺少 Grid Independence 测试"
            fi

            if [[ "$(check_convergence_order "$DRAFT_FILE")" == "true" ]]; then
                conv_pass="true"
                conv_ev="包含 Convergence Order 报告"
            else
                conv_pass="false"
                conv_ev="缺少 Convergence Order 报告"
            fi
        else
            grid_pass="false"
            grid_ev="draft.tex 不存在"
            conv_pass="false"
            conv_ev="draft.tex 不存在"
        fi
    else
        grid_pass="true"
        grid_ev="非数值计算领域，无需 Grid Independence"
        conv_pass="true"
        conv_ev="非数值计算领域，无需 Convergence Order"
    fi

    # STAT-006: Random seed fixed
    if [[ -d "$CODE_DIR" ]]; then
        if [[ "$(check_random_seed "$CODE_DIR")" == "true" ]]; then
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

    # STAT-007: Hyperparameters listed
    if [[ -f "$DRAFT_FILE" ]]; then
        if [[ "$(check_hyperparameters "$DRAFT_FILE")" == "true" ]]; then
            hyper_pass="true"
            hyper_ev="论文包含超参数列表"
        else
            hyper_pass="false"
            hyper_ev="论文缺少超参数列表"
        fi
    else
        hyper_pass="false"
        hyper_ev="draft.tex 不存在"
    fi

    # STAT-008: Dataset source cited
    if [[ -f "$DRAFT_FILE" ]]; then
        if [[ "$(check_in_dataset "$DRAFT_FILE")" == "true" ]]; then
            dataset_pass="true"
            dataset_ev="数据集包含版本/DOI/URL 来源引用"
        else
            dataset_pass="false"
            dataset_ev="数据集缺少版本/DOI/URL 来源引用"
        fi
    else
        dataset_pass="false"
        dataset_ev="draft.tex 不存在"
    fi

    # STAT-009: Independent run count
    local runs
    runs=$(count_runs ".paper/output/logs")
    if [[ "$runs" -ge "$MIN_RUNS" ]]; then
        runs_pass="true"
        runs_ev="独立运行次数: $runs >= 门槛: $MIN_RUNS"
    else
        runs_pass="false"
        runs_ev="独立运行次数: $runs < 门槛: $MIN_RUNS"
    fi

    # STAT-010: Ablation study (when required)
    if [[ "$REQUIRE_ABLATION" == "True" ]]; then
        if [[ -f "$DRAFT_FILE" ]] && [[ "$(check_ablation_present "$DRAFT_FILE")" == "true" ]]; then
            abla_pass="true"
            abla_ev="包含 Ablation Study 章节"
        else
            abla_pass="false"
            abla_ev="require_ablation=true 但缺少 Ablation Study"
        fi
    else
        abla_pass="true"
        abla_ev="无需 Ablation Study"
    fi

    # STAT-011: NN visualization disclosure
    if [[ -f "$DRAFT_FILE" ]]; then
        if [[ "$(check_nn_viz "$DRAFT_FILE")" == "true" ]]; then
            if [[ "$(check_nn_viz_disclosed "$DRAFT_FILE")" == "true" ]]; then
                nn_viz_pass="true"
                nn_viz_ev="神经网络可视化方法已披露"
            else
                nn_viz_pass="false"
                nn_viz_ev="使用神经网络可视化但未披露方法"
            fi
        else
            nn_viz_pass="true"
            nn_viz_ev="未使用神经网络可视化"
        fi
    else
        nn_viz_pass="false"
        nn_viz_ev="draft.tex 不存在"
    fi

    echo '{"results":['
    echo "{\"id\":\"STAT-001\",\"pass\":$mean_pass,\"evidence\":\"$mean_ev\"}"
    echo ",{\"id\":\"STAT-003\",\"pass\":$cherry_pass,\"evidence\":\"$cherry_ev\"}"
    echo ",{\"id\":\"STAT-004\",\"pass\":$grid_pass,\"evidence\":\"$grid_ev\"}"
    echo ",{\"id\":\"STAT-005\",\"pass\":$conv_pass,\"evidence\":\"$conv_ev\"}"
    echo ",{\"id\":\"STAT-006\",\"pass\":$seed_pass,\"evidence\":\"$seed_ev\"}"
    echo ",{\"id\":\"STAT-007\",\"pass\":$hyper_pass,\"evidence\":\"$hyper_ev\"}"
    echo ",{\"id\":\"STAT-008\",\"pass\":$dataset_pass,\"evidence\":\"$dataset_ev\"}"
    echo ",{\"id\":\"STAT-009\",\"pass\":$runs_pass,\"evidence\":\"$runs_ev\"}"
    echo ",{\"id\":\"STAT-010\",\"pass\":$abla_pass,\"evidence\":\"$abla_ev\"}"
    echo ",{\"id\":\"STAT-011\",\"pass\":$nn_viz_pass,\"evidence\":\"$nn_viz_ev\"}"
    echo ']}'
}

main

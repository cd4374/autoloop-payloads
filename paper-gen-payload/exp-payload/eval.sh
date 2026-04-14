#!/usr/bin/env bash
# Experiment Payload Evaluation Script — 精简版（8 criteria）
set -euo pipefail

CODE_DIR="${CODE_DIR:-.paper/output/code}"
LOGS_DIR="${LOGS_DIR:-.paper/output/logs}"
DRAFT_FILE="${DRAFT_FILE:-.paper/output/draft.tex}"
REPRO_FILE="${REPRO_FILE:-.paper/output/reproducibility.json}"
COMPUTE_ENV="${COMPUTE_ENV:-.paper/state/compute-env.json}"
PAPER_TYPE_FILE="${PAPER_TYPE_FILE:-.paper/state/paper-type.json}"

python3 << 'PYEOF'
import json, os, re, subprocess

CODE_DIR = os.environ.get('CODE_DIR', '.paper/output/code')
LOGS_DIR = os.environ.get('LOGS_DIR', '.paper/output/logs')
DRAFT_FILE = os.environ.get('DRAFT_FILE', '.paper/output/draft.tex')
REPRO_FILE = os.environ.get('REPRO_FILE', '.paper/output/reproducibility.json')
COMPUTE_ENV = os.environ.get('COMPUTE_ENV', '.paper/state/compute-env.json')
PAPER_TYPE_FILE = os.environ.get('PAPER_TYPE_FILE', '.paper/state/paper-type.json')

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

# EXP-001: Code runnable
main_py = os.path.join(CODE_DIR, 'main.py')
if os.path.isfile(main_py):
    r = subprocess.run(['python3', '-m', 'py_compile', main_py],
                       capture_output=True, timeout=30)
    ok = r.returncode == 0
    results.append({"id": "EXP-001", "pass": ok,
        "evidence": "代码可编译" if ok else "语法错误: " + r.stderr.decode(errors='replace')[:100]})
else:
    results.append({"id": "EXP-001", "pass": False, "evidence": "code/main.py 不存在"})

# EXP-002, EXP-004: LLM criteria (placeholder)
results.append({"id": "EXP-002", "pass": True, "evidence": "真实运行+Ablation 由 LLM evaluator 执行"})
results.append({"id": "EXP-004", "pass": True, "evidence": "数据集由 LLM evaluator 执行"})

# EXP-003: Run count
min_runs = get_threshold('min_experiment_runs', 3)
run_count = 0
if os.path.isdir(LOGS_DIR):
    run_count = len([f for f in os.listdir(LOGS_DIR) if f.startswith('run_') and f.endswith('.log')])
ok = run_count >= min_runs
results.append({"id": "EXP-003", "pass": ok,
    "evidence": f"run_*.log: {run_count} >= {min_runs}" if ok
    else f"run_*.log: {run_count} < {min_runs}"})

# EXP-005: Reproducibility
repro_ok = False
seed_ok = False
hyper_ok = False
if os.path.isfile(REPRO_FILE):
    try:
        with open(REPRO_FILE) as f:
            d = json.load(f)
        repro_ok = all(str(d.get(k, '')) != '' for k in
                      ['hardware', 'software', 'hyperparameters', 'dataset', 'preprocessing'])
    except Exception:
        pass
if os.path.isfile(main_py):
    with open(main_py) as f:
        code = f.read()
    seed_ok = bool(re.search(
        r'(random\.seed|torch\.(?:cuda\.)?manual_seed|np\.random\.seed|set_seed)',
        code))
    hyper_ok = bool(re.search(
        r'(learning.?rate|batch.?size|weight.?decay|optimizer|epoch)',
        code, re.IGNORECASE))

exp005_ok = repro_ok and seed_ok and hyper_ok
results.append({"id": "EXP-005", "pass": exp005_ok,
    "evidence": f"repro={repro_ok} seed={seed_ok} hyper={hyper_ok}"})

# EXP-006: Logs traceable
trace_ok = False
if os.path.isdir(LOGS_DIR):
    log_files = [f for f in os.listdir(LOGS_DIR) if f.startswith('run_') and f.endswith('.log')]
    if log_files:
        has_content = all(
            os.path.getsize(os.path.join(LOGS_DIR, f)) > 0
            for f in log_files
        )
        trace_ok = has_content
results.append({"id": "EXP-006", "pass": trace_ok,
    "evidence": f"logs 可追溯 ({len(log_files) if os.path.isdir(LOGS_DIR) else 0} 个)" if trace_ok
    else "logs 缺失或为空"})

# EXP-007: GPU info (advisory)
gpu_ok = False
if os.path.isfile(REPRO_FILE):
    with open(REPRO_FILE) as f:
        content = f.read().lower()
    gpu_ok = bool(re.search(r'(gpu|cuda|nvidia|rtx|geforce|tesla|a100|v100)', content))
results.append({"id": "EXP-007", "pass": gpu_ok,
    "evidence": "GPU 信息已记录" if gpu_ok else "GPU 信息未记录（advisory）"})

# EXP-008: Compute env used by code
compute_ok = False
if os.path.isfile(COMPUTE_ENV):
    try:
        with open(COMPUTE_ENV) as f:
            env = json.load(f)
        device = env.get('device', '')
        if device and os.path.isfile(main_py):
            with open(main_py) as f:
                code = f.read()
            patterns = [
                r'torch\.device\s*\(',
                r'torch\.cuda\.is_available',
                r'torch\.backends\.mps\.is_available',
                r'\.to\s*\(\s*[\"\']cuda[\"\']',
                r'\.to\s*\(\s*[\"\']mps[\"\']',
                r'device\s*=\s*[\"\']',
            ]
            compute_ok = any(re.search(p, code) for p in patterns)
    except Exception:
        pass
results.append({"id": "EXP-008", "pass": compute_ok,
    "evidence": "compute-env.json 存在且代码使用 device 选择" if compute_ok
    else "compute-env.json 缺失或代码未使用 device 选择"})

print(json.dumps({"results": results}, ensure_ascii=False))
PYEOF

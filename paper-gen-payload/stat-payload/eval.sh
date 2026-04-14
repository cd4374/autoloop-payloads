#!/usr/bin/env bash
# Statistics Payload Evaluation Script — 精简版（5 criteria）
set -euo pipefail

DRAFT_FILE="${DRAFT_FILE:-.paper/output/draft.tex}"
PAPER_TYPE_FILE="${PAPER_TYPE_FILE:-.paper/state/paper-type.json}"

python3 << 'PYEOF'
import json, os, re

DRAFT_FILE = os.environ.get('DRAFT_FILE', '.paper/output/draft.tex')
PAPER_TYPE_FILE = os.environ.get('PAPER_TYPE_FILE', '.paper/state/paper-type.json')

results = []

def get_domain():
    try:
        if os.path.isfile(PAPER_TYPE_FILE):
            with open(PAPER_TYPE_FILE) as f:
                return json.load(f).get('paper_domain', 'ai-exp')
    except Exception:
        pass
    return 'ai-exp'

domain = get_domain()

# STAT-001: Mean±std
if os.path.isfile(DRAFT_FILE):
    with open(DRAFT_FILE) as f:
        tex = f.read()
    has_mean_std = bool(re.search(r'[0-9]+\.[0-9]+\s*(?:[\u00b1±]|\\pm)\s*[0-9]+\.[0-9]+', tex))
    results.append({"id": "STAT-001", "pass": has_mean_std,
        "evidence": "包含 mean±std" if has_mean_std else "缺少 mean±std 报告"})
else:
    results.append({"id": "STAT-001", "pass": False, "evidence": "draft.tex 不存在"})

# STAT-002, STAT-003: LLM criteria
results.append({"id": "STAT-002", "pass": True, "evidence": "显著性检验由 LLM evaluator 执行"})
results.append({"id": "STAT-003", "pass": True, "evidence": "Cherry-picking 由 LLM evaluator 执行"})

# STAT-004, STAT-005: Numerical domain only
if domain == 'numerical':
    with open(DRAFT_FILE) as f:
        tex = f.read()
    grid_ok = bool(re.search(r'grid.*independ|mesh.*converg|convergen.*grid', tex, re.IGNORECASE))
    conv_ok = bool(re.search(r'convergen.*order|order.*converg|first.order|second.order', tex, re.IGNORECASE))
    results.append({"id": "STAT-004", "pass": grid_ok,
        "evidence": "包含 Grid Independence" if grid_ok else "缺少 Grid Independence"})
    results.append({"id": "STAT-005", "pass": conv_ok,
        "evidence": "包含 Convergence Order" if conv_ok else "缺少 Convergence Order"})
else:
    results.append({"id": "STAT-004", "pass": True, "evidence": "非 numerical domain"})
    results.append({"id": "STAT-005", "pass": True, "evidence": "非 numerical domain"})

print(json.dumps({"results": results}, ensure_ascii=False))
PYEOF

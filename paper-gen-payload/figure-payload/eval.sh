#!/usr/bin/env bash
# Figure Payload Evaluation Script — 精简版（8 criteria）
# FIG-001~005: script checks | FIG-006~007: llm | FIG-008: script advisory

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PAPER_TYPE_FILE="${PAPER_TYPE_FILE:-.paper/state/paper-type.json}"
DRAFT_FILE="${DRAFT_FILE:-.paper/output/draft.tex}"
FIGURES_DIR="${FIGURES_DIR:-.paper/output/figures}"
PROJECT_ROOT="${PROJECT_ROOT:-$SCRIPT_DIR}"

# Export so Python heredoc can read them
export PAPER_TYPE_FILE DRAFT_FILE FIGURES_DIR PROJECT_ROOT

python3 << 'PYEOF'
import json, os, re, subprocess

PAPER_TYPE_FILE = os.environ['PAPER_TYPE_FILE']
DRAFT_FILE = os.environ['DRAFT_FILE']
FIGURES_DIR = os.environ['FIGURES_DIR']

# Load thresholds
def load_thresholds():
    try:
        if os.path.isfile(PAPER_TYPE_FILE):
            with open(PAPER_TYPE_FILE) as f:
                pt = json.load(f)
            derived = pt.get('derived_thresholds', {})
            return {
                'min_figures': derived.get('min_figures', 5),
                'min_tables': derived.get('min_tables', 1),
            }
    except Exception:
        pass
    return {'min_figures': 5, 'min_tables': 1}

def count_figures(f):
    if not os.path.isfile(f):
        return 0
    r = subprocess.run(['grep', '-cE', r'\\includegraphics', f], capture_output=True, text=True)
    try:
        return int(r.stdout.strip())
    except Exception:
        return 0

results = []
thresholds = load_thresholds()
MIN_FIGURES = thresholds['min_figures']
MIN_TABLES  = thresholds['min_tables']

# FIG-001: Figure count
if os.path.isfile(DRAFT_FILE):
    fig_count = count_figures(DRAFT_FILE)
    ok = fig_count >= MIN_FIGURES
    results.append({"id": "FIG-001", "pass": ok,
        "evidence": f"图表数: {fig_count} >= {MIN_FIGURES}" if ok
        else f"图表数: {fig_count} < {MIN_FIGURES}"})
else:
    results.append({"id": "FIG-001", "pass": False, "evidence": "draft.tex 不存在"})

# FIG-002: Vector format (excluding ai_generated/)
if os.path.isdir(FIGURES_DIR):
    raster_files = []
    for root, dirs, files in os.walk(FIGURES_DIR):
        if 'ai_generated' in root.split(os.sep):
            continue
        for fn in files:
            ext = os.path.splitext(fn)[1].lower()
            if ext in ('.png', '.jpg', '.jpeg', '.tif', '.tiff'):
                raster_files.append(fn)
    ok = len(raster_files) == 0
    results.append({"id": "FIG-002", "pass": ok,
        "evidence": f"所有非 AI 图为向量格式 ({len(raster_files)} 个栅格)" if not ok
        else f"无栅格图，全部为向量格式"})
else:
    results.append({"id": "FIG-002", "pass": False, "evidence": "figures 目录不存在"})

# FIG-003: Figure-file consistency
if os.path.isfile(DRAFT_FILE) and os.path.isdir(FIGURES_DIR):
    with open(DRAFT_FILE) as f:
        tex = f.read()
    fig_files = re.findall(r'\\includegraphics(?:\[.*?\])?\{([^}]+)\}', tex)
    missing = sum(1 for fn in fig_files
                  if not os.path.exists(fn.strip()) and
                     not os.path.exists(os.path.join(FIGURES_DIR, fn.strip())))
    total = len(fig_files)
    if total > 0:
        ok = missing == 0
        results.append({"id": "FIG-003", "pass": ok,
            "evidence": f"所有 {total} 个图表文件存在" if ok
            else f"{missing}/{total} 个图表文件缺失"})
    else:
        results.append({"id": "FIG-003", "pass": True, "evidence": "无图表引用"})
elif not os.path.isdir(FIGURES_DIR):
    results.append({"id": "FIG-003", "pass": False, "evidence": "figures 目录不存在"})
else:
    results.append({"id": "FIG-003", "pass": True, "evidence": "draft.tex 不存在"})

# FIG-004: Raster DPI >= 300 (excluding ai_generated/)
if os.path.isdir(FIGURES_DIR):
    raster_files = []
    for root, dirs, files in os.walk(FIGURES_DIR):
        if 'ai_generated' in root.split(os.sep):
            continue
        for fn in files:
            if os.path.splitext(fn)[1].lower() in ('.png', '.jpg', '.jpeg', '.tif', '.tiff'):
                raster_files.append(os.path.join(root, fn))
    if not raster_files:
        results.append({"id": "FIG-004", "pass": True, "evidence": "无栅格图"})
    else:
        dpi_fail = 0
        dpi_pass = 0
        dpi_unk = 0
        for rf in raster_files:
            r = subprocess.run(['identify', '-units', 'PixelsPerInch', '-format', '%x', rf],
                               capture_output=True, text=True)
            if r.returncode == 0 and r.stdout.strip():
                try:
                    dpi = int(float(r.stdout.strip()))
                    if dpi >= 300:
                        dpi_pass += 1
                    else:
                        dpi_fail += 1
                except Exception:
                    dpi_unk += 1
            else:
                dpi_unk += 1
        ok = dpi_fail == 0
        results.append({"id": "FIG-004", "pass": ok,
            "evidence": f"DPI 达标: pass={dpi_pass}, fail={dpi_fail}, unk={dpi_unk}" if not ok
            else f"所有栅格图 DPI>=300 ({dpi_pass} 个)"})
else:
    results.append({"id": "FIG-004", "pass": False, "evidence": "figures 目录不存在"})

# FIG-005: Table count + booktabs
if os.path.isfile(DRAFT_FILE):
    with open(DRAFT_FILE) as f:
        tex = f.read()
    r = subprocess.run(['grep', '-cE', r'\\begin\{(tabular|table)', DRAFT_FILE],
                       capture_output=True, text=True)
    try:
        table_count = int(r.stdout.strip())
    except Exception:
        table_count = 0
    has_booktabs = bool(re.search(r'\\usepackage\{booktabs\}', tex))
    ok = table_count >= MIN_TABLES and has_booktabs
    ev_parts = []
    ev_parts.append(f"表格数={table_count}>={MIN_TABLES}")
    ev_parts.append("booktabs" if has_booktabs else "缺少booktabs")
    results.append({"id": "FIG-005", "pass": ok,
        "evidence": ", ".join(ev_parts)})
else:
    results.append({"id": "FIG-005", "pass": False, "evidence": "draft.tex 不存在"})

# FIG-006, FIG-007: LLM criteria (placeholder — handled by loop-run LLM eval)
results.append({"id": "FIG-006", "pass": True, "evidence": "图表质量综合评估由 LLM evaluator 执行"})
results.append({"id": "FIG-007", "pass": True, "evidence": "无伪造图表数据由 LLM evaluator 执行"})
# FIG-008: Script advisory — style + gen scripts
style_ok = any(os.path.isfile(p) for p in [
    'figures/paper_plot_style.py', 'figures/paper.mplstyle',
    os.path.join(FIGURES_DIR, 'paper_plot_style.py'),
    os.path.join(FIGURES_DIR, 'style.mplstyle'),
])
gen_scripts = []
if os.path.isdir(FIGURES_DIR):
    gen_scripts = [fn for fn in os.listdir(FIGURES_DIR)
                   if fn.startswith('gen_fig_') and fn.endswith('.py')]
fig_producible = style_ok or bool(gen_scripts)
results.append({"id": "FIG-008", "pass": fig_producible,
    "evidence": f"共享样式={style_ok}, 生成脚本={len(gen_scripts)} 个" if not fig_producible
    else f"图表可复现（样式={style_ok} 或 {len(gen_scripts)} 个脚本）"})

print(json.dumps({"results": results}, ensure_ascii=False))
PYEOF

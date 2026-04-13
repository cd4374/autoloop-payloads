#!/usr/bin/env bash
# Figure Loop Evaluation Script
# Evaluates all evaluator=script criteria from criteria.md
# Both shell and Python sections read configuration from parent session.md

set -euo pipefail

# Resolve paths relative to this script's location (not cwd)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_SESSION="${PARENT_SESSION:-$SCRIPT_DIR/../session.md}"
DRAFT_FILE="${DRAFT_FILE:-.paper/output/draft.tex}"
FIGURES_DIR="${FIGURES_DIR:-.paper/output/figures}"

# Pass paths to Python via environment
export PARENT_SESSION DRAFT_FILE FIGURES_DIR

python3 << 'PYEOF'
import json, os, re, subprocess

# Read from environment (set by shell section above)
PARENT_SESSION = os.environ['PARENT_SESSION']
DRAFT_FILE = os.environ['DRAFT_FILE']
FIGURES_DIR = os.environ['FIGURES_DIR']

# Load thresholds from parent session.md
def load_thresholds():
    try:
        import yaml
        with open(PARENT_SESSION) as f:
            content = f.read()
        match = re.match(r'^---\n(.*?)\n---', content, re.DOTALL)
        if match:
            fm = yaml.safe_load(match.group(1))
            thresholds = {
                'NeurIPS': {'min_figures': 5, 'min_tables': 1},
                'ICML':    {'min_figures': 5, 'min_tables': 1},
                'ICLR':    {'min_figures': 5, 'min_tables': 1},
                'AAAI':    {'min_figures': 4, 'min_tables': 1},
                'Journal': {'min_figures': 5, 'min_tables': 2},
                'Short':   {'min_figures': 3, 'min_tables': 1},
                'Letter':  {'min_figures': 2, 'min_tables': 1},
            }
            pt = fm.get('paper_type', 'NeurIPS')
            return thresholds.get(pt, thresholds['NeurIPS'])
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
    if fig_count >= MIN_FIGURES:
        results.append({"id": "FIG-001", "pass": True,  "evidence": f"图表数: {fig_count} >= 门槛: {MIN_FIGURES}"})
    else:
        results.append({"id": "FIG-001", "pass": False, "evidence": f"图表数: {fig_count} < 门槛: {MIN_FIGURES}"})
else:
    results.append({"id": "FIG-001", "pass": False, "evidence": "draft.tex 不存在"})

# FIG-002: Vector format (excluding ai_generated/ for AI-generated architecture diagrams)
if os.path.isdir(FIGURES_DIR):
    vector_files = []
    raster_files = []
    for root, dirs, files in os.walk(FIGURES_DIR):
        # Skip ai_generated/ directory — AI-generated architecture figures are PNG by design
        if 'ai_generated' in root.split(os.sep):
            continue
        for fn in files:
            ext = os.path.splitext(fn)[1].lower()
            if ext in ('.pdf', '.eps'):
                vector_files.append(os.path.join(root, fn))
            elif ext in ('.png', '.jpg', '.jpeg', '.tif', '.tiff'):
                raster_files.append(os.path.join(root, fn))
    if not raster_files:
        results.append({"id": "FIG-002", "pass": True,
                        "evidence": f"所有非 AI 图为向量格式: {len(vector_files)} 个 .pdf/.eps"})
    else:
        results.append({"id": "FIG-002", "pass": False,
                        "evidence": f"存在 {len(raster_files)} 个栅格图（非 AI 图），应使用向量格式"})
else:
    results.append({"id": "FIG-002", "pass": False, "evidence": "figures 目录不存在"})

# FIG-012: Figure-file consistency
if os.path.isfile(DRAFT_FILE) and os.path.isdir(FIGURES_DIR):
    with open(DRAFT_FILE) as f:
        tex = f.read()
    fig_files = re.findall(r'\\includegraphics(?:\[.*?\])?\{([^}]+)\}', tex)
    missing = 0
    total = len(fig_files)
    for fn in fig_files:
        fn = fn.strip()
        if not os.path.exists(fn) and not os.path.exists(os.path.join(FIGURES_DIR, fn)):
            missing += 1
    if total > 0:
        if missing == 0:
            results.append({"id": "FIG-012", "pass": True,  "evidence": f"所有 {total} 个图表文件均存在"})
        else:
            results.append({"id": "FIG-012", "pass": False, "evidence": f"{missing}/{total} 个图表文件缺失"})
    else:
        results.append({"id": "FIG-012", "pass": True, "evidence": "无图表引用或文件目录不存在"})
else:
    results.append({"id": "FIG-012", "pass": True, "evidence": "无图表引用或文件目录不存在"})

# FIG-013: Table count
if os.path.isfile(DRAFT_FILE):
    r = subprocess.run(['grep', '-cE', r'\\begin\{(tabular|table)', DRAFT_FILE],
                       capture_output=True, text=True)
    try:
        table_count = int(r.stdout.strip())
    except Exception:
        table_count = 0
    if table_count >= MIN_TABLES:
        results.append({"id": "FIG-013", "pass": True,  "evidence": f"表格数: {table_count} >= 门槛: {MIN_TABLES}"})
    else:
        results.append({"id": "FIG-013", "pass": False, "evidence": f"表格数: {table_count} < 门槛: {MIN_TABLES}"})
else:
    results.append({"id": "FIG-013", "pass": False, "evidence": "draft.tex 不存在"})

# FIG-014: Table format (booktabs)
if os.path.isfile(DRAFT_FILE):
    with open(DRAFT_FILE) as f:
        tex = f.read()
    has_tabular = bool(re.search(r'\\begin\{tabular', tex))
    if not has_tabular:
        results.append({"id": "FIG-014", "pass": True, "evidence": "无表格"})
    elif re.search(r'\\usepackage\{booktabs\}', tex):
        results.append({"id": "FIG-014", "pass": True, "evidence": "表格使用 booktabs 格式"})
    else:
        results.append({"id": "FIG-014", "pass": False, "evidence": "表格未使用 booktabs 宏包"})
else:
    results.append({"id": "FIG-014", "pass": False, "evidence": "draft.tex 不存在"})

# FIG-018: Raster image DPI check (excluding ai_generated/)
if os.path.isdir(FIGURES_DIR):
    raster_files = []
    for root, dirs, files in os.walk(FIGURES_DIR):
        if 'ai_generated' in root.split(os.sep):
            continue
        for fn in files:
            ext = os.path.splitext(fn)[1].lower()
            if ext in ('.png', '.jpg', '.jpeg', '.tif', '.tiff'):
                raster_files.append(os.path.join(root, fn))
    if not raster_files:
        results.append({"id": "FIG-018", "pass": True, "evidence": "无栅格图或所有栅格图 DPI>=300"})
    else:
        dpi_fail = 0
        dpi_pass_count = 0
        dpi_unknown = 0
        for rf in raster_files:
            r = subprocess.run(['identify', '-units', 'PixelsPerInch', '-format', '%x', rf],
                               capture_output=True, text=True)
            if r.returncode == 0 and r.stdout.strip():
                try:
                    dpi = int(float(r.stdout.strip()))
                    if dpi >= 300:
                        dpi_pass_count += 1
                    else:
                        dpi_fail += 1
                except Exception:
                    dpi_unknown += 1
            else:
                size = os.path.getsize(rf)
                if size > 10240:
                    dpi_pass_count += 1
                else:
                    dpi_unknown += 1
        if dpi_fail > 0:
            results.append({"id": "FIG-018", "pass": False,
                            "evidence": f"{dpi_fail} 个栅格图 DPI<300，{dpi_pass_count} 个达标，{dpi_unknown} 个无法检测"})
        else:
            results.append({"id": "FIG-018", "pass": True,
                            "evidence": f"{dpi_pass_count} 个栅格图 DPI>=300，{dpi_unknown} 个无法检测"})
else:
    results.append({"id": "FIG-018", "pass": True, "evidence": "无栅格图或所有栅格图 DPI>=300"})

# FIG-020: 共享样式配置
style_configured = False
for cfg in ['figures/paper_plot_style.py', 'figures/paper.mplstyle', 'figures/style.mplstyle',
            os.path.join(FIGURES_DIR, 'paper_plot_style.py'),
            os.path.join(FIGURES_DIR, 'paper.mplstyle'),
            os.path.join(FIGURES_DIR, 'style.mplstyle')]:
    if os.path.isfile(cfg):
        style_configured = True
        break
results.append({"id": "FIG-020", "pass": style_configured,
                "evidence": "存在共享样式配置文件" if style_configured
                else "缺少共享样式配置文件 (paper_plot_style.py 或 .mplstyle)"})

# FIG-021: 一图表一脚本
gen_scripts = []
if os.path.isdir(FIGURES_DIR):
    for fn in os.listdir(FIGURES_DIR):
        if fn.startswith('gen_fig_') and fn.endswith('.py'):
            gen_scripts.append(fn)
results.append({"id": "FIG-021", "pass": bool(gen_scripts),
                "evidence": f"存在 {len(gen_scripts)} 个图表生成脚本" if gen_scripts
                else "缺少图表生成脚本 (gen_fig_*.py)"})

# FIG-041: 审查迭代日志
review_log_found = False
for log in ['AUTO_REVIEW.md', 'figure-review-log.json',
            '.paper/state/figure-review.json',
            os.path.join(FIGURES_DIR, 'ai_generated', 'review_log.json')]:
    if os.path.isfile(log):
        review_log_found = True
        break
results.append({"id": "FIG-041", "pass": review_log_found,
                "evidence": "存在审查迭代日志" if review_log_found
                else "缺少审查迭代日志 (AUTO_REVIEW.md 或 figure-review-log.json)"})

print(json.dumps({"results": results}, ensure_ascii=False))
PYEOF

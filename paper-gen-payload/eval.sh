#!/usr/bin/env bash
set -euo pipefail

# Paper Generation Payload Evaluation Script
# Evaluates all script-based criteria from criteria.md
# Configuration is read from session.md frontmatter

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SESSION_FILE="$SCRIPT_DIR/session.md"

# Load configuration from session.md frontmatter
load_config() {
    python3 - <<PYEOF
import re, json

with open('$SESSION_FILE') as f:
    content = f.read()

# Parse frontmatter without external dependencies (PyYAML may be unavailable)
match = re.match(r'^---\n(.*?)\n---', content, re.DOTALL)
frontmatter = {}
if match:
    for raw in match.group(1).splitlines():
        line = raw.strip()
        if not line or line.startswith('#') or ':' not in line:
            continue
        k, v = line.split(':', 1)
        key = k.strip()
        val = v.strip().strip('"').strip("'")
        low = val.lower()
        if low == 'true':
            parsed = True
        elif low == 'false':
            parsed = False
        elif re.fullmatch(r'-?\d+', val):
            parsed = int(val)
        else:
            parsed = val
        frontmatter[key] = parsed

defaults = {
    'paper_type': 'NeurIPS',
    'domain': 'ai-exp',
    'min_references': 30,
    'min_figures': 5,
    'min_tables': 1,
    'page_limit': 9,
    'abstract_max_words': 250,
    'min_experiment_runs': 3,
    'require_ablation': True,
    'min_recent_refs_pct': 30,
}
for k, v in defaults.items():
    if k not in frontmatter:
        frontmatter[k] = v

# Map paper_type to thresholds
thresholds = {
    'NeurIPS': {'min_references': 30, 'min_figures': 5, 'min_tables': 1, 'abstract_max_words': 250, 'page_limit': 9, 'min_experiment_runs': 3},
    'ICML': {'min_references': 30, 'min_figures': 5, 'min_tables': 1, 'abstract_max_words': 250, 'page_limit': 8, 'min_experiment_runs': 3},
    'ICLR': {'min_references': 30, 'min_figures': 5, 'min_tables': 1, 'abstract_max_words': 250, 'page_limit': 8, 'min_experiment_runs': 3},
    'AAAI': {'min_references': 25, 'min_figures': 4, 'min_tables': 1, 'abstract_max_words': 200, 'page_limit': 8, 'min_experiment_runs': 3},
    'Journal': {'min_references': 40, 'min_figures': 5, 'min_tables': 2, 'abstract_max_words': 300, 'page_limit': 30, 'min_experiment_runs': 5},
    'Short': {'min_references': 15, 'min_figures': 3, 'min_tables': 1, 'abstract_max_words': 150, 'page_limit': 4, 'min_experiment_runs': 3},
    'Letter': {'min_references': 10, 'min_figures': 2, 'min_tables': 1, 'abstract_max_words': 150, 'page_limit': 2, 'min_experiment_runs': 3},
}
pt = str(frontmatter.get('paper_type', 'NeurIPS'))
t = thresholds.get(pt, thresholds['NeurIPS'])

print(json.dumps({
    'paper_type': pt,
    'domain': str(frontmatter.get('domain', 'ai-exp')),
    'min_references': t['min_references'],
    'min_figures': t['min_figures'],
    'min_tables': t['min_tables'],
    'page_limit': t['page_limit'],
    'abstract_max_words': t['abstract_max_words'],
    'min_experiment_runs': t['min_experiment_runs'],
    'require_ablation': bool(frontmatter.get('require_ablation', True)),
    'min_recent_refs_pct': int(frontmatter.get('min_recent_refs_pct', 30)),
}))
PYEOF
}

# Parse config once at start
CONFIG=$(load_config)
PAPER_TYPE=$(echo "$CONFIG" | python3 -c "import sys,json; print(json.load(sys.stdin)['paper_type'])")
DOMAIN=$(echo "$CONFIG" | python3 -c "import sys,json; print(json.load(sys.stdin)['domain'])")
MIN_REFS=$(echo "$CONFIG" | python3 -c "import sys,json; print(json.load(sys.stdin)['min_references'])")
MIN_FIGURES=$(echo "$CONFIG" | python3 -c "import sys,json; print(json.load(sys.stdin)['min_figures'])")
MIN_TABLES=$(echo "$CONFIG" | python3 -c "import sys,json; print(json.load(sys.stdin)['min_tables'])")
PAGE_LIMIT=$(echo "$CONFIG" | python3 -c "import sys,json; print(json.load(sys.stdin)['page_limit'])")
ABSTRACT_MAX=$(echo "$CONFIG" | python3 -c "import sys,json; print(json.load(sys.stdin)['abstract_max_words'])")
MIN_RUNS=$(echo "$CONFIG" | python3 -c "import sys,json; print(json.load(sys.stdin)['min_experiment_runs'])")
REQUIRE_ABLATION=$(echo "$CONFIG" | python3 -c "import sys,json; print(json.load(sys.stdin)['require_ablation'])")
MIN_RECENT_PCT=$(echo "$CONFIG" | python3 -c "import sys,json; print(json.load(sys.stdin)['min_recent_refs_pct'])")

OUTPUT_DIR=".paper/output"
REFS_FILE="$OUTPUT_DIR/references.bib"
DRAFT_FILE="$OUTPUT_DIR/draft.tex"
PDF_FILE="$OUTPUT_DIR/paper.pdf"
CODE_DIR="$OUTPUT_DIR/code"
REPRO_FILE="$OUTPUT_DIR/reproducibility.json"
PIPELINE_FILE=".paper/state/pipeline-status.json"

# Helper: Check file exists
check_file() { [[ -f "$1" ]] && echo "true" || echo "false"; }

# Helper: Count BibTeX entries
count_bib_entries() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "0"
        return
    fi
    local n
    n=$(grep -cE '^@[a-zA-Z]+\{' "$file" 2>/dev/null || true)
    echo "${n:-0}"
}

# Helper: Count recent refs (within 5 years)
count_recent_refs() {
    local file="$1"
    local current_year=$(date +%Y)
    local cutoff=$((current_year - 5))
    if [[ ! -f "$file" ]]; then
        echo "0"
        return
    fi
    grep -oE 'year\s*=\s*\{?[0-9]{4}' "$file" 2>/dev/null | \
        grep -oE '[0-9]{4}' | \
        awk -v cutoff="$cutoff" '$1 >= cutoff {count++} END {print count+0}'
}

# Helper: Count PDF pages
count_pdf_pages() {
    local pdf="$1"
    if [[ ! -f "$pdf" ]]; then
        echo "0"
        return
    fi
    pdfinfo "$pdf" 2>/dev/null | grep Pages | awk '{print $2}' || echo "0"
}

# Helper: Count figures in draft.tex
count_figures() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "0"
        return
    fi
    local n
    n=$(grep -cE '\\\\includegraphics' "$file" 2>/dev/null || true)
    echo "${n:-0}"
}

# Helper: Count tables
count_tables() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "0"
        return
    fi
    local n
    n=$(grep -cE '\\\\begin\{(tabular|table)' "$file" 2>/dev/null || true)
    echo "${n:-0}"
}

# Helper: Check abstract word count
check_abstract_words() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "0"
        return
    fi
    python3 -c "
import re
with open('$file') as f:
    content = f.read()
match = re.search(r'\\\\begin\{abstract\}(.*?)\\\\end\{abstract\}', content, re.DOTALL)
if match:
    words = len(match.group(1).split())
    print(words)
else:
    print(0)
"
}

# Helper: Check random seed in code
check_random_seed() {
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

# Helper: Check reproducibility.json fields
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

# Helper: Check mean±std coverage
check_mean_std() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "false:file_not_found"
        return
    fi

    python3 -c "
import re

with open('$file') as f:
    content = f.read()

MEAN_STD = re.compile(
    r'[0-9]+(?:\.[0-9]+)?\s*(?:[\u00b1±]|\\\\pm|\+/-)\s*[0-9]+(?:\.[0-9]+)?',
    re.IGNORECASE
)

table_pattern = r'\\\\begin\{(?:tabular|table\*?)\}.*?\\\\end\{(?:tabular|table\*?)\}'
tabular_blocks = re.findall(table_pattern, content, re.DOTALL)

table_bare = 0
table_covered = 0

for block in tabular_blocks:
    clean = re.sub(r'\\\\[a-zA-Z]+(?:\[[^\]]*\])?\{[^}]*\}', '', block)
    clean = re.sub(r'[\\\\&\|]', ' ', clean)
    cells = clean.split('&')

    for cell in cells:
        cell = cell.strip()
        if not cell:
            continue
        if re.match(r'^[a-zA-Z]', cell):
            continue
        numbers = re.findall(r'-?[0-9]+(?:\.[0-9]+)?', cell)
        if not numbers:
            continue
        if MEAN_STD.search(cell):
            table_covered += 1
        else:
            for num in numbers:
                if len(num) >= 2:
                    table_bare += 1
                    break

RESULT_PATTERNS = [
    r'(?:accuracy|precision|recall|f1[- ]?score|auc|roc[- ]?auc|performance|reached|achieved|obtained|result)[^\n]{0,30}(-?[0-9]+(?:\.[0-9]+)?)',
    r'(-?[0-9]+(?:\.[0-9]+)?)\s*%\s*(?:accuracy|precision|recall|f1)',
    r'(?:score|accuracy)[^\n]{0,20}(-?[0-9]+(?:\.[0-9]+)?)',
]
text_claims = []
for pat in RESULT_PATTERNS:
    found = re.findall(pat, content, re.IGNORECASE)
    text_claims.extend(found)

text_bare = 0
text_covered = 0
for claim_num in text_claims:
    idx = content.find(claim_num)
    if idx < 0:
        continue
    window = content[idx:idx+50]
    if MEAN_STD.search(window):
        text_covered += 1
    else:
        text_bare += 1

total_bare = table_bare + text_bare
total_covered = table_covered + text_covered

has_experiment = re.search(r'\\\\(?:section|subsubsection|paragraph)\{[^}]*(?:experiment|result|evaluation)', content, re.IGNORECASE)

if total_bare == 0 and total_covered == 0:
    if has_experiment:
        print('partial:no_numerical_results_but_has_experiment_section')
    else:
        print('partial:no_numerical_results_found')
elif total_bare > 0:
    print('false:bare_numbers_table=' + str(table_bare) + '_text=' + str(text_bare) + '_covered=' + str(total_covered))
elif total_covered > 0:
    print('true:covered=' + str(total_covered) + '_bare=0')
else:
    print('partial:no_bare_but_no_covered_either')
" 2>/dev/null || echo "false:script_error"
}

# PG-036: draft.tex exists with basic LaTeX structure
pggen001_eval() {
    local pass="true"
    local evidence=""

    if [[ ! -f "$DRAFT_FILE" ]]; then
        pass="false"
        evidence="draft.tex 不存在，需要生成"
    else
        local draft_size
        draft_size=$(stat -c%s "$DRAFT_FILE" 2>/dev/null || stat -f%z "$DRAFT_FILE" 2>/dev/null || echo "0")
        if [[ "$draft_size" -gt 100 ]]; then
            local has_docclass="false"
            local has_begindoc="false"
            local has_enddoc="false"

            grep -qE '\\\\documentclass' "$DRAFT_FILE" && has_docclass="true"
            grep -qE '\\\\begin\{document\}' "$DRAFT_FILE" && has_begindoc="true"
            grep -qE '\\\\end\{document\}' "$DRAFT_FILE" && has_enddoc="true"

            if [[ "$has_docclass" == "true" ]] && [[ "$has_begindoc" == "true" ]] && [[ "$has_enddoc" == "true" ]]; then
                pass="true"
                evidence="draft.tex 存在 (${draft_size} 字节) 且包含完整 LaTeX 结构"
            else
                pass="false"
                evidence="draft.tex 存在但缺少 LaTeX 基本结构 (docclass=$has_docclass, begin=$has_begindoc, end=$has_enddoc)"
            fi
        else
            pass="false"
            evidence="draft.tex 存在但过小 (${draft_size} 字节 < 100)"
        fi
    fi

    echo '{"id":"PG-036","pass":'$pass',"evidence":"'$evidence'"}'
}

# PG-037: Paper initialization complete
pginit_eval() {
    local pass="true"
    local evidence=""

    if [[ -f "$DRAFT_FILE" ]] && [[ -f "$REFS_FILE" ]] && [[ -f "$CODE_DIR/main.py" ]]; then
        local draft_size
        draft_size=$(stat -c%s "$DRAFT_FILE" 2>/dev/null || stat -f%z "$DRAFT_FILE" 2>/dev/null || echo "0")
        local bib_count
        bib_count=$(count_bib_entries "$REFS_FILE")

        if [[ "$draft_size" -gt 100 ]] && [[ "$bib_count" -ge 5 ]]; then
            pass="true"
            evidence="论文初始化完成: draft.tex ${draft_size} 字节, references.bib ${bib_count} 个条目, 代码已生成"
        else
            pass="false"
            evidence="初始化不完整: draft.tex ${draft_size}, references.bib ${bib_count} 个条目"
        fi
    else
        pass="false"
        evidence="缺少初始化文件: draft.tex/references.bib/code/main.py 不完全存在"
    fi

    echo '{"id":"PG-037","pass":'$pass',"evidence":"'$evidence'"}'
}

# PG-038: Pipeline status (optional, non-blocking)
pgpipe001_eval() {
    local pass="true"
    local evidence=""

    if [[ ! -f "$PIPELINE_FILE" ]]; then
        pass="true"
        evidence="pipeline-status.json 不存在（可选，跳过）"
        echo '{"id":"PG-038","pass":'$pass',"evidence":"'$evidence'"}'
        return
    fi

    python3 -c "
import json
try:
    with open('$PIPELINE_FILE') as f:
        data = json.load(f)
    required = ['current_stage', 'completed_stages', 'round', 'last_updated']
    missing = [k for k in required if k not in data]
    if missing:
        print('false:missing:' + ','.join(missing))
    else:
        print('true:ok')
except Exception as e:
    print('false:error:' + str(e))
" | while IFS= read -r line; do
        if [[ "$line" == true:* ]]; then
            evidence="pipeline-status.json 字段完整"
        else
            pass="false"
            evidence="pipeline 状态: ${line#false:}"
        fi
        echo '{"id":"PG-038","pass":'$pass',"evidence":"'$evidence'"}'
    done
}

# PG-001: 目录结构完整
pg001_eval() {
    local pass="true"
    local evidence=""
    local missing=""

    local files=("$DRAFT_FILE" "$REFS_FILE" "$PDF_FILE" "$CODE_DIR/main.py" "$REPRO_FILE")
    local env_file=""
    [[ -f "$CODE_DIR/requirements.txt" ]] && env_file="true" || [[ -f "$CODE_DIR/environment.yml" ]] && env_file="true"

    for f in "${files[@]}"; do
        if [[ ! -f "$f" ]]; then
            missing="$missing $f"
            pass="false"
        fi
    done

    if [[ "$env_file" != "true" ]]; then
        missing="$missing requirements.txt_or_environment.yml"
        pass="false"
    fi

    if [[ "$pass" == "true" ]]; then
        evidence="所有必需文件存在: draft.tex, references.bib, paper.pdf, code/main.py, reproducibility.json, requirements.txt"
    else
        evidence="缺失文件:$missing"
    fi

    echo '{"id":"PG-001","pass":'$pass',"evidence":"'$evidence'"}'
}

# PG-002: LaTeX 编译成功
pg002_eval() {
    local pass="true"
    local evidence=""

    if [[ ! -f "$DRAFT_FILE" ]]; then
        pass="false"
        evidence="draft.tex 不存在"
    else
        cd "$OUTPUT_DIR"
        if timeout 120 latexmk -pdf -interaction=nonstopmode draft.tex >/dev/null 2>&1; then
            pass="true"
            evidence="LaTeX 编译成功，生成 paper.pdf"
        else
            pass="false"
            evidence="LaTeX 编译失败"
        fi
    fi

    echo '{"id":"PG-002","pass":'$pass',"evidence":"'$evidence'"}'
}

# PG-003: 页数符合限制
pg003_eval() {
    local pass="true"
    local evidence=""

    if [[ ! -f "$PDF_FILE" ]]; then
        pass="false"
        evidence="paper.pdf 不存在"
    else
        local pages=$(count_pdf_pages "$PDF_FILE")
        if [[ "$pages" -le "$PAGE_LIMIT" ]]; then
            pass="true"
            evidence="页数: $pages <= 限制: $PAGE_LIMIT"
        else
            pass="false"
            evidence="页数: $pages > 限制: $PAGE_LIMIT"
        fi
    fi

    echo '{"id":"PG-003","pass":'$pass',"evidence":"'$evidence'"}'
}

# PG-004: 引用数量门槛
pg004_eval() {
    local pass="true"
    local evidence=""

    if [[ ! -f "$REFS_FILE" ]]; then
        pass="false"
        evidence="references.bib 不存在"
    else
        local count=$(count_bib_entries "$REFS_FILE")
        if [[ "$count" -ge "$MIN_REFS" ]]; then
            pass="true"
            evidence="引用数: $count >= 门槛: $MIN_REFS"
        else
            pass="false"
            evidence="引用数: $count < 门槛: $MIN_REFS"
        fi
    fi

    echo '{"id":"PG-004","pass":'$pass',"evidence":"'$evidence'"}'
}

# PG-005: 近五年引用占比
pg005_eval() {
    local pass="true"
    local evidence=""

    if [[ ! -f "$REFS_FILE" ]]; then
        pass="false"
        evidence="references.bib 不存在"
    else
        local total=$(count_bib_entries "$REFS_FILE")
        local recent=$(count_recent_refs "$REFS_FILE")
        local pct=0
        if [[ "$total" -gt 0 ]]; then
            pct=$((recent * 100 / total))
        fi

        if [[ "$pct" -ge "$MIN_RECENT_PCT" ]]; then
            pass="true"
            evidence="近五年引用占比: $pct% >= 门槛: $MIN_RECENT_PCT%"
        else
            pass="false"
            evidence="近五年引用占比: $pct% < 门槛: $MIN_RECENT_PCT%"
        fi
    fi

    echo '{"id":"PG-005","pass":'$pass',"evidence":"'$evidence'"}'
}

# PG-007: 图表数量门槛
pg007_eval() {
    local pass="true"
    local evidence=""

    if [[ ! -f "$DRAFT_FILE" ]]; then
        pass="false"
        evidence="draft.tex 不存在"
    else
        local count=$(count_figures "$DRAFT_FILE")
        if [[ "$count" -ge "$MIN_FIGURES" ]]; then
            pass="true"
            evidence="图表数: $count >= 门槛: $MIN_FIGURES"
        else
            pass="false"
            evidence="图表数: $count < 门槛: $MIN_FIGURES"
        fi
    fi

    echo '{"id":"PG-007","pass":'$pass',"evidence":"'$evidence'"}'
}

# PG-008: 表格数量门槛
pg008_eval() {
    local pass="true"
    local evidence=""

    if [[ ! -f "$DRAFT_FILE" ]]; then
        pass="false"
        evidence="draft.tex 不存在"
    else
        local count=$(count_tables "$DRAFT_FILE")
        if [[ "$count" -ge "$MIN_TABLES" ]]; then
            pass="true"
            evidence="表格数: $count >= 门槛: $MIN_TABLES"
        else
            pass="false"
            evidence="表格数: $count < 门槛: $MIN_TABLES"
        fi
    fi

    echo '{"id":"PG-008","pass":'$pass',"evidence":"'$evidence'"}'
}

# PG-010: 向量图表格式
pg010_eval() {
    local pass="true"
    local evidence=""

    if [[ ! -d "$OUTPUT_DIR/figures" ]]; then
        pass="true"
        evidence="figures 目录不存在（可选，跳过）"
    else
        local raster_count=$(find "$OUTPUT_DIR/figures" -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.gif" \) 2>/dev/null | wc -l)
        local vector_count=$(find "$OUTPUT_DIR/figures" -type f \( -name "*.pdf" -o -name "*.eps" \) 2>/dev/null | wc -l)

        if [[ "$raster_count" -eq 0 ]]; then
            pass="true"
            evidence="所有图表为向量格式 (pdf/eps): $vector_count 个"
        else
            pass="false"
            evidence="存在栅格图: $raster_count 个"
        fi
    fi

    echo '{"id":"PG-010","pass":'$pass',"evidence":"'$evidence'"}'
}

# PG-011: 随机种子固定
pg011_eval() {
    local pass="true"
    local evidence=""

    if [[ ! -d "$CODE_DIR" ]]; then
        pass="false"
        evidence="code/ 目录不存在"
    else
        if [[ "$(check_random_seed "$CODE_DIR")" == "true" ]]; then
            pass="true"
            evidence="实验代码包含随机种子设置"
        else
            pass="false"
            evidence="实验代码缺少随机种子设置"
        fi
    fi

    echo '{"id":"PG-011","pass":'$pass',"evidence":"'$evidence'"}'
}

# PG-012: 可重复性报告
pg012_eval() {
    local pass="true"
    local evidence=""

    if [[ ! -f "$REPRO_FILE" ]]; then
        pass="false"
        evidence="reproducibility.json 不存在"
    else
        if [[ "$(check_reproducibility_json "$REPRO_FILE")" == "true" ]]; then
            pass="true"
            evidence="reproducibility.json 包含所有必需字段"
        else
            pass="false"
            evidence="reproducibility.json 缺少必需字段"
        fi
    fi

    echo '{"id":"PG-012","pass":'$pass',"evidence":"'$evidence'"}'
}

# PG-013: Reproducibility Statement
pg013_eval() {
    local pass="true"
    local evidence=""

    if [[ ! -f "$DRAFT_FILE" ]]; then
        pass="false"
        evidence="draft.tex 不存在"
    else
        if grep -qiE '(reproducibility|reproducible)' "$DRAFT_FILE"; then
            pass="true"
            evidence="包含 Reproducibility Statement"
        else
            pass="false"
            evidence="缺少 Reproducibility Statement"
        fi
    fi

    echo '{"id":"PG-013","pass":'$pass',"evidence":"'$evidence'"}'
}

# PG-014: 环境快照
pg014_eval() {
    local pass="true"
    local evidence=""

    if [[ -f "$CODE_DIR/requirements.txt" ]] && [[ -s "$CODE_DIR/requirements.txt" ]]; then
        pass="true"
        evidence="requirements.txt 存在且非空"
    elif [[ -f "$CODE_DIR/environment.yml" ]] && [[ -s "$CODE_DIR/environment.yml" ]]; then
        pass="true"
        evidence="environment.yml 存在且非空"
    else
        pass="false"
        evidence="缺少 requirements.txt 或 environment.yml"
    fi

    echo '{"id":"PG-014","pass":'$pass',"evidence":"'$evidence'"}'
}

# PG-015: 统计报告规范
pg015_eval() {
    local pass="true"
    local evidence=""

    if [[ ! -f "$DRAFT_FILE" ]]; then
        pass="false"
        evidence="draft.tex 不存在"
    else
        local result
        result=$(check_mean_std "$DRAFT_FILE")
        case "$result" in
            true*)
                pass="true"
                evidence="实验结果包含 mean±std 报告"
                ;;
            false*|partial*)
                pass="false"
                evidence="实验结果缺少 mean±std 报告: $result"
                ;;
            *)
                pass="false"
                evidence="检查失败: $result"
                ;;
        esac
    fi

    echo '{"id":"PG-015","pass":'$pass',"evidence":"'$evidence'"}'
}

# PG-018: Ablation Study
pg018_eval() {
    local pass="true"
    local evidence=""

    if [[ "$REQUIRE_ABLATION" != "True" ]]; then
        pass="true"
        evidence="无需 Ablation Study (domain=$DOMAIN)"
    elif [[ ! -f "$DRAFT_FILE" ]]; then
        pass="false"
        evidence="draft.tex 不存在"
    elif grep -qiE 'ablation' "$DRAFT_FILE"; then
        pass="true"
        evidence="包含 Ablation Study 章节"
    else
        pass="false"
        evidence="缺少 Ablation Study 章节"
    fi

    echo '{"id":"PG-018","pass":'$pass',"evidence":"'$evidence'"}'
}

# PG-019: Limitations 段落
pg019_eval() {
    local pass="true"
    local evidence=""

    if [[ ! -f "$DRAFT_FILE" ]]; then
        pass="false"
        evidence="draft.tex 不存在"
    else
        if grep -qiE 'limitation' "$DRAFT_FILE"; then
            pass="true"
            evidence="包含 Limitations 段落"
        else
            pass="false"
            evidence="缺少 Limitations 段落"
        fi
    fi

    echo '{"id":"PG-019","pass":'$pass',"evidence":"'$evidence'"}'
}

# PG-020: 必要章节完整
pg020_eval() {
    local pass="true"
    local evidence=""
    local missing=""

    if [[ ! -f "$DRAFT_FILE" ]]; then
        pass="false"
        evidence="draft.tex 不存在"
    else
        local sections=("abstract" "intro" "method" "experiment" "conclusion" "reference")
        for sec in "${sections[@]}"; do
            if ! grep -qiE "\\\\(section|section\*)\{[^}]*$sec|\\\\begin\{abstract\}" "$DRAFT_FILE"; then
                missing="$missing $sec"
            fi
        done

        if [[ -z "$missing" ]]; then
            pass="true"
            evidence="包含所有必要章节"
        else
            pass="false"
            evidence="缺少章节:$missing"
        fi
    fi

    echo '{"id":"PG-020","pass":'$pass',"evidence":"'$evidence'"}'
}

# PG-021: Abstract 字数限制
pg021_eval() {
    local pass="true"
    local evidence=""

    if [[ ! -f "$DRAFT_FILE" ]]; then
        pass="false"
        evidence="draft.tex 不存在"
    else
        local words=$(check_abstract_words "$DRAFT_FILE")
        if [[ "$words" -le "$ABSTRACT_MAX" ]]; then
            pass="true"
            evidence="Abstract 字数: $words <= 限制: $ABSTRACT_MAX"
        else
            pass="false"
            evidence="Abstract 字数: $words > 限制: $ABSTRACT_MAX"
        fi
    fi

    echo '{"id":"PG-021","pass":'$pass',"evidence":"'$evidence'"}'
}

# PG-024: 独立运行次数
pg024_eval() {
    local pass="true"
    local evidence=""

    if [[ ! -d "$OUTPUT_DIR/logs" ]]; then
        pass="false"
        evidence="logs 目录不存在"
    else
        local runs=$(find "$OUTPUT_DIR/logs" -name "run_*.log" 2>/dev/null | wc -l)
        if [[ "$runs" -ge "$MIN_RUNS" ]]; then
            pass="true"
            evidence="独立运行次数: $runs >= 门槛: $MIN_RUNS"
        else
            pass="false"
            evidence="独立运行次数: $runs < 门槛: $MIN_RUNS"
        fi
    fi

    echo '{"id":"PG-024","pass":'$pass',"evidence":"'$evidence'"}'
}

# PG-025: Grid Independence (numerical domain)
pg025_eval() {
    local pass="true"
    local evidence=""

    if [[ "$DOMAIN" != "numerical" ]]; then
        pass="true"
        evidence="非数值计算领域，无需 Grid Independence"
    elif [[ ! -f "$DRAFT_FILE" ]]; then
        pass="false"
        evidence="draft.tex 不存在"
    elif grep -qiE 'grid.*independ|mesh.*converg|convergen.*grid' "$DRAFT_FILE"; then
        pass="true"
        evidence="包含 Grid Independence 测试"
    else
        pass="false"
        evidence="缺少 Grid Independence 测试"
    fi

    echo '{"id":"PG-025","pass":'$pass',"evidence":"'$evidence'"}'
}

# PG-026: Convergence Order (numerical domain)
pg026_eval() {
    local pass="true"
    local evidence=""

    if [[ "$DOMAIN" != "numerical" ]]; then
        pass="true"
        evidence="非数值计算领域，无需 Convergence Order"
    elif [[ ! -f "$DRAFT_FILE" ]]; then
        pass="false"
        evidence="draft.tex 不存在"
    elif grep -qiE 'convergen.*order|order.*converg' "$DRAFT_FILE"; then
        pass="true"
        evidence="包含 Convergence Order 报告"
    else
        pass="false"
        evidence="缺少 Convergence Order 报告"
    fi

    echo '{"id":"PG-026","pass":'$pass',"evidence":"'$evidence'"}'
}

# PG-029: 神经网络可视化披露
pg029_eval() {
    local pass="true"
    local evidence=""

    if [[ ! -f "$DRAFT_FILE" ]]; then
        pass="false"
        evidence="draft.tex 不存在"
    else
        if grep -qiE 'visuali.*neural|attention.*map|saliency.*map|grad.*cam|tsne.*embedding' "$DRAFT_FILE"; then
            if grep -qiE 'visuali.*method|visualization.*technique|attention.*mechanism.*visual' "$DRAFT_FILE"; then
                pass="true"
                evidence="包含神经网络可视化方法披露"
            else
                pass="false"
                evidence="使用神经网络可视化但未披露方法"
            fi
        else
            pass="true"
            evidence="未使用神经网络可视化"
        fi
    fi

    echo '{"id":"PG-029","pass":'$pass',"evidence":"'$evidence'"}'
}

# PG-030: 引用正文一致性
pg030_eval() {
    local pass="true"
    local evidence=""

    if [[ ! -f "$DRAFT_FILE" ]] || [[ ! -f "$REFS_FILE" ]]; then
        pass="false"
        evidence="缺少必要文件"
    else
        local bib_keys
        bib_keys=$(grep -oE '^@[a-zA-Z]+\{[^,]+' "$REFS_FILE" 2>/dev/null | sed 's/^@[a-zA-Z]*{//' | sort -u) || bib_keys=""

        if [[ -z "$bib_keys" ]]; then
            pass="false"
            evidence="无法提取 BibTeX 条目"
        else
            local unused=0
            local total=0
            while IFS= read -r key; do
                [[ -z "$key" ]] && continue
                total=$((total + 1))
                if ! grep -qE "\\\\cite[pt]?\{[^}]*$key" "$DRAFT_FILE" 2>/dev/null; then
                    unused=$((unused + 1))
                fi
            done <<< "$bib_keys"

            if [[ "$unused" -eq 0 ]] && [[ "$total" -gt 0 ]]; then
                pass="true"
                evidence="所有 $total 个引用在正文中被使用"
            else
                pass="false"
                evidence="$unused/$total 个引用未在正文使用"
            fi
        fi
    fi

    echo '{"id":"PG-030","pass":'$pass',"evidence":"'$evidence'"}'
}

# PG-032: 实验结果可追溯
pg032_eval() {
    local pass="true"
    local evidence=""

    if [[ ! -d "$OUTPUT_DIR/logs" ]]; then
        pass="false"
        evidence="logs 目录不存在"
    else
        local log_count
        log_count=$(find "$OUTPUT_DIR/logs" -name "run_*.log" 2>/dev/null | wc -l | tr -d ' ')
        if [[ "$log_count" -eq 0 ]]; then
            pass="false"
            evidence="无 run_*.log 文件"
        else
            pass="true"
            evidence="$log_count 个 run_*.log 存在"
        fi
    fi

    echo '{"id":"PG-032","pass":'$pass',"evidence":"'$evidence'"}'
}

# PG-033: 代码可独立运行
pg033_eval() {
    local pass="true"
    local evidence=""

    if [[ ! -f "$CODE_DIR/main.py" ]]; then
        pass="false"
        evidence="code/main.py 不存在"
    elif ! python3 -m py_compile "$CODE_DIR/main.py" 2>/dev/null; then
        pass="false"
        evidence="code/main.py 存在语法错误"
    else
        pass="true"
        evidence="code/main.py 语法正确"
    fi

    echo '{"id":"PG-033","pass":'$pass',"evidence":"'$evidence'"}'
}

# PG-039: 代码仓库版本锁定
pgrepo_eval() {
    local pass="true"
    local evidence=""

    if [[ -f "$REPRO_FILE" ]]; then
        local repo_url repo_tag repo_commit repo_doi
        repo_url=$(python3 -c "import json; d=json.load(open('$REPRO_FILE')); print(d.get('repository', '') or '')" 2>/dev/null || echo "")
        repo_tag=$(python3 -c "import json; d=json.load(open('$REPRO_FILE')); print(d.get('repository_tag', '') or '')" 2>/dev/null || echo "")
        repo_commit=$(python3 -c "import json; d=json.load(open('$REPRO_FILE')); print(d.get('repository_commit', '') or '')" 2>/dev/null || echo "")
        repo_doi=$(python3 -c "import json; d=json.load(open('$REPRO_FILE')); print(d.get('repository_doi', '') or '')" 2>/dev/null || echo "")

        if [[ -n "$repo_url" ]] || [[ -n "$repo_tag" ]] || [[ -n "$repo_commit" ]] || [[ -n "$repo_doi" ]]; then
            pass="true"
            evidence="reproducibility.json 包含仓库信息"
        else
            pass="false"
            evidence="reproducibility.json 未包含仓库信息"
        fi
    else
        pass="false"
        evidence="reproducibility.json 不存在"
    fi

    echo '{"id":"PG-039","pass":'$pass',"evidence":"'$evidence'"}'
}

# PG-040: 运行时受限冒烟验证
pg040_eval() {
    local pass="false"
    local evidence=""
    local runtime_file=".paper/state/runtime-proof.json"

    if [[ -f "$runtime_file" ]]; then
        local ok
        ok=$(python3 - <<PYEOF
import json
try:
    with open('$runtime_file') as f:
        d = json.load(f)
    req = ['command','timeout_sec','exit_code','timestamp','stdout_excerpt']
    present = all(k in d and str(d.get(k,'')) != '' for k in req)
    rc_ok = int(d.get('exit_code', 1)) == 0
    print('true' if present and rc_ok else 'false')
except Exception:
    print('false')
PYEOF
)
        if [[ "$ok" == "true" ]]; then
            pass="true"
            evidence="runtime-proof.json 证明受限冒烟运行成功"
        else
            pass="false"
            evidence="runtime-proof.json 缺失字段或 exit_code 非 0"
        fi
    else
        pass="false"
        evidence="缺少 .paper/state/runtime-proof.json"
    fi

    echo '{"id":"PG-040","pass":'$pass',"evidence":"'$evidence'"}'
}

# PG-041: 外部审查证据固定 schema
pg041_eval() {
    local pass="false"
    local evidence=""
    local review_file=".paper/state/external-review-log.json"

    if [[ -f "$review_file" ]]; then
        local ok
        ok=$(python3 - <<PYEOF
import json
req = ['provider','model','timestamp','verdict','raw_feedback','reviewer_role','request_id']
try:
    with open('$review_file') as f:
        d = json.load(f)
    fields_ok = all(k in d and str(d.get(k,'')) != '' for k in req)
    verdict_ok = str(d.get('verdict','')).strip().lower() != 'blocking'
    print('true' if fields_ok and verdict_ok else 'false')
except Exception:
    print('false')
PYEOF
)
        if [[ "$ok" == "true" ]]; then
            pass="true"
            evidence="external-review-log.json schema 完整且 verdict 非 blocking"
        else
            pass="false"
            evidence="external-review-log.json 缺失字段或 verdict=blocking"
        fi
    else
        pass="false"
        evidence="缺少 .paper/state/external-review-log.json"
    fi

    echo '{"id":"PG-041","pass":'$pass',"evidence":"'$evidence'"}'
}

# PG-042: 数值结果可追溯证据链
pg042_eval() {
    local pass="false"
    local evidence=""
    local trace_file=".paper/state/evidence-trace.json"

    if [[ -f "$trace_file" ]]; then
        local ok
        ok=$(python3 - <<PYEOF
import json, os
try:
    with open('$trace_file') as f:
        claims = json.load(f).get('claims', [])
    if not isinstance(claims, list) or len(claims) == 0:
        print('false')
    else:
        good = True
        for c in claims:
            for k in ['claim_id','value','source_log','locator']:
                if k not in c or str(c.get(k,'')) == '':
                    good = False
                    break
            if not good:
                break
            p = str(c.get('source_log',''))
            if not p.startswith('.paper/output/logs/'):
                good = False
                break
            if not os.path.isfile(p) or os.path.getsize(p) == 0:
                good = False
                break
        print('true' if good else 'false')
except Exception:
    print('false')
PYEOF
)
        if [[ "$ok" == "true" ]]; then
            pass="true"
            evidence="evidence-trace 证据链完整且日志可访问"
        else
            pass="false"
            evidence="evidence-trace 缺失映射字段或日志引用无效"
        fi
    else
        pass="false"
        evidence="缺少 .paper/state/evidence-trace.json"
    fi

    echo '{"id":"PG-042","pass":'$pass',"evidence":"'$evidence'"}'
}

# PG-043: 真实外部查重 API 达标
pg043_eval() {
    local pass="false"
    local evidence=""
    local plag_file=".paper/state/plagiarism-report.json"

    if [[ -f "$plag_file" ]]; then
        local ok
        ok=$(python3 - <<PYEOF
import json
try:
    with open('$plag_file') as f:
        d = json.load(f)
    req = ['provider','report_id','checked_at','status','response_hash','similarity_pct']
    present = all(k in d and str(d.get(k,'')) != '' for k in req)
    status_ok = str(d.get('status','')).strip().lower() == 'success'
    sim_ok = float(d.get('similarity_pct', 100.0)) <= 15.0
    print('true' if present and status_ok and sim_ok else 'false')
except Exception:
    print('false')
PYEOF
)
        if [[ "$ok" == "true" ]]; then
            pass="true"
            evidence="外部查重报告存在且 similarity_pct<=15"
        else
            pass="false"
            evidence="外部查重报告缺失字段、调用失败或相似度超阈值"
        fi
    else
        pass="false"
        evidence="缺少 .paper/state/plagiarism-report.json"
    fi

    echo '{"id":"PG-043","pass":'$pass',"evidence":"'$evidence'"}'
}

# PG-044: 数据集版本与许可证合规
pg044_eval() {
    local pass="false"
    local evidence=""
    local inventory_file=".paper/state/dataset-inventory.json"

    if [[ -f "$inventory_file" ]]; then
        local ok
        ok=$(python3 - <<PYEOF
import json
try:
    with open('$inventory_file') as f:
        ds = json.load(f).get('datasets', [])
    if not isinstance(ds, list) or len(ds) == 0:
        print('false')
    else:
        good = True
        for d in ds:
            for k in ['name','source','license','usage_terms']:
                if k not in d or str(d.get(k,'')) == '':
                    good = False
                    break
            if not good:
                break
            has_version = str(d.get('version','')).strip() != ''
            has_ref = str(d.get('doi','')).strip() != '' or str(d.get('url','')).strip() != ''
            if not (has_version or has_ref):
                good = False
                break
            if str(d.get('license_status','')).strip().lower() in ('prohibited','incompatible'):
                good = False
                break
            if bool(d.get('restricted', False)) and str(d.get('compliance_note','')).strip() == '':
                good = False
                break
        print('true' if good else 'false')
except Exception:
    print('false')
PYEOF
)
        if [[ "$ok" == "true" ]]; then
            pass="true"
            evidence="dataset inventory 版本/许可证检查通过"
        else
            pass="false"
            evidence="dataset inventory 缺失字段、版本引用不足或许可证冲突"
        fi
    else
        pass="false"
        evidence="缺少 .paper/state/dataset-inventory.json"
    fi

    echo '{"id":"PG-044","pass":'$pass',"evidence":"'$evidence'"}'
}

# PG-045: payload 协议 lint 通过
pg045_eval() {
    local pass="false"
    local evidence=""
    local lint_file=".paper/state/payload-lint-report.json"

    if [[ -f "$lint_file" ]]; then
        local ok
        ok=$(python3 - <<PYEOF
import json
try:
    with open('$lint_file') as f:
        d = json.load(f)
    status = str(d.get('status','')).strip().lower()
    checks = d.get('checks', {})
    required = ['triplet_complete','depends_valid','script_alignment']
    checks_ok = all(bool(checks.get(k, False)) for k in required)
    print('true' if status == 'pass' and checks_ok else 'false')
except Exception:
    print('false')
PYEOF
)
        if [[ "$ok" == "true" ]]; then
            pass="true"
            evidence="payload lint 报告通过"
        else
            pass="false"
            evidence="payload lint 报告未通过或字段不完整"
        fi
    else
        pass="false"
        evidence="缺少 .paper/state/payload-lint-report.json"
    fi

    echo '{"id":"PG-045","pass":'$pass',"evidence":"'$evidence'"}'
}

main() {
    echo '{"results":['

    local first=true
    local result

    for func in pggen001_eval pginit_eval pgpipe001_eval pg001_eval pg002_eval pg003_eval pg004_eval pg005_eval pg007_eval pg008_eval pg010_eval pg011_eval pg012_eval pg013_eval pg014_eval pg015_eval pg018_eval pg019_eval pg020_eval pg021_eval pg024_eval pg025_eval pg026_eval pg029_eval pg030_eval pg032_eval pg033_eval pgrepo_eval pg040_eval pg041_eval pg042_eval pg043_eval pg044_eval pg045_eval; do
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
#!/usr/bin/env bash
set -euo pipefail

# File Complete Loop Evaluation Script

OUTPUT_DIR=".paper/output"
DRAFT_FILE="$OUTPUT_DIR/draft.tex"
REFS_FILE="$OUTPUT_DIR/references.bib"

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

    echo ""
    echo ']}'
}

main

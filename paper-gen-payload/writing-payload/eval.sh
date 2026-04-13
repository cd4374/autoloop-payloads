#!/usr/bin/env bash
set -euo pipefail

# Writing Loop Evaluation Script
# Only script-evaluated criteria are emitted:
# - WRT-009 (LaTeX format)
# - WRT-010 (Figure reference completeness)

DRAFT_FILE="${DRAFT_FILE:-.paper/output/draft.tex}"
FIGURES_DIR="${FIGURES_DIR:-.paper/output/figures}"

check_latex_format() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "false"
        return
    fi

    local has_docclass="false"
    local has_begin="false"
    local has_end="false"

    grep -qE '\\\\documentclass' "$file" && has_docclass="true"
    grep -qE '\\\\begin\{document\}' "$file" && has_begin="true"
    grep -qE '\\\\end\{document\}' "$file" && has_end="true"

    if [[ "$has_docclass" == "true" && "$has_begin" == "true" && "$has_end" == "true" ]]; then
        echo "true"
    else
        echo "false"
    fi
}

extract_graphics_refs() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        return
    fi

    grep -oE '\\\\includegraphics(\[[^]]*\])?\{[^}]+\}' "$file" 2>/dev/null | \
        sed -E 's/^\\\\includegraphics(\[[^]]*\])?\{//; s/\}$//' | sort -u
}

check_ref_exists() {
    local ref="$1"
    local figures_dir="$2"
    local output_dir
    output_dir=$(dirname "$figures_dir")

    local base
    base=$(basename "$ref")

    # try common locations
    if [[ -f "$ref" ]] || [[ -f "$figures_dir/$base" ]] || [[ -f "$figures_dir/$ref" ]] || [[ -f "$output_dir/$ref" ]]; then
        echo "true"
        return
    fi

    # try extension fallback when LaTeX omits suffix
    for ext in pdf eps png jpg jpeg svg; do
        if [[ -f "$figures_dir/$base.$ext" ]] || [[ -f "$output_dir/$ref.$ext" ]] || [[ -f "$figures_dir/$ref.$ext" ]]; then
            echo "true"
            return
        fi
    done

    echo "false"
}

check_figure_refs() {
    local file="$1"
    local figures_dir="$2"

    if [[ ! -f "$file" ]] || [[ ! -d "$figures_dir" ]]; then
        echo "false"
        return
    fi

    local missing=0
    local refs
    refs=$(extract_graphics_refs "$file")

    # No includegraphics found => fail for completeness check
    if [[ -z "$refs" ]]; then
        echo "false"
        return
    fi

    while IFS= read -r ref; do
        [[ -z "$ref" ]] && continue
        if [[ "$(check_ref_exists "$ref" "$figures_dir")" != "true" ]]; then
            missing=$((missing + 1))
        fi
    done <<< "$refs"

    if [[ "$missing" -eq 0 ]]; then
        echo "true"
    else
        echo "false"
    fi
}

main() {
    local fmt_pass
    fmt_pass=$(check_latex_format "$DRAFT_FILE")
    local fmt_ev
    if [[ "$fmt_pass" == "true" ]]; then
        fmt_ev="LaTeX structure complete"
    else
        fmt_ev="LaTeX structure incomplete"
    fi

    local fig_pass
    fig_pass=$(check_figure_refs "$DRAFT_FILE" "$FIGURES_DIR")
    local fig_ev
    if [[ "$fig_pass" == "true" ]]; then
        fig_ev="Figure references complete"
    else
        fig_ev="Some figure references missing or unresolved"
    fi

    printf '%s\n' '{"results":['
    printf '%s\n' "{\"id\":\"WRT-009\",\"pass\":$fmt_pass,\"evidence\":\"$fmt_ev\"}"
    printf ',%s\n' "{\"id\":\"WRT-010\",\"pass\":$fig_pass,\"evidence\":\"$fig_ev\"}"
    printf '%s\n' ']}'
}

main

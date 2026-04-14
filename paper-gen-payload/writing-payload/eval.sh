#!/usr/bin/env bash
set -euo pipefail

# Writing Loop Evaluation Script
# Only script-evaluated criteria are emitted:
# - WRT-009 (Template match)
# - WRT-010 (Figure reference completeness)
# - WRT-011 (Template selection state consistency)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DRAFT_FILE="${DRAFT_FILE:-.paper/output/draft.tex}"
FIGURES_DIR="${FIGURES_DIR:-.paper/output/figures}"
PAPER_TYPE_FILE="${PAPER_TYPE_FILE:-.paper/state/paper-type.json}"
TEMPLATE_SELECTION_FILE="${TEMPLATE_SELECTION_FILE:-.paper/state/template-selection.json}"
TEMPLATE_REGISTRY_FILE="${TEMPLATE_REGISTRY_FILE:-$SCRIPT_DIR/templates/registry.json}"

check_template_match() {
    local draft_file="$1"
    local selection_file="$2"
    local registry_file="$3"
    [[ ! -f "$draft_file" ]] && { echo "false:draft_missing"; return; }
    [[ ! -f "$selection_file" ]] && { echo "false:template_selection_missing"; return; }
    [[ ! -f "$registry_file" ]] && { echo "false:template_registry_missing"; return; }

    python3 -c "
import json, os, re, sys

draft_file = '$draft_file'
selection_file = '$selection_file'
registry_file = '$registry_file'

try:
    with open(selection_file) as f:
        sel = json.load(f)
    with open(registry_file) as f:
        reg = json.load(f)
    with open(draft_file) as f:
        tex = f.read()
except Exception:
    print('false:read_error')
    sys.exit(0)

tid = str(sel.get('selected_template_id', '')).strip()
if not tid:
    print('false:missing_selected_template_id')
    sys.exit(0)

templates = reg.get('templates', {})
if tid not in templates:
    print('false:template_not_in_registry')
    sys.exit(0)

cfg = templates[tid]
entry_tex = str(cfg.get('entry_tex', '')).strip()
if not entry_tex:
    print('false:missing_entry_tex')
    sys.exit(0)
entry_path = os.path.join(os.path.dirname(registry_file), entry_tex)
if not os.path.isfile(entry_path):
    print('false:entry_tex_not_found')
    sys.exit(0)

expected_docclass = str(cfg.get('documentclass', '')).strip()
required_markers = cfg.get('required_markers', [])

m = re.search(r'\\\\documentclass(?:\\[[^\\]]*\\])?\\{([^}]+)\\}', tex)
actual_docclass = m.group(1).strip() if m else ''
if expected_docclass and actual_docclass != expected_docclass:
    print(f'false:docclass_mismatch:expected={expected_docclass}:actual={actual_docclass}')
    sys.exit(0)

missing = []
for mk in required_markers:
    if str(mk) not in tex:
        missing.append(str(mk))
if missing:
    print('false:missing_markers:' + ','.join(missing[:5]))
    sys.exit(0)

print('true')
" 2>/dev/null || echo "false:script_error"
}

extract_graphics_refs() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        return
    fi

    grep -oE '\\\\includegraphics(\[[^]]*\])?\{[^}]+\}' "$file" 2>/dev/null | \
        sed -E 's/^\\\\includegraphics(\[[^]]*\])?\{//; s/\}$//' | sort -u
}

check_template_selection_state() {
    local selection_file="$1"
    local registry_file="$2"
    [[ ! -f "$selection_file" ]] && { echo "false:template_selection_missing"; return; }
    [[ ! -f "$registry_file" ]] && { echo "false:template_registry_missing"; return; }

    python3 -c "
import json, os, datetime

selection_file = '$selection_file'
registry_file = '$registry_file'

try:
    with open(selection_file) as f:
        sel = json.load(f)
    with open(registry_file) as f:
        reg = json.load(f)
except Exception:
    print('false:read_error')
    raise SystemExit(0)

required = ['target_venue', 'selected_template_id', 'source_of_truth', 'constraints', 'selected_at']
for k in required:
    v = sel.get(k, None)
    if v is None or (isinstance(v, str) and v.strip() == ''):
        print('false:missing_' + k)
        raise SystemExit(0)

if not isinstance(sel.get('constraints'), dict):
    print('false:constraints_not_object')
    raise SystemExit(0)

tid = str(sel.get('selected_template_id', '')).strip()
templates = reg.get('templates', {})
if tid not in templates:
    print('false:template_not_in_registry')
    raise SystemExit(0)
entry_tex = str(templates.get(tid, {}).get('entry_tex', '')).strip()
if not entry_tex:
    print('false:missing_entry_tex')
    raise SystemExit(0)
entry_path = os.path.join(os.path.dirname(registry_file), entry_tex)
if not os.path.isfile(entry_path):
    print('false:entry_tex_not_found')
    raise SystemExit(0)

# selected_at should be parseable ISO-ish timestamp
sa = str(sel.get('selected_at', '')).strip().replace('Z', '+00:00')
try:
    datetime.datetime.fromisoformat(sa)
except Exception:
    print('false:invalid_selected_at')
    raise SystemExit(0)

print('true')
" 2>/dev/null || echo "false:script_error"
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
    local tmpl_result
    tmpl_result=$(check_template_match "$DRAFT_FILE" "$TEMPLATE_SELECTION_FILE" "$TEMPLATE_REGISTRY_FILE")
    local tmpl_pass="false"
    local tmpl_ev
    if [[ "$tmpl_result" == "true" ]]; then
        tmpl_pass="true"
        tmpl_ev="模板匹配通过：entry_tex 存在，documentclass 与 required_markers 一致"
    else
        tmpl_pass="false"
        tmpl_ev="模板匹配失败：$tmpl_result"
    fi

    local fig_pass
    fig_pass=$(check_figure_refs "$DRAFT_FILE" "$FIGURES_DIR")
    local fig_ev
    if [[ "$fig_pass" == "true" ]]; then
        fig_ev="Figure references complete"
    else
        fig_ev="Some figure references missing or unresolved"
    fi

    local state_result
    state_result=$(check_template_selection_state "$TEMPLATE_SELECTION_FILE" "$TEMPLATE_REGISTRY_FILE")
    local state_pass="false"
    local state_ev
    if [[ "$state_result" == "true" ]]; then
        state_pass="true"
        state_ev="template-selection.json 字段完整且 registry 可解析"
    else
        state_pass="false"
        state_ev="模板选择状态无效：$state_result"
    fi

    printf '%s\n' '{"results":['
    printf '%s\n' "{\"id\":\"WRT-009\",\"pass\":$tmpl_pass,\"evidence\":\"$tmpl_ev\"}"
    printf ',%s\n' "{\"id\":\"WRT-010\",\"pass\":$fig_pass,\"evidence\":\"$fig_ev\"}"
    printf ',%s\n' "{\"id\":\"WRT-011\",\"pass\":$state_pass,\"evidence\":\"$state_ev\"}"
    printf '%s\n' ']}'
}

main

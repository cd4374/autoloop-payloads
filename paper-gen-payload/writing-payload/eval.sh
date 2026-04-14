#!/usr/bin/env bash
# Writing Payload Evaluation Script — 精简版（5 criteria）
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

DRAFT_FILE="${DRAFT_FILE:-.paper/output/draft.tex}"
FIGURES_DIR="${FIGURES_DIR:-.paper/output/figures}"
TEMPLATE_SELECTION_FILE="${TEMPLATE_SELECTION_FILE:-.paper/state/template-selection.json}"
TEMPLATE_REGISTRY_FILE="${TEMPLATE_REGISTRY_FILE:-$SCRIPT_DIR/templates/registry.json}"

export DRAFT_FILE FIGURES_DIR TEMPLATE_SELECTION_FILE TEMPLATE_REGISTRY_FILE PROJECT_ROOT

python3 << 'PYEOF'
import json, os, re, datetime

DRAFT_FILE = os.environ.get('DRAFT_FILE', '.paper/output/draft.tex')
FIGURES_DIR = os.environ.get('FIGURES_DIR', '.paper/output/figures')
TEMPLATE_SELECTION_FILE = os.environ.get('TEMPLATE_SELECTION_FILE', '.paper/state/template-selection.json')
TEMPLATE_REGISTRY_FILE = os.environ.get('TEMPLATE_REGISTRY_FILE', '')
PROJECT_ROOT = os.environ.get('PROJECT_ROOT', '.')

results = []

# WRT-002: Template match
tmpl_ok = False
tmpl_ev = ""
if os.path.isfile(DRAFT_FILE) and os.path.isfile(TEMPLATE_SELECTION_FILE) and os.path.isfile(TEMPLATE_REGISTRY_FILE):
    try:
        with open(TEMPLATE_SELECTION_FILE) as f:
            sel = json.load(f)
        with open(TEMPLATE_REGISTRY_FILE) as f:
            reg = json.load(f)
        with open(DRAFT_FILE) as f:
            tex = f.read()

        tid = str(sel.get('selected_template_id', '')).strip()
        if tid and tid in reg.get('templates', {}):
            cfg = reg['templates'][tid]
            entry_tex = str(cfg.get('entry_tex', '')).strip()
            if entry_tex:
                entry_path = os.path.join(os.path.dirname(TEMPLATE_REGISTRY_FILE), entry_tex)
                if not os.path.isfile(entry_path):
                    tmpl_ev = f"entry_tex 不存在: {entry_tex}"
                else:
                    expected_docclass = str(cfg.get('documentclass', '')).strip()
                    m = re.search(r'\\\\documentclass(?:\\[[^\\]]*\\])?\{([^}]+)\}', tex)
                    actual_docclass = m.group(1).strip() if m else ''
                    if expected_docclass and actual_docclass != expected_docclass:
                        tmpl_ev = f"docclass 不匹配: expected={expected_docclass}, actual={actual_docclass}"
                    else:
                        required_markers = cfg.get('required_markers', [])
                        missing = [mk for mk in required_markers if str(mk) not in tex]
                        if missing:
                            tmpl_ev = f"缺少 required_markers: {missing[:5]}"
                        else:
                            tmpl_ok = True
                            tmpl_ev = "模板匹配通过：docclass 正确，required_markers 完整"
            else:
                tmpl_ev = "template registry entry_tex 为空"
        else:
            tmpl_ev = f"selected_template_id='{tid}' 不在 registry 中"
    except Exception as e:
        tmpl_ev = f"读取错误: {str(e)[:80]}"
elif not os.path.isfile(DRAFT_FILE):
    tmpl_ev = "draft.tex 不存在"
elif not os.path.isfile(TEMPLATE_SELECTION_FILE):
    tmpl_ev = "template-selection.json 不存在"
else:
    tmpl_ev = "template registry 不存在"

results.append({"id": "WRT-002", "pass": tmpl_ok, "evidence": tmpl_ev})

# WRT-003: Figure references
fig_ok = False
fig_ev = ""
if os.path.isfile(DRAFT_FILE) and os.path.isdir(FIGURES_DIR):
    with open(DRAFT_FILE) as f:
        tex = f.read()
    refs = re.findall(r'\\\\includegraphics(?:\[[^\]]*\])?\{([^}]+)\}', tex)
    if not refs:
        fig_ev = "未找到 \\includegraphics 引用"
    else:
        missing = 0
        for ref in refs:
            base = os.path.basename(ref)
            found = False
            for path in (ref, os.path.join(FIGURES_DIR, base),
                         os.path.join(FIGURES_DIR, ref)):
                if os.path.isfile(path):
                    found = True
                    break
            if not found:
                for ext in ('.pdf', '.eps', '.png', '.jpg', '.jpeg', '.svg'):
                    if os.path.isfile(os.path.join(FIGURES_DIR, base + ext)):
                        found = True
                        break
            if not found:
                missing += 1
        if missing == 0:
            fig_ok = True
            fig_ev = f"Figure references 完整（{len(refs)} 个）"
        else:
            fig_ev = f"{missing}/{len(refs)} 个 figure 引用缺失"
elif not os.path.isfile(DRAFT_FILE):
    fig_ev = "draft.tex 不存在"
else:
    fig_ev = "figures/ 目录不存在"

results.append({"id": "WRT-003", "pass": fig_ok, "evidence": fig_ev})

# WRT-004: Template selection state
state_ok = False
state_ev = ""
if os.path.isfile(TEMPLATE_SELECTION_FILE) and os.path.isfile(TEMPLATE_REGISTRY_FILE):
    try:
        with open(TEMPLATE_SELECTION_FILE) as f:
            sel = json.load(f)
        with open(TEMPLATE_REGISTRY_FILE) as f:
            reg = json.load(f)
        required = ['target_venue', 'selected_template_id', 'source_of_truth', 'constraints', 'selected_at']
        missing = [k for k in required
                   if not sel.get(k) or (isinstance(sel[k], str) and not sel[k].strip())]
        if missing:
            state_ev = f"缺少字段: {missing}"
        elif not isinstance(sel.get('constraints'), dict):
            state_ev = "constraints 不是 dict"
        else:
            tid = str(sel.get('selected_template_id', '')).strip()
            if tid in reg.get('templates', {}):
                entry_tex = str(reg['templates'][tid].get('entry_tex', '')).strip()
                if entry_tex:
                    entry_path = os.path.join(os.path.dirname(TEMPLATE_REGISTRY_FILE), entry_tex)
                    if os.path.isfile(entry_path):
                        sa = str(sel.get('selected_at', '')).strip().replace('Z', '+00:00')
                        try:
                            datetime.datetime.fromisoformat(sa)
                            state_ok = True
                            state_ev = "template-selection.json 字段完整且 registry 可解析"
                        except Exception:
                            state_ev = "selected_at 格式无效"
                    else:
                        state_ev = f"entry_tex 不存在: {entry_tex}"
                else:
                    state_ev = "registry entry_tex 为空"
            else:
                state_ev = f"selected_template_id='{tid}' 不在 registry 中"
    except Exception as e:
        state_ev = f"读取错误: {str(e)[:80]}"
elif not os.path.isfile(TEMPLATE_SELECTION_FILE):
    state_ev = "template-selection.json 不存在"
else:
    state_ev = "template registry 不存在"

results.append({"id": "WRT-004", "pass": state_ok, "evidence": state_ev})

# WRT-001, WRT-005: LLM criteria (placeholder)
results.append({"id": "WRT-001", "pass": True, "evidence": "论文章节结构由 LLM evaluator 执行"})
results.append({"id": "WRT-005", "pass": True, "evidence": "写作质量由 LLM evaluator 执行"})

print(json.dumps({"results": results}, ensure_ascii=False))
PYEOF

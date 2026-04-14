#!/usr/bin/env bash
# Literature Payload Evaluation Script — 精简版（3 script + 3 LLM）
set -euo pipefail

DRAFT_FILE="${DRAFT_FILE:-.paper/output/draft.tex}"
PAPERS_DIR="${PAPERS_DIR:-.paper/input/papers}"
LIT_CORPUS_INDEX_FILE="${LIT_CORPUS_INDEX_FILE:-.paper/state/lit-corpus-index.json}"
CITATION_CARDS_DIR="${CITATION_CARDS_DIR:-.paper/output/citation-cards}"

export DRAFT_FILE PAPERS_DIR LIT_CORPUS_INDEX_FILE CITATION_CARDS_DIR

python3 << 'PYEOF'
import json, os, re

DRAFT_FILE = os.environ.get('DRAFT_FILE', '.paper/output/draft.tex')
PAPERS_DIR = os.environ.get('PAPERS_DIR', '.paper/input/papers')
LIT_CORPUS_INDEX_FILE = os.environ.get('LIT_CORPUS_INDEX_FILE', '.paper/state/lit-corpus-index.json')
CITATION_CARDS_DIR = os.environ.get('CITATION_CARDS_DIR', '.paper/output/citation-cards')

results = []

# LIT-001: Related Work section
if os.path.isfile(DRAFT_FILE):
    with open(DRAFT_FILE) as f:
        tex = f.read()
    has_rw = bool(re.search(r'(related.?work|background|prior.?work|literature.?review)', tex, re.IGNORECASE))
    results.append({"id": "LIT-001", "pass": has_rw,
        "evidence": "包含 Related Work 章节" if has_rw else "缺少 Related Work 章节"})
else:
    results.append({"id": "LIT-001", "pass": False, "evidence": "draft.tex 不存在"})

# LIT-002: Corpus dir + index
corpus_ok = False
corpus_ev = ""
paper_exts = {'.pdf', '.txt', '.md'}
paper_count = 0
if os.path.isdir(PAPERS_DIR):
    for root, _, files in os.walk(PAPERS_DIR):
        for fn in files:
            if os.path.splitext(fn)[1].lower() in paper_exts:
                paper_count += 1

if paper_count > 0 and os.path.isfile(LIT_CORPUS_INDEX_FILE):
    try:
        with open(LIT_CORPUS_INDEX_FILE) as f:
            idx = json.load(f)
        papers = idx.get('papers', [])
        if isinstance(papers, list) and len(papers) > 0:
            missing_keys = 0
            for p in papers:
                if not isinstance(p, dict):
                    missing_keys += 1
                    continue
                for k in ('paper_id', 'source_type', 'path'):
                    if not str(p.get(k, '')).strip():
                        missing_keys += 1
                        break
            if missing_keys == 0:
                corpus_ok = True
                corpus_ev = f"papers/{paper_count} 篇，lit-corpus-index.json 合法"
            else:
                corpus_ev = f"lit-corpus-index.json 字段不完整，缺失项={missing_keys}"
        else:
            corpus_ev = "lit-corpus-index.json papers 数组为空"
    except Exception:
        corpus_ev = "lit-corpus-index.json 不是有效 JSON"
else:
    if paper_count == 0:
        corpus_ev = f"文献语料目录无文件（需至少 1 个 pdf/txt/md）"
    else:
        corpus_ev = "缺少 lit-corpus-index.json"

results.append({"id": "LIT-002", "pass": corpus_ok, "evidence": corpus_ev})

# LIT-003: Citation cards markdown only
cards_ok = False
cards_ev = ""
if os.path.isdir(CITATION_CARDS_DIR):
    all_files = [fn for fn in os.listdir(CITATION_CARDS_DIR)
                 if os.path.isfile(os.path.join(CITATION_CARDS_DIR, fn))]
    md_files = [fn for fn in all_files if fn.lower().endswith('.md')]
    non_md = [fn for fn in all_files if not fn.lower().endswith('.md')]
    if len(all_files) == 0:
        cards_ev = "citation-cards 目录为空"
    elif len(non_md) > 0:
        cards_ev = f"发现非 Markdown 文件 {len(non_md)} 个: {', '.join(non_md[:3])}"
    elif len(md_files) == 0:
        cards_ev = "citation-cards 目录无 .md 文件"
    else:
        cards_ok = True
        cards_ev = f"citation cards 全部为 Markdown（{len(md_files)} 个）"
else:
    cards_ev = "缺少 .paper/output/citation-cards/"

results.append({"id": "LIT-003", "pass": cards_ok, "evidence": cards_ev})

# LIT-004, LIT-005, LIT-006: LLM criteria (placeholder)
results.append({"id": "LIT-004", "pass": True, "evidence": "关键论文覆盖由 LLM evaluator 执行"})
results.append({"id": "LIT-005", "pass": True, "evidence": "Novelty 对比由 LLM evaluator 执行"})
results.append({"id": "LIT-006", "pass": True, "evidence": "文献综述完整性由 LLM evaluator 执行"})

print(json.dumps({"results": results}, ensure_ascii=False))
PYEOF

#!/usr/bin/env bash
set -euo pipefail

# Literature Loop Evaluation Script
# Configuration inherited from parent payload's session.md

DRAFT_FILE="${DRAFT_FILE:-.paper/output/draft.tex}"
REFS_FILE="${REFS_FILE:-.paper/output/references.bib}"
PAPER_TYPE_FILE="${PAPER_TYPE_FILE:-.paper/state/paper-type.json}"
PAPERS_DIR="${PAPERS_DIR:-.paper/input/papers}"
LIT_CORPUS_INDEX_FILE="${LIT_CORPUS_INDEX_FILE:-.paper/state/lit-corpus-index.json}"
CITATION_CARDS_DIR="${CITATION_CARDS_DIR:-.paper/output/citation-cards}"

# All evaluation done in Python for correct JSON output
python3 << 'PYEOF'
import json, os, re, subprocess
from datetime import datetime

DRAFT_FILE = os.environ.get('DRAFT_FILE', '.paper/output/draft.tex')
REFS_FILE = os.environ.get('REFS_FILE', '.paper/output/references.bib')
PAPER_TYPE_FILE = os.environ.get('PAPER_TYPE_FILE', '.paper/state/paper-type.json')
PAPERS_DIR = os.environ.get('PAPERS_DIR', '.paper/input/papers')
LIT_CORPUS_INDEX_FILE = os.environ.get('LIT_CORPUS_INDEX_FILE', '.paper/state/lit-corpus-index.json')
CITATION_CARDS_DIR = os.environ.get('CITATION_CARDS_DIR', '.paper/output/citation-cards')

results = []

# LIT-001: Related Work section (script)
if os.path.exists(DRAFT_FILE):
    r = subprocess.run(['grep', '-qiE', '(related.*work|background|prior.*work|literature.*review)', DRAFT_FILE],
                      capture_output=True)
    has_rw = (r.returncode == 0)
    results.append({"id": "LIT-001", "pass": has_rw,
                    "evidence": "包含 Related Work 章节" if has_rw else "缺少 Related Work 章节"})
else:
    results.append({"id": "LIT-001", "pass": False, "evidence": "draft.tex 不存在"})

# LIT-004: Recent references percentage (script)
if os.path.exists(REFS_FILE):
    with open(REFS_FILE) as f:
        bib = f.read()
    years = re.findall(r'year\s*=\s*\{?([0-9]{4})', bib)
    current_year = datetime.now().year
    cutoff = current_year - 5
    recent = sum(1 for y in years if int(y) >= cutoff)
    total = len(years)
    pct = round(recent * 100 / total, 1) if total > 0 else 0
    min_pct = 30
    if os.path.exists(PAPER_TYPE_FILE):
        with open(PAPER_TYPE_FILE) as f:
            pt = json.load(f)
        min_pct = pt.get('derived_thresholds', {}).get('min_recent_refs_pct', 30)
    results.append({"id": "LIT-004", "pass": pct >= min_pct,
                    "evidence": f"近五年文献占比: {pct}% >= 门槛" if pct >= min_pct else f"近五年文献占比: {pct}% < 门槛"})
else:
    results.append({"id": "LIT-004", "pass": False, "evidence": "references.bib 不存在"})

# LIT-005: Key venue citations count (script)
# Extract cited keys from tex and check if they correspond to bib entries
# with recognizable venue fields (journal/booktitle containing known venue names).
if os.path.exists(DRAFT_FILE) and os.path.exists(REFS_FILE):
    with open(DRAFT_FILE) as f:
        tex = f.read()
    with open(REFS_FILE) as f:
        bib = f.read()

    # Extract all cite keys used in tex
    cited_keys = set()
    for m in re.findall(r'\\cite[a-z]*\{([^}]+)\}', tex):
        for key in m.split(','):
            cited_keys.add(key.strip())

    # Build a dict: key -> venue field value
    venue_keywords = re.compile(
        r'^(neurips|icml|iclr|nature\s*(?:machine|portfolio)|'
        r'stat\s*\.?\s*ml|arxiv|international\s*conference\s*on\s*(?:machine\s*learning|learning\s*representations)|'
        r'proceedings\s*of\s*(?:icml|neurips|iclr|aaai|ijcai)|'
        r'journal\s*of\s*(?:machine\s*learning|mach\.?|ml)|'
        r'transactions\s*on\s*(?:ml|ai|machine\s*learning)|'
        r'computer\s*vision\s*(?:and\s*)?pattern\s*recognition|'
        r'iccv|cvpr|eccv|acl|emnlp|naacl|tmlr)',
        re.IGNORECASE
    )
    venue_keys = 0
    # Split bib into entries and check each cited key's venue field
    for entry in re.split(r'\n(?=@)', bib):
        entry_key_m = re.search(r'^@\w+\{([^,]+)', entry)
        if not entry_key_m:
            continue
        key = entry_key_m.group(1).strip()
        if key not in cited_keys:
            continue
        # Check journal or booktitle field for venue keywords
        for field_m in re.finditer(r'(?:journal|booktitle|venue)\s*=\s*[\{"]([^}"]+)[\}"]', entry, re.IGNORECASE):
            if venue_keywords.search(field_m.group(1)):
                venue_keys += 1
                break
    results.append({"id": "LIT-005", "pass": venue_keys >= 5,
                    "evidence": f"检测到 {venue_keys} 篇领域旗舰论文被引用 (>=5)" if venue_keys >= 5 else f"领域旗舰引用过少: {venue_keys} 篇 (需>=5)"})
elif not os.path.exists(DRAFT_FILE):
    results.append({"id": "LIT-005", "pass": False, "evidence": "draft.tex 不存在"})
else:
    results.append({"id": "LIT-005", "pass": False, "evidence": "references.bib 不存在"})

# LIT-009: Corpus directory exists with at least one paper file
paper_exts = {'.pdf', '.txt', '.md'}
paper_count = 0
manual_count = 0
downloaded_count = 0
if os.path.isdir(PAPERS_DIR):
    for root, _, files in os.walk(PAPERS_DIR):
        for fn in files:
            ext = os.path.splitext(fn)[1].lower()
            if ext in paper_exts:
                paper_count += 1
                full = os.path.join(root, fn)
                rel = os.path.relpath(full, PAPERS_DIR)
                parts = rel.split(os.sep)
                if parts and parts[0] == 'manual':
                    manual_count += 1
                elif parts and parts[0] == 'downloaded':
                    downloaded_count += 1
if paper_count > 0:
    results.append({"id": "LIT-009", "pass": True,
                    "evidence": f"文献语料目录存在，共 {paper_count} 篇（manual={manual_count}, downloaded={downloaded_count}）"})
else:
    results.append({"id": "LIT-009", "pass": False,
                    "evidence": "`.paper/input/papers/` 不存在或无文献文件（需至少 1 个 pdf/txt/md）"})

# LIT-010: lit-corpus-index schema check
if os.path.isfile(LIT_CORPUS_INDEX_FILE):
    try:
        with open(LIT_CORPUS_INDEX_FILE) as f:
            idx = json.load(f)
        papers = idx.get('papers', [])
        ok = isinstance(papers, list) and len(papers) > 0
        missing = 0
        for p in papers:
            if not isinstance(p, dict):
                ok = False
                missing += 1
                continue
            for k in ('paper_id', 'source_type', 'path'):
                if not str(p.get(k, '')).strip():
                    ok = False
                    missing += 1
                    break
        if ok:
            results.append({"id": "LIT-010", "pass": True,
                            "evidence": f"lit-corpus-index.json 合法，papers={len(papers)}"})
        else:
            results.append({"id": "LIT-010", "pass": False,
                            "evidence": f"lit-corpus-index.json 字段不完整，缺失项={missing}"})
    except Exception:
        results.append({"id": "LIT-010", "pass": False,
                        "evidence": "lit-corpus-index.json 不是有效 JSON"})
else:
    results.append({"id": "LIT-010", "pass": False,
                    "evidence": "缺少 .paper/state/lit-corpus-index.json"})

# LIT-011: Markdown citation cards existence
if os.path.isdir(CITATION_CARDS_DIR):
    md_cards = [fn for fn in os.listdir(CITATION_CARDS_DIR)
                if os.path.isfile(os.path.join(CITATION_CARDS_DIR, fn)) and fn.lower().endswith('.md')]
    if len(md_cards) > 0:
        results.append({"id": "LIT-011", "pass": True,
                        "evidence": f"citation cards 存在，Markdown 文件={len(md_cards)}"})
    else:
        results.append({"id": "LIT-011", "pass": False,
                        "evidence": "citation-cards 目录存在但缺少 .md 卡片"})
else:
    results.append({"id": "LIT-011", "pass": False,
                    "evidence": "缺少 .paper/output/citation-cards/"})

# LIT-012: citation cards markdown-only constraint
if os.path.isdir(CITATION_CARDS_DIR):
    non_md = []
    total = 0
    for fn in os.listdir(CITATION_CARDS_DIR):
        fp = os.path.join(CITATION_CARDS_DIR, fn)
        if not os.path.isfile(fp):
            continue
        total += 1
        if not fn.lower().endswith('.md'):
            non_md.append(fn)
    if total == 0:
        results.append({"id": "LIT-012", "pass": False,
                        "evidence": "citation-cards 目录为空，无法验证 markdown-only"})
    elif len(non_md) == 0:
        results.append({"id": "LIT-012", "pass": True,
                        "evidence": f"citation cards 全部为 Markdown（{total} 个）"})
    else:
        preview = ', '.join(non_md[:5])
        results.append({"id": "LIT-012", "pass": False,
                        "evidence": f"发现非 Markdown 卡片 {len(non_md)} 个: {preview}"})
else:
    results.append({"id": "LIT-012", "pass": False,
                    "evidence": "缺少 .paper/output/citation-cards/"})

print(json.dumps({"results": results}, ensure_ascii=False))
PYEOF

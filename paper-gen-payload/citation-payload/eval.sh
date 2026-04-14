#!/usr/bin/env bash
# Citation Payload Evaluation Script — 精简版（6 criteria）
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REFS_FILE="${REFS_FILE:-.paper/output/references.bib}"
DRAFT_FILE="${DRAFT_FILE:-.paper/output/draft.tex}"
PAPER_TYPE_FILE="${PAPER_TYPE_FILE:-.paper/state/paper-type.json}"
HTTP_TIMEOUT="${HTTP_TIMEOUT:-10}"

# Helper: count BibTeX entries
count_bib_entries() {
    [[ -f "$1" ]] && grep -cE '^@[a-zA-Z]+\{' "$1" 2>/dev/null || echo "0"
}

# Helper: extract DOI from BibTeX entry
extract_dois() {
    python3 -c "
import re
try:
    with open('$1') as f:
        content = f.read()
    dois = re.findall(r'doi\s*=\s*[\"{\']([^\"}\']+)[\"}\']', content, re.DOTALL | re.IGNORECASE)
    for d in dois:
        d = d.strip().rstrip(',;')
        for prefix in ('https://doi.org/','http://doi.org/','doi:','DOI:'):
            if d.startswith(prefix):
                d = d[len(prefix):]
                break
        print(d)
except Exception:
    pass
" 2>/dev/null || true
}

# Helper: extract arXiv ID from BibTeX entry
extract_arxiv_ids() {
    python3 -c "
import re
try:
    with open('$1') as f:
        content = f.read()
    ids = re.findall(r'(?:eprint|arxiv)\s*=\s*[\"{\']([^\"}\']+)[\"}\']', content, re.DOTALL | re.IGNORECASE)
    for i in ids:
        i = i.strip().rstrip(',;')
        for prefix in ('arXiv:','arxiv:'):
            if i.startswith(prefix):
                i = i[len(prefix):]
                break
        print(i)
except Exception:
    pass
" 2>/dev/null || true
}

# Helper: DOI accessibility check
verify_doi_accessibility() {
    local doi="$1"
    [[ -z "$doi" ]] && { echo "skip"; return; }
    doi=$(echo "$doi" | tr -d ' ')
    local status
    status=$(curl -sL -o /dev/null -w "%{http_code}" --max-time "$HTTP_TIMEOUT" "https://doi.org/$doi" 2>/dev/null || echo "000")
    case "$status" in
        200|301|302|303|307|308) echo "pass" ;;
        000) echo "timeout" ;;
        *) echo "fail:$status" ;;
    esac
}

# Helper: arXiv accessibility check (PDF then abstract fallback)
verify_arxiv_accessibility() {
    local arxiv="$1"
    [[ -z "$arxiv" ]] && { echo "skip"; return; }
    arxiv=$(echo "$arxiv" | tr -d ' ')
    local status
    status=$(curl -sL -o /dev/null -w "%{http_code}" --max-time "$HTTP_TIMEOUT" "https://arxiv.org/pdf/${arxiv}.pdf" 2>/dev/null || echo "000")
    case "$status" in
        200) echo "pass" ;;
        404)
            status=$(curl -sL -o /dev/null -w "%{http_code}" --max-time "$HTTP_TIMEOUT" "https://arxiv.org/abs/${arxiv}" 2>/dev/null || echo "000")
            case "$status" in
                200) echo "pass" ;;
                000) echo "timeout" ;;
                *) echo "fail:$status" ;;
            esac
            ;;
        000) echo "timeout" ;;
        *) echo "fail:$status" ;;
    esac
}

# Helper: CrossRef consistency check
verify_crossref_consistency() {
    local doi="$1"
    local bibtex_title="$2"
    local bibtex_year="$3"
    [[ -z "$doi" ]] && { echo "skip"; return; }
    doi=$(echo "$doi" | tr -d ' ')
    local clean_doi="$doi"
    case "$clean_doi" in
        https://doi.org/*) clean_doi="${clean_doi#https://doi.org/}" ;;
        http://doi.org/*)  clean_doi="${clean_doi#http://doi.org/}" ;;
        doi:*|DOI:*)       clean_doi="${clean_doi#doi:*}" ;;
    esac
    local response
    response=$(curl -sL --max-time "$HTTP_TIMEOUT" -H "Accept: application/json" \
                 "https://api.crossref.org/works/$clean_doi" 2>/dev/null || echo "")
    [[ -z "$response" ]] && { echo "fail:no_response"; return; }

    python3 << PYEOF
import json, re, sys
from difflib import SequenceMatcher

try:
    resp = json.loads('''$response''')
except Exception:
    print('fail:invalid_json'); sys.exit(0)

msg = resp.get('message', {})
crossref_titles = msg.get('title', [])
crossref_title = crossref_titles[0] if crossref_titles else ''

crossref_year = ''
for field in ('published-print', 'published-online', 'created'):
    parts = msg.get(field, {}).get('date-parts', [])
    if parts and parts[0]:
        crossref_year = str(parts[0][0])
        break

if not crossref_title:
    print('fail:crossref_no_title'); sys.exit(0)

def norm(t):
    t = t.lower()
    t = re.sub(r'[^\w\s]', '', t)
    return ' '.join(t.split())

bibtex_title = '''$bibtex_title'''.lower().strip()
bibtex_year = '''$bibtex_year'''.strip()
sim = SequenceMatcher(None, norm(bibtex_title), norm(crossref_title)).ratio()

year_match = (bibtex_year == '') or (crossref_year == bibtex_year) or \
    (abs(int(crossref_year or 0) - int(bibtex_year or 0)) <= 1)

if sim >= 0.7 and year_match:
    print(f'pass:{sim:.2f}')
elif sim >= 0.7 and not year_match:
    print(f'fail:year_mismatch:bib={bibtex_year}:cr={crossref_year}')
else:
    print(f'fail:title_mismatch:sim={sim:.2f}')
PYEOF
}

# Helper: Layer 1 BibTeX field check
check_layer1_fields() {
    [[ ! -f "$1" ]] && { echo "0:1"; return; }
    python3 -c "
import re
try:
    with open('$1') as f:
        content = f.read()
    entries = re.findall(r'@\w+\{[^@]+', content, re.DOTALL)
    total = len(entries)
    incomplete = sum(1 for e in entries
                     if not (re.search(r'author\s*=', e, re.IGNORECASE)
                             and re.search(r'title\s*=', e, re.IGNORECASE)
                             and re.search(r'year\s*=', e, re.IGNORECASE)))
    print(f'{total}:{incomplete}')
except Exception:
    print('0:1')
" 2>/dev/null || echo "0:1"
}

# Helper: cite consistency check
check_cite_consistency() {
    [[ ! -f "$1" ]] || [[ ! -f "$2" ]] && { echo "0:0"; return; }
    python3 -c "
import re
try:
    with open('$1') as f:
        bib = f.read()
    with open('$2') as f:
        tex = f.read()
    bib_keys = [k.strip() for k in re.findall(r'^@\w+\{([^,]+)', bib, re.MULTILINE)]
    used = sum(1 for k in bib_keys
               if re.search(r'\\\\cite[pt]?\{[^}]*' + re.escape(k), tex))
    print(f'{used}:{len(bib_keys)}')
except Exception:
    print('0:0')
" 2>/dev/null || echo "0:0"
}

# Helper: BibTeX style consistency check
check_bibtex_style() {
    [[ ! -f "$1" ]] && { echo "false"; return; }
    python3 -c "
import re
try:
    with open('$1') as f:
        content = f.read()
    entries = re.findall(r'@\w+\{[^@]+', content, re.DOTALL)
    brace_count = quote_count = 0
    for entry in entries:
        m = re.search(r'title\s*=\s*[\{\"](.+?)[\}\"]', entry, re.IGNORECASE | re.DOTALL)
        if m:
            val = m.group(0)
            if val.startswith('title = {'):
                brace_count += 1
            elif val.startswith('title = \"'):
                quote_count += 1
    total = brace_count + quote_count
    if total == 0:
        print('true')
    elif brace_count > 0 and quote_count > 0:
        print('false:mixed_styles')
    else:
        print('true')
except Exception:
    print('true')
" 2>/dev/null || echo "true"
}

main() {
    local l1_pass="false" l1_ev=""
    local l2_pass="false" l2_ev=""
    local l3_pass="false" l3_ev=""
    local cnt_pass="false" cnt_ev=""
    local cite_pass="false" cite_ev=""
    local sty_pass="false" sty_ev=""

    # CITE-001: Layer 1 BibTeX field completeness
    if [[ -f "$REFS_FILE" ]]; then
        local result="$(check_layer1_fields "$REFS_FILE")"
        local total="${result%%:*}"
        local incomplete="${result##*:}"
        if [[ "$incomplete" -eq 0 ]]; then
            l1_pass="true"
            l1_ev="所有 $total 个 BibTeX 条目包含必需字段"
        else
            l1_ev="$incomplete/$total 个条目缺少必需字段"
        fi
    else
        l1_ev="references.bib 不存在"
    fi

    # CITE-002: DOI/arXiv accessibility
    if [[ -f "$REFS_FILE" ]]; then
        local doi_verified=0 doi_failed=0 doi_timeout=0
        local arxiv_verified=0 arxiv_failed=0 arxiv_timeout=0
        while IFS= read -r doi; do
            [[ -z "$doi" ]] && continue
            local r; r=$(verify_doi_accessibility "$doi")
            case "$r" in
                pass) ((doi_verified++)) ;;
                timeout) ((doi_timeout++)) ;;
                fail:*) ((doi_failed++)) ;;
            esac
        done < <(extract_dois "$REFS_FILE")
        while IFS= read -r arxiv; do
            [[ -z "$arxiv" ]] && continue
            local r; r=$(verify_arxiv_accessibility "$arxiv")
            case "$r" in
                pass) ((arxiv_verified++)) ;;
                timeout) ((arxiv_timeout++)) ;;
                fail:*) ((arxiv_failed++)) ;;
            esac
        done < <(extract_arxiv_ids "$REFS_FILE")
        local total_ids=$((doi_verified + doi_failed + doi_timeout + arxiv_verified + arxiv_failed + arxiv_timeout))
        if [[ "$total_ids" -gt 0 ]]; then
            local fail_rate=$(( (doi_failed + arxiv_failed) * 100 / total_ids ))
            if [[ "$fail_rate" -le 20 ]]; then
                l2_pass="true"
                l2_ev="Layer 2 通过：$((doi_verified+arxiv_verified)) 可访问，$((doi_failed+arxiv_failed)) 失败"
            else
                l2_ev="Layer 2 失败：$fail_rate% 失败率 > 20% 门槛"
            fi
        else
            l2_pass="true"
            l2_ev="Layer 2 跳过（无 DOI/arXiv ID）"
        fi
    else
        l2_ev="references.bib 不存在"
    fi

    # CITE-003: CrossRef consistency
    if [[ -f "$REFS_FILE" ]]; then
        local l3_verified=0 l3_failed=0 l3_fail_reason=""
        while IFS='|' read -r doi bibtex_title bibtex_year _; do
            [[ -z "$doi" ]] && continue
            local r; r=$(verify_crossref_consistency "$doi" "$bibtex_title" "$bibtex_year")
            case "${r%%:*}" in
                pass) ((l3_verified++)) ;;
                fail)
                    ((l3_failed++))
                    [[ ${#l3_fail_reason} -lt 150 ]] && l3_fail_reason="$l3_fail_reason ${r#*:}"
                    ;;
            esac
        done < <(python3 -c "
import re
try:
    with open('$REFS_FILE') as f:
        content = f.read()
    entries = re.findall(r'@\w+\{([^,]+),([^@]+)', content, re.DOTALL)
    for key, body in entries:
        doi_m = re.search(r'doi\s*=\s*[\"{\']([^\"}\']+)[\"}\']', body, re.DOTALL | re.IGNORECASE)
        title_m = re.search(r'title\s*=\s*[\"{\']([^\"}\']+)[\"}\']', body, re.DOTALL | re.IGNORECASE)
        year_m = re.search(r'year\s*=\s*[\"{\']([^\"}\']+)[\"}\']', body, re.DOTALL | re.IGNORECASE)
        if doi_m:
            doi = doi_m.group(1).strip().rstrip(',;')
            for prefix in ('https://doi.org/','http://doi.org/','doi:','DOI:'):
                if doi.startswith(prefix):
                    doi = doi[len(prefix):]
                    break
            title = title_m.group(1).strip().rstrip(',;') if title_m else ''
            year = year_m.group(1).strip().rstrip(',;') if year_m else ''
            print(f'{doi}|{title}|{year}|{key.strip()}')
except Exception:
    pass
" 2>/dev/null)
        local total_l3=$((l3_verified + l3_failed))
        if [[ "$total_l3" -gt 0 ]]; then
            if [[ "$l3_failed" -eq 0 ]]; then
                l3_pass="true"
                l3_ev="Layer 3 通过：$l3_verified 个 DOI title/year 与 CrossRef 一致"
            else
                l3_ev="Layer 3 失败：$l3_failed/$total_l3 不一致$l3_fail_reason"
            fi
        else
            l3_pass="true"
            l3_ev="Layer 3 跳过（无 DOI）"
        fi
    else
        l3_ev="references.bib 不存在"
    fi

    # CITE-004: Citation count
    if [[ -f "$REFS_FILE" ]]; then
        local count; count=$(count_bib_entries "$REFS_FILE")
        local min; min=$(python3 -c "import json; d=json.load(open('$PAPER_TYPE_FILE')); print(d.get('derived_thresholds',{}).get('min_references', 30))" 2>/dev/null || echo "30")
        if [[ "$count" -ge "$min" ]]; then
            cnt_pass="true"
            cnt_ev="引用数: $count >= $min"
        else
            cnt_ev="引用数: $count < $min"
        fi
    else
        cnt_ev="references.bib 不存在"
    fi

    # CITE-005: Cite consistency
    local cite_result="$(check_cite_consistency "$REFS_FILE" "$DRAFT_FILE")"
    local cite_used="${cite_result%%:*}"
    local cite_total="${cite_result##*:}"
    if [[ "$cite_total" -gt 0 ]]; then
        if [[ "$cite_used" -eq "$cite_total" ]]; then
            cite_pass="true"
            cite_ev="所有 $cite_total 个 BibTeX 条目在正文中被引用"
        else
            cite_ev="$((cite_total - cite_used))/$cite_total 个条目未使用"
        fi
    else
        cite_ev="references.bib 为空或文件不存在"
    fi

    # CITE-006: BibTeX style consistency
    local style_result; style_result=$(check_bibtex_style "$REFS_FILE")
    if [[ "$style_result" == "true" ]]; then
        sty_pass="true"
        sty_ev="BibTeX 格式一致"
    else
        sty_ev="检测到 BibTeX 格式混用"
    fi

    printf '{"results":[\n'
    printf '{"id":"CITE-001","pass":%s,"evidence":"%s"}\n' "$l1_pass" "$l1_ev"
    printf ',{"id":"CITE-002","pass":%s,"evidence":"%s"}\n' "$l2_pass" "$l2_ev"
    printf ',{"id":"CITE-003","pass":%s,"evidence":"%s"}\n' "$l3_pass" "$l3_ev"
    printf ',{"id":"CITE-004","pass":%s,"evidence":"%s"}\n' "$cnt_pass" "$cnt_ev"
    printf ',{"id":"CITE-005","pass":%s,"evidence":"%s"}\n' "$cite_pass" "$cite_ev"
    printf ',{"id":"CITE-006","pass":%s,"evidence":"%s"}\n' "$sty_pass" "$sty_ev"
    printf ']}\n'
}

main

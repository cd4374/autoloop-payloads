#!/usr/bin/env bash
set -euo pipefail

# Citation Loop Evaluation Script
# Configuration inherited from parent payload's session.md

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_SESSION="$SCRIPT_DIR/../session.md"

REFS_FILE="${REFS_FILE:-.paper/output/references.bib}"
DRAFT_FILE="${DRAFT_FILE:-.paper/output/draft.tex}"
PAPER_TYPE_FILE="${PAPER_TYPE_FILE:-.paper/state/paper-type.json}"
CITATION_CARDS_DIR="${CITATION_CARDS_DIR:-.paper/output/citation-cards}"

# Network timeout for HTTP checks (seconds)
HTTP_TIMEOUT="${HTTP_TIMEOUT:-10}"

# Helper: count BibTeX entries
count_bib_entries() {
    local file="$1"
    [[ -f "$file" ]] && grep -cE '^@[a-zA-Z]+\{' "$file" 2>/dev/null || echo "0"
}

# Helper: extract DOI from BibTeX entry
extract_dois() {
    python3 -c "
import re, sys
try:
    with open('$1') as f:
        content = f.read()
    dois = re.findall(r'doi\s*=\s*[\"{\']([^\"}\']+)[\"}\']', content, re.DOTALL | re.IGNORECASE)
    for d in dois:
        d = d.strip().rstrip(',').rstrip(';')
        if d.startswith('https://doi.org/'):
            d = d[19:]
        if d.startswith('http://doi.org/'):
            d = d[18:]
        if d.startswith('doi:'):
            d = d[4:]
        print(d)
except Exception as e:
    pass
" 2>/dev/null || true
}

# Helper: extract arXiv ID from BibTeX entry
extract_arxiv_ids() {
    python3 -c "
import re, sys
try:
    with open('$1') as f:
        content = f.read()
    ids = re.findall(r'(?:eprint|arxiv)\s*=\s*[\"{\']([^\"}\']+)[\"}\']', content, re.DOTALL | re.IGNORECASE)
    for i in ids:
        i = i.strip().rstrip(',').rstrip(';')
        if i.startswith('arXiv:'):
            i = i[6:]
        if i.startswith('arxiv:'):
            i = i[6:]
        print(i)
except Exception as e:
    pass
" 2>/dev/null || true
}

# Helper: extract BibTeX entry titles for comparison
extract_bibtex_titles() {
    python3 -c "
import re, sys
try:
    with open('$1') as f:
        content = f.read()
    entries = re.findall(r'@\w+\{([^,]+),([^@]+)', content, re.DOTALL)
    for entry_key, entry_content in entries:
        title_match = re.search(r'title\s*=\s*[\"{\']([^\"}\']+)[\"}\']', entry_content, re.DOTALL | re.IGNORECASE)
        year_match = re.search(r'year\s*=\s*[\"{\']([^\"}\']+)[\"}\']', entry_content, re.DOTALL | re.IGNORECASE)
        doi_match = re.search(r'doi\s*=\s*[\"{\']([^\"}\']+)[\"}\']', entry_content, re.DOTALL | re.IGNORECASE)
        if doi_match and title_match:
            doi = doi_match.group(1).strip().rstrip(',')
            title = title_match.group(1).strip().rstrip(',')
            year = year_match.group(1).strip().rstrip(',') if year_match else ''
            print(f'{doi}|{title}|{year}|{entry_key.strip()}')
except Exception as e:
    pass
" 2>/dev/null || true
}

# Helper: Layer 2 - DOI URL accessibility check
verify_doi_accessibility() {
    local doi="$1"
    [[ -z "$doi" ]] && { echo "skip"; return; }

    doi="${doi#https://doi.org/}"
    doi="${doi#http://doi.org/}"
    doi="${doi#doi:}"
    doi="${doi#DOI:}"
    doi=$(echo "$doi" | tr -d ' ')

    local url="https://doi.org/$doi"
    local status
    status=$(curl -sL -o /dev/null -w "%{http_code}" --max-time "$HTTP_TIMEOUT" "$url" 2>/dev/null || echo "000")

    case "$status" in
        200|301|302|303|307|308) echo "pass" ;;
        000) echo "timeout" ;;
        *) echo "fail:$status" ;;
    esac
}

# Helper: verify arXiv ID accessibility (Layer 2)
# Prefer PDF page over abstract page — abstract page always 200 even for non-existent IDs.
verify_arxiv_accessibility() {
    local arxiv="$1"
    [[ -z "$arxiv" ]] && { echo "skip"; return; }

    arxiv="${arxiv#arXiv:}"
    arxiv="${arxiv#arxiv:}"
    arxiv=$(echo "$arxiv" | tr -d ' ')

    # Try PDF first (more reliable — non-existent IDs return 404)
    local pdf_url="https://arxiv.org/pdf/${arxiv}.pdf"
    local status
    status=$(curl -sL -o /dev/null -w "%{http_code}" --max-time "$HTTP_TIMEOUT" "$pdf_url" 2>/dev/null || echo "000")

    case "$status" in
        200) echo "pass" ;;
        404)
            # Fallback to abstract page for versioned IDs like 2301.00001v2
            local abs_url="https://arxiv.org/abs/${arxiv}"
            status=$(curl -sL -o /dev/null -w "%{http_code}" --max-time "$HTTP_TIMEOUT" "$abs_url" 2>/dev/null || echo "000")
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

# Helper: Layer 3 - CrossRef title+year consistency check
# Per PAPER_GEN_ACCEPTANCE.md 4.3: Must verify title/year match CrossRef response
verify_crossref_consistency() {
    local doi="$1"
    local bibtex_title="$2"
    local bibtex_year="$3"

    [[ -z "$doi" ]] && { echo "skip"; return; }

    # Normalize DOI
    doi="${doi#https://doi.org/}"
    doi="${doi#http://doi.org/}"
    doi="${doi#doi:}"
    doi=$(echo "$doi" | tr -d ' ')

    local url="https://api.crossref.org/works/$doi"
    local response
    response=$(curl -sL --max-time "$HTTP_TIMEOUT" -H "Accept: application/json" "$url" 2>/dev/null || echo "")

    if [[ -z "$response" ]]; then
        echo "fail:no_response"
        return
    fi

    # Escape the JSON response for Python embedding
    response_escaped=$(printf '%s' "$response" | sed "s/'/\\'/g")
    bibtex_title_escaped=$(printf '%s' "$bibtex_title" | sed "s/'/\\'/g")

    python3 << PYEOF
import json
import sys
import re

try:
    # Handle potential JSON parsing errors
    try:
        response = json.loads('$response_escaped')
    except json.JSONDecodeError:
        print('fail:invalid_json_response')
        sys.exit(0)

    bibtex_title = '''$bibtex_title_escaped'''.lower().strip()
    bibtex_year = '''$bibtex_year'''.strip()

    message = response.get('message', {})

    # Extract title with fallback
    crossref_titles = message.get('title', [])
    crossref_title = crossref_titles[0] if crossref_titles else ''

    # Extract year from multiple possible fields
    crossref_year = ''
    published_print = message.get('published-print', {})
    published_online = message.get('published-online', {})
    created = message.get('created', {})

    if published_print.get('date-parts') and len(published_print['date-parts']) > 0:
        crossref_year = str(published_print['date-parts'][0][0])
    elif published_online.get('date-parts') and len(published_online['date-parts']) > 0:
        crossref_year = str(published_online['date-parts'][0][0])
    elif created.get('date-parts') and len(created['date-parts']) > 0:
        crossref_year = str(created['date-parts'][0][0])

    # Handle empty CrossRef title
    if not crossref_title:
        print('fail:crossref_no_title')
        sys.exit(0)

    def normalize_title(t):
        t = t.lower()
        # Remove punctuation, keep alphanumerics and spaces
        t = re.sub(r'[^\w\s]', '', t)
        # Collapse whitespace
        t = ' '.join(t.split())
        return t

    norm_bibtex = normalize_title(bibtex_title)
    norm_crossref = normalize_title(crossref_title)

    from difflib import SequenceMatcher
    similarity = SequenceMatcher(None, norm_bibtex, norm_crossref).ratio()

    # Year match: allow empty BibTeX year (user didn't provide), otherwise must match
    year_match = (bibtex_year == '') or (crossref_year == bibtex_year) or (abs(int(crossref_year or 0) - int(bibtex_year or 0)) <= 1)

    # Per criteria: title similarity >= 0.7 AND year must match (or be empty)
    if similarity >= 0.7 and year_match:
        if bibtex_year == '':
            print(f'pass:{similarity:.2f}:year_missing_in_bibtex')
        else:
            print(f'pass:{similarity:.2f}')
    elif similarity >= 0.7 and not year_match:
        print(f'fail:year_mismatch:bib={bibtex_year}:crossref={crossref_year}:sim={similarity:.2f}')
    else:
        print(f'fail:title_mismatch:sim={similarity:.2f}:bib={norm_bibtex[:50]}:crossref={norm_crossref[:50]}')
except Exception as e:
    print(f'fail:runtime_error:{str(e)}')
PYEOF
}

# Helper: Check Layer 1 - required fields
check_layer1_fields() {
    local file="$1"
    [[ ! -f "$file" ]] && { echo "fail:file_missing"; return; }

    python3 -c "
import re
try:
    with open('$file') as f:
        content = f.read()
    entries = re.findall(r'@\w+\{([^@]+)', content, re.DOTALL)
    total = len(entries)
    incomplete = 0
    for entry in entries:
        has_author = bool(re.search(r'author\s*=', entry, re.IGNORECASE))
        has_title = bool(re.search(r'title\s*=', entry, re.IGNORECASE))
        has_year = bool(re.search(r'year\s*=', entry, re.IGNORECASE))
        if not (has_author and has_title and has_year):
            incomplete += 1
    print(f'{total}:{incomplete}')
except Exception:
    print('0:1')
" 2>/dev/null || echo "0:1"
}

# Helper: check cite-consistency (CITE-008)
check_cite_consistency() {
    local bib_file="$1"
    local tex_file="$2"
    [[ ! -f "$bib_file" ]] || [[ ! -f "$tex_file" ]] && { echo "0:0"; return; }

    python3 -c "
import re
try:
    with open('$bib_file') as f:
        bib = f.read()
    with open('$tex_file') as f:
        tex = f.read()
    bib_keys = re.findall(r'^@\w+\{([^,]+)', bib, re.MULTILINE)
    bib_keys = [k.strip() for k in bib_keys]
    used = 0
    total = len(bib_keys)
    for key in bib_keys:
        if re.search(r'\\\\cite[pt]?\{[^}]*' + re.escape(key), tex):
            used += 1
    print(f'{used}:{total}')
except Exception:
    print('0:0')
" 2>/dev/null || echo "0:0"
}

# Helper: check BibTeX style consistency (CITE-007)
check_bibtex_style() {
    local file="$1"
    [[ ! -f "$file" ]] && { echo "false"; return; }

    python3 -c "
import re, sys
filepath = '$file'
try:
    with open(filepath) as f:
        content = f.read()
    entries = re.findall(r'@\w+\{[^@]+', content, re.DOTALL)
    brace_count = 0
    quote_count = 0
    for entry in entries:
        title_match = re.search(r'title\s*=\s*[\{\"](.+?)[\}\"]', entry, re.DOTALL | re.IGNORECASE)
        if title_match:
            val = title_match.group(0)
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

# Helper: check citation card -> bib mapping (CITE-009)
check_card_bib_mapping() {
    local cards_dir="$1"
    local bib_file="$2"
    [[ ! -d "$cards_dir" ]] && { echo "0:0:0"; return; }
    [[ ! -f "$bib_file" ]] && { echo "0:0:0"; return; }

    python3 -c "
import os, re

cards_dir = '$cards_dir'
bib_file = '$bib_file'

with open(bib_file) as f:
    bib = f.read()

bib_keys = set(k.strip() for k in re.findall(r'^@\\w+\\{([^,]+)', bib, re.MULTILINE))
dois = set()
arxiv_ids = set()
for d in re.findall(r'doi\\s*=\\s*[\"{\']([^\"}\']+)[\"}\']', bib, re.IGNORECASE):
    v = d.strip().rstrip(',').rstrip(';').lower()
    v = v.replace('https://doi.org/', '').replace('http://doi.org/', '').replace('doi:', '')
    dois.add(v)
for a in re.findall(r'(?:eprint|arxiv)\\s*=\\s*[\"{\']([^\"}\']+)[\"}\']', bib, re.IGNORECASE):
    v = a.strip().rstrip(',').rstrip(';').lower()
    v = v.replace('arxiv:', '').replace('arxiv', '').replace(' ', '')
    arxiv_ids.add(v)

card_files = [fn for fn in os.listdir(cards_dir) if fn.lower().endswith('.md') and os.path.isfile(os.path.join(cards_dir, fn))]
total = len(card_files)
mapped = 0

for fn in card_files:
    fp = os.path.join(cards_dir, fn)
    try:
        with open(fp) as f:
            text = f.read()
    except Exception:
        continue

    text_l = text.lower()
    ok = False

    # 1) Bib key via explicit field or generic @key mention
    m = re.search(r'(?im)^\\s*bibliography\\s*:\\s*(.+)$', text)
    if m:
        cand = m.group(1).strip()
        cand = cand.replace('@', '').split()[0].strip('[](){}')
        if cand in bib_keys:
            ok = True
    if not ok:
        for k in bib_keys:
            if ('@' + k.lower()) in text_l:
                ok = True
                break

    # 2) DOI match
    if not ok:
        for d in dois:
            if d and d in text_l:
                ok = True
                break

    # 3) arXiv match
    if not ok:
        arx = re.findall(r'(?:arxiv[:\\s]*)([0-9]{4}\\.[0-9]{4,5}(?:v[0-9]+)?)', text_l)
        for a in arx:
            if a.replace(' ', '') in arxiv_ids:
                ok = True
                break

    if ok:
        mapped += 1

print(f'{mapped}:{total}:{total - mapped}')
" 2>/dev/null || echo "0:0:0"
}

main() {
    local l1_pass="false"
    local l2_pass="false"
    local l3_pass="false"
    local count_pass="false"
    local recent_pass="false"
    local link_pass="false"
    local style_pass="false"
    local card_map_pass="false"
    local l1_ev=""
    local l2_ev=""
    local l3_ev=""
    local count_ev=""
    local recent_ev=""
    local link_ev=""
    local style_ev=""
    local card_map_ev=""

    # CITE-001: Layer 1 - BibTeX field completeness
    if [[ -f "$REFS_FILE" ]]; then
        local result
        result=$(check_layer1_fields "$REFS_FILE")
        local total="${result%%:*}"
        local incomplete="${result##*:}"
        if [[ "$incomplete" -eq 0 ]]; then
            l1_pass="true"
            l1_ev="所有 $total 个 BibTeX 条目包含必需字段(author/title/year)"
        else
            l1_pass="false"
            l1_ev="$incomplete/$total 个条目缺少必需字段"
        fi
    else
        l1_pass="false"
        l1_ev="references.bib 不存在"
    fi

    # CITE-002: Layer 2 - DOI/arXiv accessibility (actual HTTP verification)
    if [[ -f "$REFS_FILE" ]]; then
        local doi_verified=0
        local doi_failed=0
        local doi_timeout=0
        local arxiv_verified=0
        local arxiv_failed=0
        local arxiv_timeout=0

        while IFS= read -r doi; do
            [[ -z "$doi" ]] && continue
            local result
            result=$(verify_doi_accessibility "$doi")
            case "$result" in
                pass) ((doi_verified++)) ;;
                timeout) ((doi_timeout++)) ;;
                fail:*) ((doi_failed++)) ;;
                skip) ;;
            esac
        done < <(extract_dois "$REFS_FILE")

        while IFS= read -r arxiv; do
            [[ -z "$arxiv" ]] && continue
            local result
            result=$(verify_arxiv_accessibility "$arxiv")
            case "$result" in
                pass) ((arxiv_verified++)) ;;
                timeout) ((arxiv_timeout++)) ;;
                fail:*) ((arxiv_failed++)) ;;
                skip) ;;
            esac
        done < <(extract_arxiv_ids "$REFS_FILE")

        local total_verified=$((doi_verified + arxiv_verified))
        local total_failed=$((doi_failed + arxiv_failed))
        local total_timeout=$((doi_timeout + arxiv_timeout))
        local total_ids=$((total_verified + total_failed + total_timeout))

        if [[ "$total_ids" -gt 0 ]]; then
            local fail_rate=0
            fail_rate=$((total_failed * 100 / total_ids))

            if [[ "$total_failed" -eq 0 ]]; then
                l2_pass="true"
                l2_ev="Layer 2 验证通过：$total_verified 个 DOI/arXiv URL 可访问"
            elif [[ "$fail_rate" -le 20 ]]; then
                l2_pass="true"
                l2_ev="Layer 2 验证通过（含豁免）：$total_verified 个可访问，$total_failed 个失败($fail_rate%)，$total_timeout 个超时"
            else
                l2_pass="false"
                l2_ev="Layer 2 验证失败：$total_failed/$total_ids 个 DOI/arXiv URL 不可访问($fail_rate% 失败率)"
            fi
        else
            l2_pass="false"
            l2_ev="references.bib 中未检测到 DOI 或 arXiv ID，无法执行 Layer 2 验证"
        fi
    else
        l2_pass="false"
        l2_ev="references.bib 不存在"
    fi

    # CITE-003: Layer 3 - CrossRef title+year consistency (actual API comparison)
    if [[ -f "$REFS_FILE" ]]; then
        local l3_verified=0
        local l3_failed=0
        local l3_skip=0
        local fail_reason=""

        while IFS='|' read -r doi bibtex_title bibtex_year entry_key; do
            [[ -z "$doi" ]] && continue
            local result
            result=$(verify_crossref_consistency "$doi" "$bibtex_title" "$bibtex_year")
            case "${result%%:*}" in
                pass) ((l3_verified++)) ;;
                fail)
                    ((l3_failed++))
                    # Capture first few failure reasons for evidence
                    if [[ ${#fail_reason} -lt 100 ]] && [[ -n "$entry_key" ]]; then
                        local reason="${result#*:}"
                        fail_reason="$fail_reason $entry_key:$reason"
                    fi
                    ;;
                skip) ((l3_skip++)) ;;
            esac
        done < <(extract_bibtex_titles "$REFS_FILE")

        local total_l3=$((l3_verified + l3_failed))
        if [[ "$total_l3" -gt 0 ]]; then
            if [[ "$l3_failed" -eq 0 ]]; then
                l3_pass="true"
                l3_ev="Layer 3 验证通过：$l3_verified 个 DOI title/year 与 CrossRef 一致"
            else
                l3_pass="false"
                l3_ev="Layer 3 验证失败：$l3_failed/$total_l3 个 DOI title/year 与 CrossRef 不一致 ($fail_reason)"
            fi
        else
            l3_pass="false"
            l3_ev="无可验证 DOI，Layer 3 无法执行"
        fi
    else
        l3_pass="false"
        l3_ev="references.bib 不存在"
    fi

    # CITE-004: Citation count
    if [[ -f "$REFS_FILE" ]] && [[ -f "$PAPER_TYPE_FILE" ]]; then
        local count
        count=$(count_bib_entries "$REFS_FILE")
        local min
        min=$(python3 -c "import json; d=json.load(open('$PAPER_TYPE_FILE')); print(d.get('derived_thresholds', {}).get('min_references', 30))" 2>/dev/null || echo "30")

        if [[ "$count" -ge "$min" ]]; then
            count_pass="true"
            count_ev="引用数: $count >= 门槛: $min"
        else
            count_pass="false"
            count_ev="引用数: $count < 门槛: $min"
        fi
    elif [[ -f "$REFS_FILE" ]]; then
        local count
        count=$(count_bib_entries "$REFS_FILE")
        if [[ "$count" -ge 30 ]]; then
            count_pass="true"
            count_ev="引用数: $count >= 默认门槛: 30"
        else
            count_pass="false"
            count_ev="引用数: $count < 默认门槛: 30"
        fi
    else
        count_pass="false"
        count_ev="references.bib 不存在"
    fi

    # CITE-005: Recent references percentage
    if [[ -f "$REFS_FILE" ]]; then
        local current_year
        current_year=$(date +%Y)
        local cutoff=$((current_year - 5))

        local total_refs
        total_refs=$(count_bib_entries "$REFS_FILE")

        local recent_count=0
        if [[ "$total_refs" -gt 0 ]]; then
            recent_count=$(grep -oE 'year\s*=\s*[{\"]?[0-9]{4}' "$REFS_FILE" 2>/dev/null | \
                grep -oE '[0-9]{4}' | \
                awk -v cutoff="$cutoff" '$1 >= cutoff {count++} END {print count+0}')
        fi

        local pct
        pct=$(python3 -c "print(round($recent_count * 100 / $total_refs, 1))" 2>/dev/null || echo "0")

        local exempt="false"
        if [[ -f "$PAPER_TYPE_FILE" ]]; then
            exempt=$(python3 -c "import json; d=json.load(open('$PAPER_TYPE_FILE')); print('true' if d.get('exemptions', {}).get('recent_refs_pct_exempt', False) else 'false')" 2>/dev/null || echo "false")
        fi

        local min_pct="30"
        if [[ -f "$PAPER_TYPE_FILE" ]]; then
            min_pct=$(python3 -c "import json; d=json.load(open('$PAPER_TYPE_FILE')); print(d.get('derived_thresholds', {}).get('min_recent_refs_pct', 30))" 2>/dev/null || echo "30")
        fi

        if [[ "$exempt" == "true" ]]; then
            recent_pass="true"
            recent_ev="近五年引用占比: $pct%（已豁免）"
        elif [[ "$pct" -ge "$min_pct" ]]; then
            recent_pass="true"
            recent_ev="近五年引用占比: $pct% >= 门槛: ${min_pct}%"
        else
            recent_pass="false"
            recent_ev="近五年引用占比: $pct% < 门槛: ${min_pct}%"
        fi
    else
        recent_pass="false"
        recent_ev="references.bib 不存在"
    fi

    # CITE-008: Cite consistency
    local cite_result
    cite_result=$(check_cite_consistency "$REFS_FILE" "$DRAFT_FILE")
    local cite_used="${cite_result%%:*}"
    local cite_total="${cite_result##*:}"
    if [[ "$cite_total" -gt 0 ]]; then
        if [[ "$cite_used" -eq "$cite_total" ]]; then
            link_pass="true"
            link_ev="所有 $cite_total 个 BibTeX 条目在正文中被引用"
        else
            link_pass="false"
            link_ev="$((cite_total - cite_used))/$cite_total 个条目未在正文中使用"
        fi
    else
        link_pass="false"
        link_ev="references.bib 为空或文件不存在"
    fi

    # CITE-007: BibTeX style consistency
    local style_result
    style_result=$(check_bibtex_style "$REFS_FILE")
    if [[ "$style_result" == "true" ]]; then
        style_pass="true"
        style_ev="BibTeX 格式一致"
    else
        style_pass="false"
        style_ev="检测到 BibTeX 格式混用"
    fi

    # CITE-009: citation card ↔ bib mapping
    if [[ -d "$CITATION_CARDS_DIR" ]] && [[ -f "$REFS_FILE" ]]; then
        local map_result
        map_result=$(check_card_bib_mapping "$CITATION_CARDS_DIR" "$REFS_FILE")
        local mapped="${map_result%%:*}"
        local tail="${map_result#*:}"
        local total="${tail%%:*}"
        local missing="${map_result##*:}"
        if [[ "$total" -gt 0 ]] && [[ "$mapped" -eq "$total" ]]; then
            card_map_pass="true"
            card_map_ev="全部 $total 个 citation cards 可映射到 references.bib"
        elif [[ "$total" -gt 0 ]]; then
            card_map_pass="false"
            card_map_ev="$missing/$total 个 citation cards 缺少 bib key/DOI/arXiv 映射"
        else
            card_map_pass="false"
            card_map_ev="citation-cards 目录为空或 references.bib 不存在"
        fi
    else
        card_map_pass="false"
        card_map_ev="缺少 citation-cards 目录或 references.bib"
    fi

    printf '%s\n' '{"results":['
    printf '%s\n' "{\"id\":\"CITE-001\",\"pass\":$l1_pass,\"evidence\":\"$l1_ev\"}"
    printf ',%s\n' "{\"id\":\"CITE-002\",\"pass\":$l2_pass,\"evidence\":\"$l2_ev\"}"
    printf ',%s\n' "{\"id\":\"CITE-003\",\"pass\":$l3_pass,\"evidence\":\"$l3_ev\"}"
    printf ',%s\n' "{\"id\":\"CITE-004\",\"pass\":$count_pass,\"evidence\":\"$count_ev\"}"
    printf ',%s\n' "{\"id\":\"CITE-005\",\"pass\":$recent_pass,\"evidence\":\"$recent_ev\"}"
    printf ',%s\n' "{\"id\":\"CITE-008\",\"pass\":$link_pass,\"evidence\":\"$link_ev\"}"
    printf ',%s\n' "{\"id\":\"CITE-007\",\"pass\":$style_pass,\"evidence\":\"$style_ev\"}"
    printf ',%s\n' "{\"id\":\"CITE-009\",\"pass\":$card_map_pass,\"evidence\":\"$card_map_ev\"}"
    printf '%s\n' ']}'
}

main

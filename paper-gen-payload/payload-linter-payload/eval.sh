#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${ROOT_DIR:-$SCRIPT_DIR/..}"
LINT_REPORT_FILE="${LINT_REPORT_FILE:-$ROOT_DIR/.paper/state/payload-lint-report.json}"

# LNT-001: payload 三件套完整
lnt001_eval() {
  local pass="false"
  local evidence=""

  local ok missing_count payload_count
  ok=$(python3 - <<PYEOF
import glob, os
root = '$ROOT_DIR'
payload_dirs = sorted([p for p in glob.glob(os.path.join(root, '*-payload')) if os.path.isdir(p)])
missing = []
for d in payload_dirs:
    for fn in ('criteria.md','eval.sh','session.md'):
        if not os.path.isfile(os.path.join(d, fn)):
            missing.append(f"{os.path.basename(d)}/{fn}")
print('true' if len(payload_dirs) > 0 and len(missing) == 0 else 'false')
PYEOF
)

  missing_count=$(python3 - <<PYEOF
import glob, os
root = '$ROOT_DIR'
payload_dirs = sorted([p for p in glob.glob(os.path.join(root, '*-payload')) if os.path.isdir(p)])
missing = 0
for d in payload_dirs:
    for fn in ('criteria.md','eval.sh','session.md'):
        if not os.path.isfile(os.path.join(d, fn)):
            missing += 1
print(missing)
PYEOF
)

  payload_count=$(python3 - <<PYEOF
import glob, os
root = '$ROOT_DIR'
payload_dirs = [p for p in glob.glob(os.path.join(root, '*-payload')) if os.path.isdir(p)]
print(len(payload_dirs))
PYEOF
)

  if [[ "$ok" == "true" ]]; then
    pass="true"
    evidence="$payload_count 个 payload 均具备 criteria.md/eval.sh/session.md"
  else
    pass="false"
    evidence="检测到 $missing_count 处三件套缺失"
  fi

  if [[ "$payload_count" -eq 0 ]]; then
    pass="false"
    evidence="未发现任何 *-payload 目录"
  fi

  echo "{\"id\":\"LNT-001\",\"pass\":$pass,\"evidence\":\"$evidence\"}"
}

# LNT-002: criteria 依赖图合法
lnt002_eval() {
  local pass="false"
  local evidence=""

  local ok
  ok=$(python3 - <<PYEOF
import glob, os, re

def parse_criteria(path):
    items = []
    current = None
    with open(path, encoding='utf-8') as f:
        for raw in f:
            line = raw.rstrip('\n')
            if re.match(r'^-\s+id:\s*', line):
                if current:
                    items.append(current)
                current = {'id': line.split(':',1)[1].strip(), 'depends_on': []}
            elif current and re.match(r'^\s+depends_on:\s*\[', line):
                arr = line.split(':',1)[1].strip()
                refs = re.findall(r'"([A-Z]+-\d{3})"', arr)
                current['depends_on'] = refs
            elif current and re.match(r'^\s+depends_on:\s*$', line):
                current['depends_on'] = []
            elif current and re.match(r'^\s*-\s*"([A-Z]+-\d{3})"\s*$', line):
                current['depends_on'].append(re.findall(r'"([A-Z]+-\d{3})"', line)[0])
        if current:
            items.append(current)
    return items

root = '$ROOT_DIR'
criteria_files = sorted(glob.glob(os.path.join(root, '*-payload', 'criteria.md')))
all_ok = True
id_pattern = re.compile(r'^[A-Z]+-\d{3}$')

for cf in criteria_files:
    items = parse_criteria(cf)
    ids = [x['id'] for x in items]
    if len(ids) != len(set(ids)):
        all_ok = False
        break
    if any(id_pattern.match(i) is None for i in ids):
        all_ok = False
        break
    id_set = set(ids)
    for x in items:
        for dep in x.get('depends_on', []):
            if dep not in id_set:
                all_ok = False
                break
        if not all_ok:
            break
    if not all_ok:
        break

    graph = {x['id']: x.get('depends_on', []) for x in items}
    state = {k: 0 for k in graph}  # 0=unvisited,1=visiting,2=done

    def dfs(u):
        state[u] = 1
        for v in graph.get(u, []):
            if state[v] == 1:
                return False
            if state[v] == 0 and not dfs(v):
                return False
        state[u] = 2
        return True

    for node in graph:
        if state[node] == 0 and not dfs(node):
            all_ok = False
            break
    if not all_ok:
        break

print('true' if all_ok else 'false')
PYEOF
)

  if [[ "$ok" == "true" ]]; then
    pass="true"
    evidence="所有 payload criteria 的 ID/depends_on/无环校验通过"
  else
    pass="false"
    evidence="存在 ID 非法/重复、depends_on 悬空或依赖环"
  fi

  echo "{\"id\":\"LNT-002\",\"pass\":$pass,\"evidence\":\"$evidence\"}"
}

# LNT-003: script 输出与 criteria 对齐
#
# 对齐规则（来自 PAYLOAD_SPEC §2.3）：
#   - "eval.sh 只评估 evaluator: script 的 criterion"
#   - "evaluator: llm 的 criterion 不应由 eval.sh 返回"
# 因此正确性要求：
#   1. eval.sh 输出的每个 ID 必须是该 payload 中 evaluator=script 的 criterion（不多报）
#   2. 每个 evaluator=script 的 criterion ID 必须在 eval.sh 输出中出现（不漏报）
#   3. 纯 LLM payload（无 script criteria）eval.sh 输出 [] 视为正确
lnt003_eval() {
  local pass="false"
  local evidence=""

  if [[ -f "$LINT_REPORT_FILE" ]]; then
    local result
    result=$(python3 - <<'PYEOF'
import glob, os, re, json, subprocess

root = '$ROOT_DIR'
payload_dirs = sorted([
    p for p in glob.glob(os.path.join(root, '*-payload'))
    if os.path.isdir(p) and not os.path.basename(p).startswith('.')
])
id_pattern = re.compile(r'^[A-Z]+-\d{3}$')

def parse_criteria_script_ids(criteria_path):
    """Return set of evaluator=script criterion IDs."""
    items = []
    current = None
    with open(criteria_path, encoding='utf-8') as f:
        for raw in f:
            line = raw.rstrip('\n')
            if re.match(r'^-\s+id:\s*', line):
                if current:
                    items.append(current)
                current = {'id': line.split(':', 1)[1].strip(), 'evaluator': None}
            elif current and re.match(r'^\s+evaluator:\s*', line):
                current['evaluator'] = line.split(':', 1)[1].strip()
            elif re.match(r'^[^-\s]', line) or re.match(r'^-\s+[^i]', line):
                if current:
                    items.append(current)
                    current = None
        if current:
            items.append(current)
    return {item['id'] for item in items if item.get('evaluator') == 'script'}

def parse_eval_output(eval_sh_path):
    """Run eval.sh and extract criterion IDs from JSON output."""
    try:
        r = subprocess.run(
            ['bash', eval_sh_path],
            capture_output=True, timeout=60,
            cwd=os.path.dirname(eval_sh_path)
        )
        try:
            data = json.loads(r.stdout.strip())
            results = data.get('results', [])
            if isinstance(results, list):
                return {item['id'] for item in results if 'id' in item and id_pattern.match(str(item['id']))}
        except json.JSONDecodeError:
            pass
    except Exception:
        pass
    return set()

all_ok = True
fail_details = []

for pd in payload_dirs:
    pb_name = os.path.basename(pd)
    criteria_path = os.path.join(pd, 'criteria.md')
    eval_sh_path = os.path.join(pd, 'eval.sh')

    if not os.path.exists(criteria_path) or not os.path.exists(eval_sh_path):
        continue

    script_ids = parse_criteria_script_ids(criteria_path)
    output_ids = parse_eval_output(eval_sh_path)

    # Rule 1: output ⊇ script_ids  (no missing script criteria)
    missing = script_ids - output_ids
    # Rule 2: output ⊆ script_ids  (no extra LLM criteria in output)
    extra = output_ids - script_ids

    if missing or extra:
        all_ok = False
        detail = f"{pb_name}: script_ids={sorted(script_ids)}, output_ids={sorted(output_ids)}"
        if missing:
            detail += f", missing={sorted(missing)}"
        if extra:
            detail += f", extra={sorted(extra)}"
        fail_details.append(detail)

if all_ok:
    print('true')
else:
    print('false:' + ' | '.join(fail_details[:3]))
PYEOF
)

    if [[ "$result" == "true" ]]; then
      pass="true"
      evidence="所有 payload eval.sh 输出与 criteria script ID 集合对齐"
    else
      pass="false"
      evidence="对齐失败: ${result#false:}"
    fi
  else
    pass="false"
    evidence="缺少 .paper/state/payload-lint-report.json，跳过对齐检查"
  fi

  echo "{\"id\":\"LNT-003\",\"pass\":$pass,\"evidence\":\"$evidence\"}"
}

main() {
  printf '%s\n' '{"results":['
  printf '%s\n' "$(lnt001_eval)"
  printf ',%s\n' "$(lnt002_eval)"
  printf ',%s\n' "$(lnt003_eval)"
  printf '%s\n' ']}'
}

main

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PAYLOAD_ROOT="${PAYLOAD_ROOT:-$SCRIPT_DIR/..}"
REVIEW_LOG_FILE="${REVIEW_LOG_FILE:-$PAYLOAD_ROOT/.paper/state/external-review-log.json}"

main() {
  local p1="false"
  local e1=""
  local p2="false"
  local e2=""
  local p3="false"
  local e3=""

  if [[ -f "$REVIEW_LOG_FILE" ]] && python3 -c "import json; json.load(open('$REVIEW_LOG_FILE'))" >/dev/null 2>&1; then
    p1="true"
    e1="固定路径外审日志存在且 JSON 合法"
  else
    p1="false"
    e1="缺少固定路径外审日志或 JSON 非法"
  fi

  if [[ "$p1" == "true" ]]; then
    local schema_ok
    schema_ok=$(python3 - <<PYEOF
import json
req = ['provider','model','timestamp','verdict','raw_feedback','reviewer_role','request_id']
try:
    with open('$REVIEW_LOG_FILE') as f:
        d = json.load(f)
    ok = all(k in d and str(d.get(k,'')) != '' for k in req)
    print('true' if ok else 'false')
except Exception:
    print('false')
PYEOF
)
    if [[ "$schema_ok" == "true" ]]; then
      p2="true"
      e2="外审日志 schema 字段完整"
    else
      p2="false"
      e2="外审日志 schema 缺失字段"
    fi
  else
    p2="false"
    e2="跳过 schema 检查：ERE-001 未通过"
  fi

  if [[ "$p2" == "true" ]]; then
    local model verdict
    model=$(python3 - <<PYEOF
import json
with open('$REVIEW_LOG_FILE') as f:
    print(str(json.load(f).get('model','')).strip())
PYEOF
)
    verdict=$(python3 - <<PYEOF
import json
with open('$REVIEW_LOG_FILE') as f:
    print(str(json.load(f).get('verdict','')).strip().lower())
PYEOF
)

    if [[ ! "$model" =~ ^(local|self|internal|same-model)$ ]] && [[ "$verdict" != "blocking" ]]; then
      p3="true"
      e3="外部模型审查有效且 verdict 非 blocking"
    else
      p3="false"
      e3="外部审查不满足要求（model=$model, verdict=$verdict）"
    fi
  else
    p3="false"
    e3="跳过外审有效性检查：ERE-002 未通过"
  fi

  printf '%s\n' '{"results":['
  printf '%s\n' "{\"id\":\"ERE-001\",\"pass\":$p1,\"evidence\":\"$e1\"}"
  printf ',%s\n' "{\"id\":\"ERE-002\",\"pass\":$p2,\"evidence\":\"$e2\"}"
  printf ',%s\n' "{\"id\":\"ERE-003\",\"pass\":$p3,\"evidence\":\"$e3\"}"
  printf '%s\n' ']}'
}

main

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PAYLOAD_ROOT="${PAYLOAD_ROOT:-$SCRIPT_DIR/..}"
TRACE_FILE="${TRACE_FILE:-$PAYLOAD_ROOT/.paper/state/evidence-trace.json}"

main() {
  local p1="false"
  local e1=""
  local p2="false"
  local e2=""
  local p3="false"
  local e3=""

  if [[ -f "$TRACE_FILE" ]]; then
    local basic_ok
    basic_ok=$(python3 - <<PYEOF
import json
try:
    with open('$TRACE_FILE') as f:
        d = json.load(f)
    claims = d.get('claims', [])
    print('true' if isinstance(claims, list) and len(claims) > 0 else 'false')
except Exception:
    print('false')
PYEOF
)
    if [[ "$basic_ok" == "true" ]]; then
      p1="true"
      e1="evidence-trace.json 存在且 claims 非空"
    else
      p1="false"
      e1="evidence-trace.json 缺少 claims 或为空"
    fi
  else
    p1="false"
    e1="缺少 .paper/state/evidence-trace.json"
  fi

  if [[ "$p1" == "true" ]]; then
    local map_ok
    map_ok=$(python3 - <<PYEOF
import json
req = ['claim_id','value','source_log','locator']
try:
    with open('$TRACE_FILE') as f:
        claims = json.load(f).get('claims',[])
    ok = True
    for c in claims:
        if not all(k in c and str(c.get(k,'')) != '' for k in req):
            ok = False
            break
    print('true' if ok else 'false')
except Exception:
    print('false')
PYEOF
)
    if [[ "$map_ok" == "true" ]]; then
      p2="true"
      e2="claims 映射字段完整"
    else
      p2="false"
      e2="claims 存在缺失字段"
    fi
  else
    p2="false"
    e2="跳过映射字段检查：ETR-001 未通过"
  fi

  if [[ "$p2" == "true" ]]; then
    local log_ok
    log_ok=$(python3 - <<PYEOF
import json, os
try:
    with open('$TRACE_FILE') as f:
        claims = json.load(f).get('claims',[])
    ok = True
    for c in claims:
        p = str(c.get('source_log',''))
        if not p.startswith('.paper/output/logs/'):
            ok = False
            break
        if not os.path.isfile(p) or os.path.getsize(p) == 0:
            ok = False
            break
    print('true' if ok else 'false')
except Exception:
    print('false')
PYEOF
)
    if [[ "$log_ok" == "true" ]]; then
      p3="true"
      e3="所有 source_log 路径存在且非空"
    else
      p3="false"
      e3="存在无效 source_log 路径或空日志"
    fi
  else
    p3="false"
    e3="跳过日志可访问检查：ETR-002 未通过"
  fi

  printf '%s\n' '{"results":['
  printf '%s\n' "{\"id\":\"ETR-001\",\"pass\":$p1,\"evidence\":\"$e1\"}"
  printf ',%s\n' "{\"id\":\"ETR-002\",\"pass\":$p2,\"evidence\":\"$e2\"}"
  printf ',%s\n' "{\"id\":\"ETR-003\",\"pass\":$p3,\"evidence\":\"$e3\"}"
  printf '%s\n' ']}'
}

main

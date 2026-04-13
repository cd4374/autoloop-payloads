#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PAYLOAD_ROOT="${PAYLOAD_ROOT:-$SCRIPT_DIR/..}"
RUNTIME_PROOF_FILE="${RUNTIME_PROOF_FILE:-$PAYLOAD_ROOT/.paper/state/runtime-proof.json}"
DEFAULT_CMD="python3 .paper/output/code/main.py"
DEFAULT_TIMEOUT="${RUNTIME_PROOF_TIMEOUT:-30}"

extract_field() {
  local file="$1"
  local key="$2"
  python3 - <<PYEOF 2>/dev/null || true
import json
try:
    with open('$file') as f:
        data = json.load(f)
    v = data.get('$key', '')
    if isinstance(v, (dict, list)):
        import json as _j
        print(_j.dumps(v, ensure_ascii=False))
    else:
        print(str(v))
except Exception:
    pass
PYEOF
}

main() {
  local p1="false"
  local e1=""
  local p2="false"
  local e2=""
  local p3="false"
  local e3=""

  local command="$DEFAULT_CMD"
  local timeout_sec="$DEFAULT_TIMEOUT"

  if [[ -f "$RUNTIME_PROOF_FILE" ]]; then
    local c t
    c=$(extract_field "$RUNTIME_PROOF_FILE" "command")
    t=$(extract_field "$RUNTIME_PROOF_FILE" "timeout_sec")
    [[ -n "$c" ]] && command="$c"
    [[ "$t" =~ ^[0-9]+$ ]] && timeout_sec="$t"
  fi

  if [[ -n "$command" ]]; then
    p1="true"
    e1="已解析冒烟命令: $command"
  else
    p1="false"
    e1="无法解析冒烟命令"
  fi

  if [[ -f "$RUNTIME_PROOF_FILE" ]]; then
    local smoke_ok
    smoke_ok=$(python3 - <<PYEOF
import json
try:
    with open('$RUNTIME_PROOF_FILE') as f:
        d = json.load(f)
    rc = int(d.get('exit_code', 1))
    stderr_excerpt = str(d.get('stderr_excerpt','')).lower()
    stdout_excerpt = str(d.get('stdout_excerpt','')).lower()
    bad = ('traceback' in stderr_excerpt) or ('fatal error' in stderr_excerpt) or ('exception:' in stderr_excerpt) or ('traceback' in stdout_excerpt)
    print('true' if rc == 0 and not bad else 'false')
except Exception:
    print('false')
PYEOF
)
    if [[ "$smoke_ok" == "true" ]]; then
      p2="true"
      e2="受限冒烟运行证据通过（timeout=${timeout_sec}s, exit_code=0）"
    else
      p2="false"
      e2="runtime-proof.json 未证明受限冒烟运行成功"
    fi
  else
    p2="false"
    e2="缺少 runtime-proof.json，无法验证受限冒烟运行"
  fi

  if [[ -f "$RUNTIME_PROOF_FILE" ]]; then
    local ok
    ok=$(python3 - <<PYEOF
import json
try:
    with open('$RUNTIME_PROOF_FILE') as f:
        d = json.load(f)
    req = ['command','timeout_sec','exit_code','timestamp','stdout_excerpt']
    print('true' if all(k in d and str(d.get(k,'')) != '' for k in req) else 'false')
except Exception:
    print('false')
PYEOF
)
    if [[ "$ok" == "true" ]]; then
      p3="true"
      e3="runtime-proof.json 证据字段完整"
    else
      p3="false"
      e3="runtime-proof.json 缺少必需字段"
    fi
  else
    p3="false"
    e3="缺少 .paper/state/runtime-proof.json"
  fi

  printf '%s\n' '{"results":['
  printf '%s\n' "{\"id\":\"RTP-001\",\"pass\":$p1,\"evidence\":\"$e1\"}"
  printf ',%s\n' "{\"id\":\"RTP-002\",\"pass\":$p2,\"evidence\":\"$e2\"}"
  printf ',%s\n' "{\"id\":\"RTP-003\",\"pass\":$p3,\"evidence\":\"$e3\"}"
  printf '%s\n' ']}'
}

main

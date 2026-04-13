#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PAYLOAD_ROOT="${PAYLOAD_ROOT:-$SCRIPT_DIR/..}"
PLAG_REPORT_FILE="${PLAG_REPORT_FILE:-$PAYLOAD_ROOT/.paper/state/plagiarism-report.json}"

# PLG-001: 查重 API 配置存在
plg001_eval() {
  local pass="false"
  local evidence=""

  local provider endpoint api_key
  provider="${PLAGIARISM_API_PROVIDER:-}"
  endpoint="${PLAGIARISM_API_ENDPOINT:-}"
  api_key="${PLAGIARISM_API_KEY:-}"

  local report_provider report_endpoint
  report_provider=""
  report_endpoint=""

  if [[ -f "$PLAG_REPORT_FILE" ]]; then
    report_provider=$(python3 - <<PYEOF
import json
try:
    with open('$PLAG_REPORT_FILE') as f:
        d = json.load(f)
    print(str(d.get('provider','')).strip())
except Exception:
    print('')
PYEOF
)
    report_endpoint=$(python3 - <<PYEOF
import json
try:
    with open('$PLAG_REPORT_FILE') as f:
        d = json.load(f)
    print(str(d.get('endpoint','')).strip())
except Exception:
    print('')
PYEOF
)
  fi

  if [[ -n "$provider" && -n "$endpoint" && -n "$api_key" ]]; then
    pass="true"
    evidence="检测到环境变量 API 配置（provider/endpoint/key）"
  elif [[ -n "$report_provider" && -n "$report_endpoint" && -n "$api_key" ]]; then
    pass="true"
    evidence="检测到报告元数据 provider/endpoint 且环境变量存在 API key"
  else
    pass="false"
    evidence="缺少真实查重 API 配置（需要 provider/endpoint/key）"
  fi

  echo "{\"id\":\"PLG-001\",\"pass\":$pass,\"evidence\":\"$evidence\"}"
}

# PLG-002: 外部查重调用证据存在
plg002_eval() {
  local pass="false"
  local evidence=""

  if [[ -f "$PLAG_REPORT_FILE" ]]; then
    local ok
    ok=$(python3 - <<PYEOF
import json
try:
    with open('$PLAG_REPORT_FILE') as f:
        d = json.load(f)
    required = ['report_id','checked_at','provider','status','response_hash']
    present = all(k in d and str(d.get(k,'')).strip() != '' for k in required)
    status_ok = str(d.get('status','')).strip().lower() in ('success','completed')
    print('true' if present and status_ok else 'false')
except Exception:
    print('false')
PYEOF
)
    if [[ "$ok" == "true" ]]; then
      pass="true"
      evidence="查重报告包含 report_id/checked_at/provider/status/response_hash"
    else
      pass="false"
      evidence="plagiarism-report.json 缺失调用证据字段或 status 非成功"
    fi
  else
    pass="false"
    evidence="缺少 .paper/state/plagiarism-report.json"
  fi

  echo "{\"id\":\"PLG-002\",\"pass\":$pass,\"evidence\":\"$evidence\"}"
}

# PLG-003: 相似度阈值达标
plg003_eval() {
  local pass="false"
  local evidence=""

  if [[ -f "$PLAG_REPORT_FILE" ]]; then
    local ok sim
    ok=$(python3 - <<PYEOF
import json
try:
    with open('$PLAG_REPORT_FILE') as f:
        d = json.load(f)
    status_ok = str(d.get('status','')).strip().lower() in ('success','completed')
    sim = float(d.get('similarity_pct', 100.0))
    print('true' if status_ok and sim <= 15.0 else 'false')
except Exception:
    print('false')
PYEOF
)
    sim=$(python3 - <<PYEOF
import json
try:
    with open('$PLAG_REPORT_FILE') as f:
        d = json.load(f)
    print(str(d.get('similarity_pct','unknown')))
except Exception:
    print('unknown')
PYEOF
)
    if [[ "$ok" == "true" ]]; then
      pass="true"
      evidence="相似度达标（similarity_pct=$sim，阈值<=15）"
    else
      pass="false"
      evidence="相似度未达标或调用未成功（similarity_pct=$sim）"
    fi
  else
    pass="false"
    evidence="缺少 .paper/state/plagiarism-report.json"
  fi

  echo "{\"id\":\"PLG-003\",\"pass\":$pass,\"evidence\":\"$evidence\"}"
}

main() {
  printf '%s\n' '{"results":['
  printf '%s\n' "$(plg001_eval)"
  printf ',%s\n' "$(plg002_eval)"
  printf ',%s\n' "$(plg003_eval)"
  printf '%s\n' ']}'
}

main

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PAYLOAD_ROOT="${PAYLOAD_ROOT:-$SCRIPT_DIR/..}"
INVENTORY_FILE="${INVENTORY_FILE:-$PAYLOAD_ROOT/.paper/state/dataset-inventory.json}"

# DLC-001: 数据集清单结构完整
dlc001_eval() {
  local pass="false"
  local evidence=""

  if [[ -f "$INVENTORY_FILE" ]]; then
    local ok total
    ok=$(python3 - <<PYEOF
import json
try:
    with open('$INVENTORY_FILE') as f:
        d = json.load(f)
    datasets = d.get('datasets', [])
    if not isinstance(datasets, list) or len(datasets) == 0:
        print('false')
    else:
        required = ['name','source','license','usage_terms']
        good = True
        for item in datasets:
            if not isinstance(item, dict):
                good = False
                break
            if not all(k in item and str(item.get(k,'')).strip() != '' for k in required):
                good = False
                break
        print('true' if good else 'false')
except Exception:
    print('false')
PYEOF
)
    total=$(python3 - <<PYEOF
import json
try:
    with open('$INVENTORY_FILE') as f:
        d = json.load(f)
    datasets = d.get('datasets', [])
    print(len(datasets) if isinstance(datasets, list) else 0)
except Exception:
    print(0)
PYEOF
)
    if [[ "$ok" == "true" ]]; then
      pass="true"
      evidence="dataset-inventory.json 结构完整（datasets=$total）"
    else
      pass="false"
      evidence="dataset-inventory.json 缺失 datasets 或必需字段"
    fi
  else
    pass="false"
    evidence="缺少 .paper/state/dataset-inventory.json"
  fi

  echo "{\"id\":\"DLC-001\",\"pass\":$pass,\"evidence\":\"$evidence\"}"
}

# DLC-002: 版本或引用信息完整
dlc002_eval() {
  local pass="false"
  local evidence=""

  if [[ -f "$INVENTORY_FILE" ]]; then
    local ok
    ok=$(python3 - <<PYEOF
import json
try:
    with open('$INVENTORY_FILE') as f:
        d = json.load(f)
    datasets = d.get('datasets', [])
    if not isinstance(datasets, list) or len(datasets) == 0:
        print('false')
    else:
        good = True
        for item in datasets:
            version = str(item.get('version','')).strip()
            doi = str(item.get('doi','')).strip()
            url = str(item.get('url','')).strip()
            if not (version or doi or url):
                good = False
                break
        print('true' if good else 'false')
except Exception:
    print('false')
PYEOF
)
    if [[ "$ok" == "true" ]]; then
      pass="true"
      evidence="每个数据集都包含 version 或 DOI/URL"
    else
      pass="false"
      evidence="存在数据集缺少 version 且缺少 DOI/URL"
    fi
  else
    pass="false"
    evidence="缺少 .paper/state/dataset-inventory.json"
  fi

  echo "{\"id\":\"DLC-002\",\"pass\":$pass,\"evidence\":\"$evidence\"}"
}

# DLC-003: 许可证约束无冲突
dlc003_eval() {
  local pass="false"
  local evidence=""

  if [[ -f "$INVENTORY_FILE" ]]; then
    local ok
    ok=$(python3 - <<PYEOF
import json
try:
    with open('$INVENTORY_FILE') as f:
        d = json.load(f)
    datasets = d.get('datasets', [])
    if not isinstance(datasets, list) or len(datasets) == 0:
        print('false')
    else:
        bad_status = {'prohibited','incompatible'}
        good = True
        for item in datasets:
            status = str(item.get('license_status','')).strip().lower()
            restricted = bool(item.get('restricted', False))
            note = str(item.get('compliance_note','')).strip()
            if status in bad_status:
                good = False
                break
            if restricted and note == '':
                good = False
                break
        print('true' if good else 'false')
except Exception:
    print('false')
PYEOF
)
    if [[ "$ok" == "true" ]]; then
      pass="true"
      evidence="未检测到 prohibited/incompatible，restricted 条目均有合规说明"
    else
      pass="false"
      evidence="存在许可证冲突，或 restricted 条目缺少 compliance_note"
    fi
  else
    pass="false"
    evidence="缺少 .paper/state/dataset-inventory.json"
  fi

  echo "{\"id\":\"DLC-003\",\"pass\":$pass,\"evidence\":\"$evidence\"}"
}

main() {
  printf '%s\n' '{"results":['
  printf '%s\n' "$(dlc001_eval)"
  printf ',%s\n' "$(dlc002_eval)"
  printf ',%s\n' "$(dlc003_eval)"
  printf '%s\n' ']}'
}

main

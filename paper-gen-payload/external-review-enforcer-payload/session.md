---
payload: "external-review-enforcer-loop"
version: "1.0"
max_iter: 2
---

目标：强制外部审查证据采用固定 JSON 路径与 schema，确保跨模型审查可验证。

## 固定证据路径

- `.paper/state/external-review-log.json`

## 检查项目

1. 固定路径文件存在且为合法 JSON
2. 必需字段完整：provider/model/timestamp/verdict/raw_feedback/reviewer_role/request_id
3. verdict 不为 blocking，且 model 不是本地自审占位值

## 状态输出

- `.paper/state/external-review-log.json`

## Actions

### Step 1: 准备
- action: bash
  cmd: "echo 'external-review-enforcer-loop 准备就绪，等待基座评估 criteria...'"

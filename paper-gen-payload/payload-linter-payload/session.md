---
payload: "payload-linter-loop"
version: "1.0"
max_iter: 2
---

目标：对 paper-gen payload 体系做协议级 lint，防止后续扩展破坏 PAYLOAD_SPEC 约束。

## 检查项目

1. 每个 payload 目录包含 criteria.yaml/session.md
2. ID 格式、唯一性、depends_on 引用与无环
3. criteria.yaml 中 script rules 的 check.type 已在 loop-run SKILL.md 注册

## 状态输出

- `.paper/state/payload-lint-report.json`

## Actions

### Step 1: 准备
- action: bash
  cmd: "echo 'payload-linter-loop 准备就绪，等待基座评估 criteria...'"

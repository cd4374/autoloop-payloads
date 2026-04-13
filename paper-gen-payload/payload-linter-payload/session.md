---
payload: "payload-linter-loop"
version: "1.0"
max_iter: 2
---

目标：对 paper-gen payload 体系做协议级 lint，防止后续扩展破坏 PAYLOAD_SPEC 约束。

## 检查项目

1. 每个 payload 目录包含 criteria.md/eval.sh/session.md
2. ID 格式、唯一性、depends_on 引用与无环
3. script criteria 与 eval 输出 ID 集合一致

## 状态输出

- `.paper/state/payload-lint-report.json`

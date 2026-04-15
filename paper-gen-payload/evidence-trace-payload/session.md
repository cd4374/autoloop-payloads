---
payload: "evidence-trace-loop"
version: "1.0"
max_iter: 2
---

目标：确保论文中的关键数值可追溯到实验日志，形成 machine-checkable 证据链。

## 检查项目

1. evidence-trace 索引存在并可解析
2. 每个 claim 映射到 run_*.log（包含文件路径和定位信息）
3. 被映射日志文件全部存在且可读

## 状态输出

- `.paper/state/evidence-trace.json`

## Actions

### Step 1: 准备
- action: bash
  cmd: "echo 'evidence-trace-loop 准备就绪，等待基座评估 criteria...'"

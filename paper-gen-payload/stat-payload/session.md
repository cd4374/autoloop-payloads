---
payload: "stat-loop"
version: "1.0"
max_iter: 2
---

目标：统计规范检查与修复。

## 检查项目

1. 所有结果报告 mean±std
2. 统计显著性检验（p-value/effect size/CI）
3. 无 cherry-picking
4. Grid independence（numerical）
5. Convergence order（numerical）

## 停止条件

- stat-auditor 报告 pass=true
- 或达到 MAX_ITER=2

## 状态输出

- `.paper/state/stat-status.json`: 统计检查状态

## Actions

### Step 1: 准备
- action: bash
  cmd: "echo 'stat-loop 准备就绪，等待基座评估 criteria...'"
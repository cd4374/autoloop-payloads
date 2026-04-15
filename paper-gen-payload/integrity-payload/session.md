---
payload: "integrity-loop"
version: "1.0"
max_iter: 2
---

目标：学术诚信检查，验证数据/图像真实性。

## 检查项目

1. 无数据伪造
2. 无图像操纵（crop/enhance 等）
3. 无抄袭（相似度 <=15%）
4. Conflict of Interest 声明
5. 图像/代码许可证归属
6. 神经网络可视化方法披露

## 停止条件

- integrity-checker 报告 pass=true
- 或达到 MAX_ITER=2

## 状态输出

- `.paper/state/integrity-status.json`: 检查状态

## Actions

### Step 1: 论文数字审计
- action: skill
  skill: paper-claim-audit
  args: "读取 .paper/output/draft.tex，验证论文中每个数字与 .paper/output/logs/ 中原始日志的一致性"

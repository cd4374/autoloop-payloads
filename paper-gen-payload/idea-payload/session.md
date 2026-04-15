---
payload: "idea-loop"
version: "1.0"
max_iter: 3
---

目标：验证研究想法的 novelty × feasibility × impact，确保想法值得推进。

## 评估维度

1. **Novelty**: 与现有工作的差异化
2. **Feasibility**: 技术实现可行性
3. **Impact**: 学术/应用价值

## 停止条件

- 任一候选想法分数 >=80 且 novelty 通过
- 或达到 MAX_ITER=3

## 状态输出

- `.paper/state/idea-status.json`: 当前最佳想法及其评分
- `.paper/loop-logs/idea-round-{N}.json`: 各轮次候选想法列表
- `.paper/input/papers/manual/`: 用户手工补充的文献入口（供 lit/citation loop 使用）

## Actions

### Step 1: 生成候选想法
- action: skill
  skill: idea-creator
  args: "读取 .paper/input/idea.md 中的研究方向，生成 3-5 个候选研究想法，写入 .paper/state/idea-candidates.json"

### Step 2: 核查新颖性
- action: skill
  skill: novelty-check
  args: "读取 .paper/state/idea-candidates.json 中评分最高的 idea，验证其新颖性并输出 .paper/state/novelty-report.json"
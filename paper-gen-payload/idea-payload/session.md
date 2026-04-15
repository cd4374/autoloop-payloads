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

### Step 1: 准备
- action: bash
  cmd: "echo 'idea-loop 准备就绪，等待基座评估 criteria...'"
---
payload: "review-loop"
version: "1.0"
max_iter: 4
---

目标：跨模型审查循环，迭代改进论文直至达标。

## 审查维度权重（来自 payload 配置）

| Dimension | Weight |
|-----------|--------|
| Novelty | 25% |
| Technical Rigor | 20% |
| Experimental Adequacy | 20% |
| Writing Clarity | 15% |
| Citation Accuracy | 10% |
| Reproducibility | 5% |
| Impact | 5% |

## 停止条件

- 综合评分 >=85 且无 blocking issue
- 或达到 MAX_ITER=4

## 分数下降保护

- 连续两轮分数下降 → human-intervention-needed

## 审查模式

- medium: MCP review (Claude 控制 GPT 看到的内容)
- hard: MCP review + Reviewer Memory + Debate Protocol
- nightmare: codex exec (GPT 直接读取 repo)

## 状态输出

- `.paper/state/review-status.json`: 当前评分和 blocking issues
- `.paper/loop-logs/review-round-{N}.json`: 各轮次审查结果
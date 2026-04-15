---
payload: "novelty-check"
version: "1.0"
max_iter: 2
---

目标：验证研究想法的新颖性（novelty），防止在已被做过的方向上浪费时间。

## 评估维度

1. **Novelty**: 与现有工作的差异化（HIGH / MEDIUM / LOW）
2. **Feasibility**: 技术实现可行性
3. **Impact**: 学术/应用价值

## 工作流程

### Phase A: 提取核心主张

从 `.paper/input/idea.md` 提取 3-5 个核心技术主张：
- 方法是什么？
- 解决什么问题？
- 核心机制是什么？
- 与显而易见基线的区别？

### Phase B: 多源文献搜索

对每个核心主张，使用以下来源搜索：
- arXiv (2023-2026)
- ICLR / NeurIPS / ICML 2024-2026
- Semantic Scholar（按引用量排序前 20）
- DBLP 会议论文

### Phase C: Novelty 报告生成

调用 LLM（gpt-5.4 xhigh）综合判断：
- 每个核心主张的新颖性评级（HIGH / MEDIUM / LOW）
- 最接近的先工作
- 总体评分（1-10）
- 建议：PROCEED / PROCEED_WITH_CAUTION / ABANDON

### Phase D: 输出写入

将 novelty 报告写入：
- `.paper/state/novelty-report.json` — 结构化报告
- `.paper/output/novelty-report.md` — 可读 Markdown 摘要

## 停止条件

- `overall_assessment != "ABANDON"` 且 `overall_score >= 5`
- 或达到 MAX_ITER=2

## 状态输出

- `.paper/state/novelty-report.json`: 结构化新颖性报告
- `.paper/output/novelty-report.md`: 可读摘要

## 约束

- 新颖性检查必须是 brutal honest — 假阳性浪费研究时间
- "将 X 应用于 Y" 本身不算新颖，除非揭示了令人惊讶的洞察
- 同时检查方法新颖性和实验设置新颖性

---
payload: "paper-gen"
version: "1.0"
max_iter: 5
paper_type: "NeurIPS"
domain: "ai-exp"
---

目标：从研究想法自动生成一篇高质量、可验证、可重复、真实的学术论文。

## 输入

payload 目录内的 `idea.md` 定义研究想法。若不存在，需用户提供。

## 配置

| 参数 | 值 | 说明 |
|------|-----|------|
| paper_type | NeurIPS | 会议/期刊类型 |
| domain | ai-exp | 论文领域 |
| min_references | 30 | 引用数门槛 |
| min_figures | 5 | 图表数门槛 |
| min_tables | 1 | 表格数门槛 |
| page_limit | 9 | 页数限制 |
| abstract_max_words | 250 | Abstract 字数上限 |
| min_experiment_runs | 3 | 独立运行次数 |
| require_ablation | true | 是否需要 Ablation Study |
| min_recent_refs_pct | 30 | 近五年引用占比 (%) |

## 子 Loop

通过 `fix_skill: loop-run` 触发子 loop：

1. idea-loop (`idea-payload/`): MAX_ITER=3，验证 novelty x feasibility x impact
2. literature-loop (`lit-payload/`): MAX_ITER=2，文献综述完整性
3. experiment-loop (`exp-payload/`): MAX_ITER=3，实验设计与执行
4. citation-loop (`citation-payload/`): MAX_ITER=3，四层引用验证
5. figure-loop (`figure-payload/`): MAX_ITER=5，图表质量 8 维度
6. review-loop (`review-payload/`): MAX_ITER=4，跨模型审查

## 状态文件

- `.loop/results.jsonl`: 每轮评估结果
- `.loop/session.md`: session 上下文
- `.paper/output/`: 生成的论文文件
- `.paper/state/pipeline-status.json`: 主流水线状态（可选，用于追踪进度）

## 约束

- 不伪造实验数据
- 不捏造引用
- reviewer agents 只读不写
- 所有数字来自真实运行
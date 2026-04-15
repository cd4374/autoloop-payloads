---
payload: "research-contract"
version: "1.0"
max_iter: 2
---

目标：从 `.paper/input/idea.md` 和 `.paper/state/novelty-report.json` 生成 `.paper/input/research-contract.md`，作为后续所有子 loop（lit / exp / writing）的共同上下文锚点。

## 输入文件

- `.paper/input/idea.md`: 用户研究想法
- `.paper/state/novelty-report.json`: 新颖性报告

## 输出文件

- `.paper/input/research-contract.md`: 研究契约锚点文档

## 研究契约结构

必须包含以下章节：

1. **Selected Idea**: 想法描述、来源、选择理由
2. **Core Claims**: 核心主张列表（>=1 条）
3. **Method Summary**: 方法摘要（2-3 段，足以让后续 agent 独立实现）
4. **Experiment Design**: 数据集 / 基线 / 指标 / 超参 / 计算预算
5. **Baselines**: 已有基线表格（方法 / 数据集 / 指标 / 分数 / 来源）
6. **Status Checklist**: 里程碑勾选清单

## 停止条件

- research-contract.md 包含所有必需章节
- Core Claims >= 1 条
- Baselines 表格非空
- 或达到 MAX_ITER=2

## 设计原则

- **Context 压缩**：新会话恢复时，LLM 只需读这份契约，无需读完整 idea.md
- **下游友好**：Method Summary 描述清晰，后续 lit / exp / writing agent 可独立推进
- **Baseline 可追溯**：所有基线分数标注来源（论文引用或复现）

## Actions

### Step 1: 准备
- action: bash
  cmd: "echo 'research-contract-loop 准备就绪，等待基座评估 criteria...'"

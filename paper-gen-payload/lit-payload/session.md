---
payload: "literature-loop"
version: "1.0"
max_iter: 2
---

目标：验证文献综述的完整性和覆盖面，并沉淀可复用文献语料。

## 输入契约

- 文献语料目录：`.paper/input/papers/`
  - 自动下载文献：`.paper/input/papers/downloaded/`
  - 用户手工补充：`.paper/input/papers/manual/`（也允许直接放在 `papers/` 根目录）

## 检查项目

1. 相关工作的覆盖面
2. 关键论文的引用
3. 与现有工作的对比
4. 近五年文献的比例
5. 文献语料目录与索引完整性
6. citation cards 仅 Markdown 输出

## 停止条件

- 文献综述覆盖领域关键工作，且语料索引可用于下游引用链路
- 或达到 MAX_ITER=2

## 状态输出

- `.paper/state/lit-status.json`: 文献综述状态
- `.paper/state/lit-corpus-index.json`: 文献语料索引（downloaded/manual/path/title/doi/arxiv 等）
- `.paper/output/citation-cards/`: 引文卡片（仅 `.md`）

## Actions

### Step 1: 准备
- action: bash
  cmd: "echo 'lit-loop 准备就绪，等待基座评估 criteria...'"

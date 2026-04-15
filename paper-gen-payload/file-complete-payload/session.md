---
payload: "file-complete-loop"
version: "1.0"
max_iter: 2
---

目标：确保论文输出文件完整性，并在 hard-review 全通过后生成根目录版本交付包 `Vx/`。

## 必需文件

- draft.tex: LaTeX 源文件
- references.bib: BibTeX 引用
- paper.pdf: 编译后的 PDF
- code/main.py: 实验代码
- code/requirements.txt: Python 依赖
- reproducibility.json: 可重复性信息

## 交付包规则（hard gate 后）

- 版本目录位于项目根：`V1/`, `V2/`, ...（递增且不覆盖）
- 每个 `Vx/` 必须包含：
  - `code/`: 来自 `.paper/output/code/` 的可复现实验代码
  - `latex/`: `draft.tex`、`references.bib`、`figures/` 与编译依赖
  - `else-supports/`: 关键证据与支持材料（下载文献、citation cards、hard-gate state 文件）
- 记录状态文件：`.paper/state/release-package.json`

## 停止条件

- 所有必需文件存在且非空
- 且在 hard gate 全通过时可验证 `Vx/` 结构
- 或达到 MAX_ITER=2

## Actions

### Step 1: 准备
- action: bash
  cmd: "echo 'file-complete-loop 准备就绪，等待基座评估 criteria...'"

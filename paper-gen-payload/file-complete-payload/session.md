---
payload: "file-complete-loop"
version: "1.0"
max_iter: 2
---

目标：确保论文输出文件完整性。

## 必需文件

- draft.tex: LaTeX 源文件
- references.bib: BibTeX 引用
- paper.pdf: 编译后的 PDF
- code/main.py: 实验代码
- code/requirements.txt: Python 依赖
- reproducibility.json: 可重复性信息

## 停止条件

- 所有必需文件存在且非空
- 或达到 MAX_ITER=2

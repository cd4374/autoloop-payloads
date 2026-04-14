- id: FILE-001
  title: draft.tex 存在
  severity: blocking
  evaluator: script
  pass_condition: ".paper/output/draft.tex 存在且非空（文件大小 > 100 字节）。"
  fix_hint: "生成 draft.tex。"

- id: FILE-002
  title: references.bib 存在
  severity: blocking
  evaluator: script
  pass_condition: ".paper/output/references.bib 存在且非空（至少包含 1 个 BibTeX 条目）。"
  fix_hint: "生成 references.bib。"

- id: FILE-003
  title: paper.pdf 存在
  severity: blocking
  evaluator: script
  pass_condition: ".paper/output/paper.pdf 存在且非空（文件大小 > 1KB）。"
  fix_hint: "运行 latexmk 编译生成 paper.pdf。"

- id: FILE-004
  title: code/main.py 存在
  severity: blocking
  evaluator: script
  pass_condition: ".paper/output/code/main.py 存在且非空（文件大小 > 50 字节）。"
  fix_hint: "生成实验代码 main.py。"

- id: FILE-005
  title: code/requirements.txt 存在
  severity: blocking
  evaluator: script
  pass_condition: ".paper/output/code/requirements.txt 存在且非空（文件大小 > 5 字节）。"
  fix_hint: "生成 requirements.txt（pip freeze 或手动列出依赖）。"

- id: FILE-006
  title: reproducibility.json 存在
  severity: blocking
  evaluator: script
  pass_condition: ".paper/output/reproducibility.json 存在且为合法 JSON，包含 hardware/software/hyperparameters/dataset/preprocessing 字段。"
  fix_hint: "生成 reproducibility.json，填写实验环境信息。"

- id: FILE-007
  title: figures/ 目录存在
  severity: blocking
  evaluator: script
  pass_condition: ".paper/output/figures/ 目录存在（即使为空目录）。"
  fix_hint: "创建 figures/ 目录，生成图表文件。"

- id: FILE-008
  title: draft.tex LaTeX 结构完整
  severity: blocking
  evaluator: script
  depends_on: ["FILE-001"]
  pass_condition: "draft.tex 包含 \\documentclass、\\begin{document}、\\end{document} 三个基本结构。"
  fix_hint: "修复 draft.tex 的 LaTeX 基本结构。"

- id: FILE-009
  title: references.bib 与 draft.tex 引用一致
  severity: blocking
  evaluator: script
  depends_on: ["FILE-002"]
  pass_condition: "references.bib 中每个条目在 draft.tex 中有 \\cite{} 使用（不允许孤立引用）。"
  fix_hint: "清理未使用的 BibTeX 条目或补充正文引用。"

- id: FILE-010
  title: 所有必需文件完整性（汇总）
  severity: blocking
  evaluator: script
  depends_on: ["FILE-001", "FILE-002", "FILE-003", "FILE-004", "FILE-005", "FILE-006"]
  pass_condition: "所有以下文件均存在且非空：draft.tex, references.bib, paper.pdf, code/main.py, code/requirements.txt, reproducibility.json。"
  fix_hint: "补充缺失的文件。运行 latexmk 生成 PDF，运行 pip freeze 生成 requirements.txt。"

- id: FILE-011
  title: release 触发条件满足
  severity: blocking
  evaluator: script
  pass_condition: "`.paper/state/runtime-proof.json`、`.paper/state/external-review-log.json`、`.paper/state/evidence-trace.json`、`.paper/state/plagiarism-report.json`、`.paper/state/dataset-inventory.json` 全部存在且符合 hard gate 的基本 pass 条件。"
  fix_hint: "先完成 runtime-proof/external-review/evidence-trace/plagiarism/dataset-license 等 hard gate 证据。"

- id: FILE-012
  title: 根目录版本包结构
  severity: blocking
  evaluator: script
  depends_on: ["FILE-011"]
  pass_condition: "项目根目录存在最新 `Vx/`，且包含 `code/`、`latex/`、`else-supports/` 子目录。"
  fix_hint: "在 hard gate 通过后创建下一个版本目录并补齐三个子目录。"

- id: FILE-013
  title: release-package 状态文件完整
  severity: blocking
  evaluator: script
  depends_on: ["FILE-012"]
  pass_condition: "`.paper/state/release-package.json` 存在，包含 `version_folder`、`created_at`、`trigger`、`evidence_refs`。"
  fix_hint: "生成 release-package.json 并记录版本号、触发来源和证据路径。"

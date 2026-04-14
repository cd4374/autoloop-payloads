# File Complete Payload — 精简版
# 5 个 criteria（原 13 个）：合并文件完整性检查，保留 Vx 打包核心

- id: FILE-001
  title: 核心文件完整性
  severity: blocking
  evaluator: script
  pass_condition: "以下文件均存在且非空：draft.tex, references.bib, paper.pdf, code/main.py, code/requirements.txt, reproducibility.json。"
  fix_hint: "补充缺失的核心文件。运行 latexmk 编译 PDF，pip freeze 生成 requirements.txt。"

- id: FILE-002
  title: LaTeX 结构与引用一致
  severity: blocking
  evaluator: script
  depends_on: ["FILE-001"]
  pass_condition: "draft.tex 包含 \\documentclass/\\begin{document}/\\end{document}；所有 BibTeX 条目在正文中被引用。"
  fix_hint: "修复 LaTeX 结构，补充正文引用。"

- id: FILE-003
  title: Hard gate 证据就绪
  severity: blocking
  evaluator: script
  depends_on: ["FILE-001"]
  pass_condition: "runtime-proof.json (exit_code=0)、external-review-log.json (verdict≠blocking)、evidence-trace.json、plagiarism-report.json (status=success, sim≤15%) 全部存在。"
  fix_hint: "完成各 P0 门控后生成对应证据文件。"

- id: FILE-004
  title: Vx 交付包结构完整
  severity: blocking
  evaluator: script
  depends_on: ["FILE-003"]
  pass_condition: "项目根目录存在最新 Vx/ 目录，包含 code/、latex/、else-supports/ 三个子目录。"
  fix_hint: "在 hard gate 通过后创建 Vx 版本目录并复制对应文件。"

- id: FILE-005
  title: release-package 状态文件完整
  severity: blocking
  evaluator: script
  depends_on: ["FILE-004"]
  pass_condition: ".paper/state/release-package.json 存在且包含 version_folder/created_at/trigger/evidence_refs 字段。"
  fix_hint: "生成 release-package.json，记录版本号、触发来源和证据引用。"

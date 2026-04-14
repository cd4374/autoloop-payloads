- id: INIT-001
  title: 顶级目录结构完整
  severity: blocking
  evaluator: script
  pass_condition: ".paper/ 目录存在且包含 state/, input/, output/ 子目录；.paper/input/idea.md 存在且非空"
  fix_hint: "创建 .paper/ 目录结构：mkdir -p .paper/state .paper/input .paper/output；创建 idea.md 描述研究想法"

- id: INIT-002
  title: pipeline-status.json 已初始化
  severity: blocking
  evaluator: script
  depends_on: ["INIT-001"]
  pass_condition: ".paper/state/pipeline-status.json 存在且包含 current_stage、completed_stages 字段"
  fix_hint: "创建 pipeline-status.json，设置 current_stage='paper-init'，completed_stages=[]"

- id: INIT-003
  title: paper-type.json 已初始化
  severity: blocking
  evaluator: script
  depends_on: ["INIT-001"]
  pass_condition: ".paper/state/paper-type.json 存在且包含 venue、paper_domain、derived_thresholds 字段"
  fix_hint: "创建 .paper/state/paper-type.json，从父 payload session.md 读取 paper_type/domain 配置，计算 derived_thresholds（min_references/min_figures/min_tables/page_limit/abstract_max_words/min_experiment_runs/require_ablation/min_recent_refs_pct），写入 JSON。"

- id: INIT-004
  title: draft.tex 已生成
  severity: blocking
  evaluator: script
  depends_on: ["INIT-002"]
  pass_condition: ".paper/output/draft.tex 存在且文件大小 > 100 字节，包含 \\documentclass、\\begin{document}、\\end{document} 结构"
  fix_hint: "根据 idea.md 和父 payload 配置生成 draft.tex：1) 读取 idea.md 获取研究主题；2) 根据 paper_type 确定文档类和页数限制；3) 生成包含 Abstract、Introduction、Related Work、Method、Experiments、Conclusion、Limitations、References 的完整论文，每章包含具体内容而非占位符"

- id: INIT-005
  title: references.bib 已生成
  severity: blocking
  evaluator: script
  depends_on: ["INIT-004"]
  pass_condition: ".paper/output/references.bib 存在且至少包含 5 个有效的 BibTeX 条目"
  fix_hint: "为 draft.tex 中的引用生成 references.bib：1) 提取 draft.tex 中所有 \\cite{} 命令；2) 搜索相关文献；3) 生成 BibTeX 条目；4) 确保包含近五年文献"

- id: INIT-006
  title: 实验代码已生成
  severity: blocking
  evaluator: script
  depends_on: ["INIT-004"]
  pass_condition: ".paper/output/code/main.py 存在且文件大小 > 50 字节，包含可导入的依赖和基本结构"
  fix_hint: "根据 draft.tex 中的 Method 和 Experiments 章节生成实验代码：1) 分析方法描述，提取数据集、模型、训练参数；2) 生成 Python 代码，包含 import、数据加载、模型定义、训练循环、评估指标；3) 确保代码使用真实数据集"

- id: INIT-007
  title: requirements.txt 已生成
  severity: blocking
  evaluator: script
  depends_on: ["INIT-006"]
  pass_condition: ".paper/output/code/requirements.txt 存在且列出 main.py 的所有依赖"
  fix_hint: "分析 main.py 的 import 语句，生成 requirements.txt"

- id: INIT-008
  title: reproducibility.json 已填写
  severity: blocking
  evaluator: script
  depends_on: ["INIT-006", "INIT-007"]
  pass_condition: ".paper/output/reproducibility.json 存在且包含 hardware、software、hyperparameters、dataset、preprocessing 字段，内容非空"
  fix_hint: "填写 reproducibility.json：hardware（GPU/CPU）、software（Python/框架版本）、hyperparameters（学习率/batch size/epoch）、dataset（名称/版本/来源）、preprocessing（预处理流程）"

- id: INIT-009
  title: figures 目录已创建
  severity: blocking
  evaluator: script
  depends_on: ["INIT-004"]
  pass_condition: ".paper/output/figures/ 目录存在"
  fix_hint: "创建 figures/ 目录"

- id: INIT-010
  title: 初始化完成
  severity: blocking
  evaluator: llm
  depends_on: ["INIT-001", "INIT-002", "INIT-004", "INIT-005", "INIT-006", "INIT-007", "INIT-008", "INIT-009"]
  pass_condition: "所有初始化检查通过，生成的内容语义连贯、与研究 idea 一致、格式正确，无明显的逻辑错误或占位符内容"
  fix_hint: "检查 draft.tex、references.bib、code/main.py 是否与研究 idea 一致，内容是否完整，修复不一致或缺失"
- id: REV-001
  title: 综合评分达标
  severity: blocking
  evaluator: llm
  depends_on: ["REV-101", "REV-102", "REV-103", "REV-104", "REV-105", "REV-106", "REV-107", "REV-108", "REV-109", "REV-110", "REV-111"]
  pass_condition: "跨模型审查综合评分 >= 85/100。评分基于以下维度加权：Novelty(25%), Technical Rigor(20%), Experimental Adequacy(20%), Writing Clarity(15%), Citation Accuracy(10%), Reproducibility(5%), Impact(5%)。script evaluator 已通过的客观项（REV-101~REV-111）不得在 LLM 评分中重复扣分。"
  fix_hint: "根据审查反馈修改论文。优先修复 blocking objective issues（REV-101~REV-111 失败项），再改进主观质量。"

- id: REV-002
  title: 无 blocking issue
  severity: blocking
  evaluator: llm
  depends_on: ["REV-001"]
  pass_condition: "无 reviewer 标记为 blocking 的 issue。所有 blocking issues 必须已解决。"
  fix_hint: "修复所有 blocking issues。"

- id: REV-003
  title: Integrity 检查通过
  severity: blocking
  evaluator: llm
  pass_condition: "integrity-checker 报告 pass=true（无数据伪造、无图像操纵、无抄袭、无缺失诚信声明）"
  fix_hint: "修复学术诚信问题。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/integrity-payload"

- id: REV-004
  title: 统计合规通过
  severity: blocking
  evaluator: llm
  depends_on: ["REV-106"]
  pass_condition: "stat-auditor 报告 pass=true。包含 p-value/CI/effect size，无 cherry-picking。"
  fix_hint: "修复统计规范问题。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/stat-payload"

- id: REV-101
  title: 必要章节完整（客观）
  severity: blocking
  evaluator: script
  pass_condition: "draft.tex 包含 Abstract、Introduction、Method、Experiments、Conclusion、Limitations 章节"
  fix_hint: "补充缺失章节。"

- id: REV-102
  title: Abstract 字数限制（客观）
  severity: blocking
  evaluator: script
  pass_condition: "Abstract 字数 <= payload 配置的 abstract_max_words (NeurIPS/ICML/ICLR<=250, AAAI<=200, Journal<=300, Short/Letter<=150)"
  fix_hint: "调整 Abstract 长度。"

- id: REV-103
  title: 引用数量达标（客观）
  severity: blocking
  evaluator: script
  pass_condition: "references.bib 条目数 >= payload 配置的 min_references (NeurIPS/ICML/ICLR>=30, AAAI>=25, Journal>=40, Short>=15, Letter>=10)"
  fix_hint: "补充引用至达标。"

- id: REV-104
  title: 图表数量达标（客观）
  severity: blocking
  evaluator: script
  pass_condition: "图表数量 >= payload 配置的 min_figures"
  fix_hint: "增加图表至达标。"

- id: REV-105
  title: 表格数量达标（客观）
  severity: blocking
  evaluator: script
  pass_condition: "表格数量 >= payload 配置的 min_tables (>=1)"
  fix_hint: "增加表格至达标。"

- id: REV-106
  title: 统计报告规范（客观）
  severity: blocking
  evaluator: script
  pass_condition: "实验结果包含 mean±std，不存在无误差报告的数值"
  fix_hint: "补充误差报告。"

- id: REV-107
  title: Conflict of Interest 存在（客观）
  severity: blocking
  evaluator: script
  pass_condition: "draft.tex 包含 Conflict of Interest 声明"
  fix_hint: "添加 Conflict of Interest 声明。"

- id: REV-108
  title: Limitations 段落存在（客观）
  severity: blocking
  evaluator: script
  pass_condition: "draft.tex 包含 Limitations 段落"
  fix_hint: "添加 Limitations 段落。"

- id: REV-109
  title: Reproducibility Statement 存在（客观）
  severity: blocking
  evaluator: script
  pass_condition: "draft.tex 包含 Reproducibility Statement 段落"
  fix_hint: "添加 Reproducibility Statement 段落。"

- id: REV-110
  title: 代码和依赖完整（客观）
  severity: blocking
  evaluator: script
  pass_condition: ".paper/output/code/main.py 和 .paper/output/code/requirements.txt 均存在且非空"
  fix_hint: "补充实验代码或 requirements.txt。"

- id: REV-111
  title: LaTeX 编译成功（客观）
  severity: blocking
  evaluator: script
  pass_condition: "latexmk -pdf draft.tex 成功，生成 paper.pdf 且无编译错误"
  fix_hint: "修复 LaTeX 编译错误。"

- id: REV-005
  title: Novelty 维度评分
  severity: advisory
  evaluator: llm
  depends_on: ["REV-101"]
  pass_condition: "Novelty 维度评分 >= 80/100"
  fix_hint: "增强方法创新性，突出与现有工作的差异。"

- id: REV-006
  title: Technical Rigor 维度评分
  severity: advisory
  evaluator: llm
  depends_on: ["REV-106", "REV-108"]
  pass_condition: "Technical Rigor 维度评分 >= 80/100"
  fix_hint: "加强技术严谨性，确保理论推导和实验设计无漏洞。"

- id: REV-007
  title: Experimental Adequacy 维度评分
  severity: advisory
  evaluator: llm
  depends_on: ["REV-103", "REV-104", "REV-105", "REV-110"]
  pass_condition: "Experimental Adequacy 维度评分 >= 80/100"
  fix_hint: "完善实验设计，增加基线对比或消融实验。"

- id: REV-008
  title: Writing Clarity 维度评分
  severity: advisory
  evaluator: llm
  depends_on: ["REV-101", "REV-102"]
  pass_condition: "Writing Clarity 维度评分 >= 80/100"
  fix_hint: "改进写作清晰度，优化句子结构和逻辑流畅性。"

- id: REV-112
  title: Citation Accuracy 维度评分
  severity: advisory
  evaluator: llm
  depends_on: ["REV-103"]
  pass_condition: "Citation Accuracy 维度评分 >= 80/100（引用格式正确、无幻觉引用、与正文一致）"
  fix_hint: "修正引用格式，移除幻觉引用。"

- id: REV-113
  title: Impact 维度评分
  severity: advisory
  evaluator: llm
  depends_on: ["REV-109"]
  pass_condition: "Impact 维度评分 >= 80/100（研究问题的重要性和应用前景）"
  fix_hint: "强调研究的应用价值和影响。"

- id: REV-114
  title: Reproducibility 维度评分
  severity: advisory
  evaluator: llm
  depends_on: ["REV-109", "REV-110"]
  pass_condition: "Reproducibility 维度评分 >= 80/100（代码、数据、环境可复现）"
  fix_hint: "完善可重复性信息，确保代码可运行。"

- id: REV-115
  title: 跨模型审查触发
  severity: advisory
  evaluator: llm
  pass_condition: "审查过程中调用了外部模型（如 GPT-5/GPT-4.4）进行独立评审，而非仅依赖同一模型自审。审查记录中包含外部模型返回的评审意见。"
  fix_hint: "配置 Codex MCP 或外部模型 endpoint，触发跨模型审查。"

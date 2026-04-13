- id: PG-036
  title: 顶级内容生成 - draft.tex 和论文结构
  severity: blocking
  evaluator: script
  pass_condition: ".paper/output/draft.tex 存在且文件大小 > 100 字节，包含 LaTeX 基本结构（\\documentclass、\\begin{document}、\\end{document}）"
  fix_hint: "根据 idea.md 生成完整的 draft.tex：1) 读取 .paper/input/idea.md 获取研究主题；2) 根据 payload 配置确定文档类（如 NeurIPS 2025）和页数限制；3) 生成包含 Abstract、Introduction、Related Work、Method、Experiments、Conclusion、Limitations、References 的完整论文，每个章节有具体内容而非占位符；4) 生成 references.bib（至少 5 个真实引用）和 code/main.py（基本结构）"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/paper-init-payload"

- id: PG-037
  title: 论文初始化完成
  severity: blocking
  evaluator: script
  depends_on: ["PG-036"]
  pass_condition: ".paper/output/draft.tex 存在且文件大小 > 100 字节，.paper/output/references.bib 存在且至少包含 5 个 BibTeX 条目，.paper/output/code/main.py 存在"
  fix_hint: "启动论文初始化流程，通过 paper-init-payload 生成 draft.tex、references.bib、实验代码等基础文件。这是端到端生成的第一步。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/paper-init-payload"

- id: PG-038
  title: pipeline 状态持续更新
  severity: blocking
  evaluator: script
  depends_on: ["PG-037"]
  pass_condition: ".paper/state/pipeline-status.json 包含 current_stage、completed_stages、round、last_updated 字段；completed_stages 非空并包含 paper-init。"
  fix_hint: "更新 .paper/state/pipeline-status.json：1) 从 completed_stages 数组中移除已完成的阶段；2) 向 completed_stages 追加当前完成的阶段（如 paper-init）；3) 更新 current_stage 为下一阶段；4) 将 round 递增；5) 将 last_updated 更新为当前 UTC 时间（ISO-8601 格式）。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/paper-init-payload"

- id: PG-001
  title: 目录结构完整
  severity: blocking
  evaluator: script
  depends_on: ["PG-037"]
  pass_condition: ".paper/output/ 目录下存在 draft.tex、references.bib、paper.pdf、code/main.py、code/requirements.txt、reproducibility.json"
  fix_hint: "生成所有必需文件。运行 latexmk 生成 PDF，运行 pip freeze 生成 requirements.txt，填写 reproducibility.json。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/file-complete-payload"

- id: PG-002
  title: LaTeX 编译成功
  severity: blocking
  evaluator: script
  depends_on: ["PG-001"]
  pass_condition: "latexmk -pdf draft.tex 成功，生成 paper.pdf 且无编译错误"
  fix_hint: "修复 LaTeX 编译错误。检查缺失的宏包或格式问题。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/writing-payload"

- id: PG-003
  title: 页数符合限制
  severity: blocking
  evaluator: script
  depends_on: ["PG-002"]
  pass_condition: "pdf 页数 <= payload 配置的 page_limit (NeurIPS:9, ICML/ICLR/AAAI:8, Journal:30, Short:4, Letter:2)"
  fix_hint: "调整论文内容长度以符合页数限制。压缩附录或减少细节描述。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/writing-payload"

- id: PG-004
  title: 引用数量门槛
  severity: blocking
  evaluator: script
  depends_on: ["PG-001"]
  pass_condition: "references.bib 条目数 >= payload 配置的 min_references (NeurIPS/ICML/ICLR>=30, AAAI>=25, Journal>=40, Short>=15, Letter>=10)"
  fix_hint: "补充引用至达标。优先补充领域关键论文和近五年文献。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/citation-payload"

- id: PG-005
  title: 近五年引用占比
  severity: blocking
  evaluator: script
  depends_on: ["PG-004"]
  pass_condition: "近五年引用占比 >= payload 配置的 min_recent_refs_pct (ai-exp>=30%, ai-theory>=15%, numerical/physics>=20%)"
  fix_hint: "补充近期文献引用。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/citation-payload"

- id: PG-006
  title: 引用幻觉检验
  severity: blocking
  evaluator: llm
  depends_on: ["PG-004"]
  pass_condition: "所有引用通过 Layer 2-3 验证（DOI 或 arXiv 存在），无 hallucinated 条目。Layer 2: DOI/arXiv URL 可访问。Layer 3: CrossRef title+year 一致性。"
  fix_hint: "移除幻觉引用，补充真实引用。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/citation-payload"

- id: PG-007
  title: 图表数量门槛
  severity: blocking
  evaluator: script
  depends_on: ["PG-001"]
  pass_condition: "图表数量 >= payload 配置的 min_figures (NeurIPS/ICML/ICLR/Journal>=5, AAAI>=4, Short>=3, Letter>=2)"
  fix_hint: "增加图表至达标。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/figure-payload"

- id: PG-008
  title: 表格数量门槛
  severity: blocking
  evaluator: script
  depends_on: ["PG-001"]
  pass_condition: "表格数量 >= payload 配置的 min_tables (>=1)"
  fix_hint: "增加表格至达标。至少包含主要结果对比表。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/writing-payload"

- id: PG-009
  title: 图表质量 8 维度
  severity: blocking
  evaluator: llm
  depends_on: ["PG-007"]
  pass_condition: "所有图表通过 8 维度审查（准确性、可读性、无截断、色盲友好、标题完整、轴完整、误差棒说明、风格一致），综合评分 >=8.0/10。"
  fix_hint: "修复图表问题。参考 figure-payload 评估结果。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/figure-payload"

- id: PG-010
  title: 向量图表格式
  severity: blocking
  evaluator: script
  depends_on: ["PG-007"]
  pass_condition: "所有图表文件为 .pdf 或 .eps 格式，无纯栅格图"
  fix_hint: "将图表转换为向量格式。使用 matplotlib 导出 PDF。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/figure-payload"

- id: PG-011
  title: 随机种子固定
  severity: blocking
  evaluator: script
  depends_on: ["PG-001"]
  pass_condition: "code/main.py 包含随机种子设置（torch.manual_seed/np.random.seed/random.seed 等）。"
  fix_hint: "在实验代码中添加随机种子固定。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/exp-payload"

- id: PG-012
  title: 可重复性报告
  severity: blocking
  evaluator: script
  depends_on: ["PG-011"]
  pass_condition: "reproducibility.json 包含：hardware、software、hyperparameters、dataset（version/source）、preprocessing 字段，且内容非空。"
  fix_hint: "补充 reproducibility.json 所有必需字段。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/exp-payload"

- id: PG-013
  title: Reproducibility Statement
  severity: blocking
  evaluator: script
  depends_on: ["PG-001"]
  pass_condition: "draft.tex 包含 Reproducibility Statement 段落，说明实验环境、随机种子、数据集来源。"
  fix_hint: "添加 Reproducibility Statement 段落到 draft.tex，描述实验环境配置、随机种子设置和数据集来源信息。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/writing-payload"

- id: PG-014
  title: 环境快照
  severity: blocking
  evaluator: script
  depends_on: ["PG-001"]
  pass_condition: "code/requirements.txt 或 code/environment.yml 存在且非空"
  fix_hint: "生成 requirements.txt（pip freeze > requirements.txt）或 environment.yml。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/exp-payload"

- id: PG-015
  title: 统计报告规范
  severity: blocking
  evaluator: script
  depends_on: ["PG-001"]
  pass_condition: "所有实验结果报告 mean±std，不存在无误差报告的数值。格式：0.85\\pm 0.03 或 85.3±3.2。"
  fix_hint: "补充误差报告。确保所有定量结果附带标准差。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/stat-payload"

- id: PG-016
  title: 统计显著性检验
  severity: blocking
  evaluator: llm
  depends_on: ["PG-015"]
  pass_condition: "实验结果包含统计显著性检验（p-value 或 confidence interval 或 effect size）。"
  fix_hint: "添加统计显著性检验。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/stat-payload"

- id: PG-017
  title: 无 Cherry-picking
  severity: blocking
  evaluator: llm
  depends_on: ["PG-001"]
  pass_condition: "draft.tex 不包含 cherry-picking 信号词（'best result'/'selectively reported'/'only show' 等），且所有报告结果与实验日志一致。"
  fix_hint: "报告所有实验结果，移除或重新表述疑似 cherry-picking 的描述。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/integrity-payload"

- id: PG-018
  title: Ablation Study（需消融时）
  severity: blocking
  evaluator: script
  depends_on: ["PG-001"]
  pass_condition: "当 payload 配置的 require_ablation=true 时，draft.tex 包含 Ablation Study 章节。"
  fix_hint: "添加 Ablation Study 章节，分析每个关键组件的贡献。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/exp-payload"

- id: PG-019
  title: Limitations 段落
  severity: blocking
  evaluator: script
  depends_on: ["PG-001"]
  pass_condition: "draft.tex 包含 Limitations 章节，诚实陈述方法局限性和适用范围。"
  fix_hint: "添加 Limitations 段落到 draft.tex，诚实陈述方法的局限性、适用范围和已知不足。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/writing-payload"

- id: PG-020
  title: 必要章节完整
  severity: blocking
  evaluator: script
  depends_on: ["PG-001"]
  pass_condition: "draft.tex 包含：Abstract、Introduction、Method、Experiments、Conclusion、References。"
  fix_hint: "补充缺失章节。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/writing-payload"

- id: PG-021
  title: Abstract 字数限制
  severity: blocking
  evaluator: script
  depends_on: ["PG-020"]
  pass_condition: "Abstract 字数 <= payload 配置的 abstract_max_words (NeurIPS/ICML/ICLR<=250, AAAI<=200, Journal<=300, Short/Letter<=150)。"
  fix_hint: "调整 Abstract 长度至符合 payload 配置的字数限制。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/writing-payload"

- id: PG-022
  title: 学术诚信完整性
  severity: blocking
  evaluator: llm
  depends_on: ["PG-001"]
  pass_condition: "draft.tex 包含：Conflict of Interest statement（必须）、图像/代码许可证归属（若使用第三方）、无图像操纵声明（若使用图像）。"
  fix_hint: "添加学术诚信声明。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/integrity-payload"

- id: PG-023
  title: 无图像操纵
  severity: blocking
  evaluator: llm
  depends_on: ["PG-001"]
  pass_condition: "所有图像文件无 crop/enhance 等操纵（除标注外），无伪造数据图表。图表数据与实验日志一致。"
  fix_hint: "移除操纵图像或添加披露，确保图表数据真实。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/integrity-payload"

- id: PG-024
  title: 独立运行次数
  severity: blocking
  evaluator: script
  depends_on: ["PG-001"]
  pass_condition: ".paper/output/logs/ 目录下独立运行次数 >= payload 配置的 min_experiment_runs (ai-exp>=3, Journal>=5)。每个 run_*.log 对应一次完整实验。"
  fix_hint: "增加独立运行次数。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/exp-payload"

- id: PG-025
  title: Grid Independence（数值计算时）
  severity: advisory
  evaluator: script
  depends_on: ["PG-001"]
  pass_condition: "当 paper_domain=numerical 时，至少在 2 个不同网格上进行验证，draft.tex 包含网格无关性讨论。"
  fix_hint: "添加网格独立性测试。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/stat-payload"

- id: PG-026
  title: Convergence Order（数值计算时）
  severity: advisory
  evaluator: script
  depends_on: ["PG-001"]
  pass_condition: "当 paper_domain=numerical 时，报告收敛阶数（first order / second order 等）。"
  fix_hint: "计算并报告收敛阶数。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/stat-payload"

- id: PG-027
  title: 跨模型审查通过
  severity: blocking
  evaluator: llm
  depends_on: ["PG-001", "PG-020"]
  pass_condition: "外部审查模型综合分 >=85，且无 blocking issue。审查记录中包含外部模型返回的评审意见（非同模型自审）。"
  fix_hint: "根据审查反馈修改论文。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/review-payload"

- id: PG-028
  title: 数据完整性
  severity: blocking
  evaluator: llm
  depends_on: ["PG-001", "PG-023"]
  pass_condition: "integrity-checker 报告 pass=true，无数据伪造、无图像操纵、无抄袭（相似度 <=15%）。所有数字可从 logs/ 追溯。"
  fix_hint: "修复数据完整性问题。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/integrity-payload"

- id: PG-029
  title: 神经网络可视化披露
  severity: advisory
  evaluator: script
  depends_on: ["PG-001"]
  pass_condition: "若使用神经网络可视化方法（attention map、saliency map、t-SNE、Grad-CAM 等），在 method 或 appendix 中披露生成方法和工具。"
  fix_hint: "添加神经网络可视化方法披露。"

- id: PG-030
  title: 引用正文一致性
  severity: blocking
  evaluator: script
  depends_on: ["PG-004"]
  pass_condition: "references.bib 中每个条目在 draft.tex 中有 \\cite{} 使用。无孤立引用条目。"
  fix_hint: "清理未使用引用或补充正文引用。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/citation-payload"

- id: PG-031
  title: 无伪造 BibTeX 条目
  severity: blocking
  evaluator: llm
  depends_on: ["PG-004"]
  pass_condition: "references.bib 中所有条目为真实文献，title/author/year/journal 可验证。BibTeX 条目与引用的原文一致。"
  fix_hint: "移除捏造的 BibTeX 条目，补充真实文献。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/citation-payload"

- id: PG-032
  title: 实验结果可追溯
  severity: blocking
  evaluator: script
  depends_on: ["PG-024"]
  pass_condition: "draft.tex 中报告的所有数字可从 .paper/output/logs/run_*.log 追溯。无无法在日志中找到支撑数据的报告结果。"
  fix_hint: "确保所有报告结果来自 logs/ 目录中的实验日志。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/exp-payload"

- id: PG-033
  title: 代码可独立运行
  severity: blocking
  evaluator: script
  depends_on: ["PG-001"]
  pass_condition: "code/main.py 可独立运行，无语法错误，可导入所有依赖。"
  fix_hint: "修复代码错误，确保可独立运行。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/exp-payload"

- id: PG-034
  title: 超参数完整列出
  severity: blocking
  evaluator: llm
  depends_on: ["PG-001"]
  pass_condition: "论文中列出所有关键超参数（learning_rate/batch_size/weight_decay/optimizer/epoch/activation），无'按经验选取'等模糊表述。"
  fix_hint: "补充完整超参数列表。"

- id: PG-039
  title: 代码仓库版本锁定
  severity: blocking
  evaluator: script
  depends_on: ["PG-001"]
  pass_condition: "reproducibility.json 包含 repository 字段（url/tag/commit/doi 至少一项非空），或 payload 配置的 repository.url 非空且指向有效的 GitHub/Zenodo/Code Ocean 仓库。"
  fix_hint: "在 reproducibility.json 中填写代码仓库 URL 和版本锁定（tag 或 commit SHA）。建议使用 GitHub Release 或 Zenodo DOI 锁定版本。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/exp-payload"

- id: PG-035
  title: 论文写作完整性（LLM 评估）
  severity: advisory
  evaluator: llm
  depends_on: ["PG-020", "PG-021", "PG-019"]
  pass_condition: "论文写作质量满足以下标准：逻辑连贯、语言准确、结构合理、格式规范，各章节之间过渡自然，无语法错误。"
  fix_hint: "改进写作质量。优化句子结构，确保逻辑连贯，检查拼写和语法错误。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/writing-payload"

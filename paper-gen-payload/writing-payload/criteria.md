- id: WRT-001
  title: Abstract 生成
  severity: blocking
  evaluator: llm
  pass_condition: "draft.tex 包含 Abstract 章节，字数 <= payload 配置的 abstract_max_words，涵盖问题、方法、结果"
  fix_hint: "生成或调整 Abstract"

- id: WRT-002
  title: Introduction 生成
  severity: blocking
  evaluator: llm
  pass_condition: "draft.tex 包含 Introduction 章节，涵盖背景、动机、主要贡献列表"
  fix_hint: "生成 Introduction"

- id: WRT-003
  title: Related Work 生成
  severity: blocking
  evaluator: llm
  pass_condition: "draft.tex 包含 Related Work 章节，引用关键论文并与现有工作对比"
  fix_hint: "生成 Related Work"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/lit-payload"

- id: WRT-004
  title: Method 生成
  severity: blocking
  evaluator: llm
  pass_condition: "draft.tex 包含 Method 章节，清晰描述方法架构、算法流程、关键创新点"
  fix_hint: "生成 Method"

- id: WRT-005
  title: Experiments 生成
  severity: blocking
  evaluator: llm
  pass_condition: "draft.tex 包含 Experiments 章节，包含数据集、基线、指标、实验结果表格"
  fix_hint: "生成 Experiments"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/exp-payload"

- id: WRT-006
  title: Ablation Study 生成（需消融时）
  severity: blocking
  evaluator: llm
  pass_condition: "当 require_ablation=true 时，包含 Ablation Study 章节分析关键组件贡献"
  fix_hint: "生成 Ablation Study"

- id: WRT-007
  title: Conclusion 生成
  severity: blocking
  evaluator: llm
  pass_condition: "draft.tex 包含 Conclusion 章节，总结主要发现和未来工作"
  fix_hint: "生成 Conclusion"

- id: WRT-008
  title: Limitations 生成
  severity: blocking
  evaluator: llm
  pass_condition: "draft.tex 包含 Limitations 章节，诚实陈述方法局限性"
  fix_hint: "生成 Limitations"

- id: WRT-009
  title: LaTeX 格式规范
  severity: blocking
  evaluator: script
  pass_condition: "draft.tex 符合目标 venue 格式要求（使用正确 documentclass、宏包）"
  fix_hint: "调整 LaTeX 格式"

- id: WRT-010
  title: 图表引用完整
  severity: blocking
  evaluator: script
  pass_condition: "draft.tex 中的 \\includegraphics 对应 figures/ 目录下的真实文件"
  fix_hint: "补充缺失图表或修正引用路径"
- id: INT-001
  title: 数据真实性（信号检测）
  severity: blocking
  evaluator: script
  pass_condition: "draft.tex 不包含明显数据伪造信号（如不可能值：100.00% 精度；负的准确率）。script 级检查无法替代实验日志验证，最终以 logs/run_*.log 一致性为准。"
  fix_hint: "确保所有数字来自真实实验运行。如有人工选取结果，必须披露选取标准。"

- id: INT-010
  title: 数据真实性（语义验证）
  severity: blocking
  evaluator: llm
  depends_on: ["INT-001"]
  pass_condition: "所有实验数字可从 .paper/output/logs/run_*.log 中追溯，无捏造。BibTeX 条目与引用对应，无伪造文献。"
  fix_hint: "移除伪造数据，运行真实实验。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/integrity-payload"

- id: INT-002
  title: 无图像操纵
  severity: blocking
  evaluator: script
  pass_condition: "draft.tex 不包含图像操纵披露词（如'cropped'、'contrast enhanced'、'brightness adjusted'），或已添加说明。"
  fix_hint: "移除操纵图像，添加披露说明，或使用原始图像。"

- id: INT-011
  title: 无图像操纵（语义验证）
  severity: blocking
  evaluator: llm
  depends_on: ["INT-002"]
  pass_condition: "所有 figure 文件与论文数据一致，无选择性展示或增强。如有图像处理，需在 figure caption 中披露。"
  fix_hint: "确保图像与原始数据一致，披露所有图像处理步骤。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/figure-payload"

- id: INT-003
  title: 抄袭检测（信号检测）
  severity: blocking
  evaluator: script
  pass_condition: "draft.tex 不包含版权声明混入正文等明显抄袭信号。注意：script 检查无法替代专业查重工具。"
  fix_hint: "使用 Turnitin/iThenticate 等工具查重。重写重复内容。"

- id: INT-012
  title: 抄袭检测（语义验证）
  severity: blocking
  evaluator: llm
  depends_on: ["INT-003"]
  pass_condition: "正文写作使用自己的语言，无大段复制粘贴痕迹，引用格式正确。注意：LLM 无法计算实际相似度，此 criterion 仅作语义层面的写作原创性评估。正式投稿前必须使用 iThenticate/Turnitin 等专业工具进行查重。"
  fix_hint: "重写重复内容，确保引用格式正确。注意：当前无法实际计算相似度百分比，此 criterion 仅作提醒。正式查重需调用外部 API（如 Turnitin/iThenticate）或人工检查。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/integrity-payload"

- id: INT-004
  title: Conflict of Interest 声明
  severity: blocking
  evaluator: script
  pass_condition: "draft.tex 包含 Conflict of Interest 声明或'No Conflict of Interest'声明。"
  fix_hint: "添加 Conflict of Interest 声明。"

- id: INT-005
  title: 许可证归属
  severity: blocking
  evaluator: script
  pass_condition: "使用第三方图像/代码时，在论文中标注许可证来源；不使用第三方内容时视为通过。"
  fix_hint: "添加许可证归属信息，或移除未授权的第三方内容。"

- id: INT-006
  title: 神经网络可视化披露
  severity: blocking
  evaluator: script
  pass_condition: "若使用神经网络可视化方法（attention map、saliency map、t-SNE、Grad-CAM 等），在 method 或 appendix 中披露生成方法、工具和参数。"
  fix_hint: "添加神经网络可视化方法披露，包括使用的工具和参数设置。"

- id: INT-007
  title: 引用不虚构（幻觉引用检测）
  severity: blocking
  evaluator: llm
  pass_condition: "所有引用条目真实存在（通过 Layer 2 DOI/arXiv 验证），title/year/author 与原文一致。"
  fix_hint: "移除幻觉引用，补充真实引用。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/citation-payload"

- id: INT-008
  title: 数据完整性（无 cherry-picking）
  severity: blocking
  evaluator: llm
  pass_condition: "报告中使用的数字与 logs/ 目录下的 run_*.log 一致，无选择性展示。"
  fix_hint: "报告所有实验结果，补充缺失的实验日志。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/integrity-payload"

- id: INT-009
  title: BibTeX 条目不虚构
  severity: blocking
  evaluator: llm
  pass_condition: "references.bib 中所有条目为真实文献，不包含捏造的 author/title/year/journal。"
  fix_hint: "移除捏造的 BibTeX 条目，通过 DOI/arXiv 查询补充真实文献。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/citation-payload"

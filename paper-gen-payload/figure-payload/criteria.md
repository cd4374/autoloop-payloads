# Figure Payload — 精简版
# 8 个 criteria（原 29 个）：保留可脚本化的检查，合并 8 维度 LLM 评估

- id: FIG-001
  title: 图表数量门槛
  severity: blocking
  evaluator: script
  pass_condition: "图表数量 >= min_figures (NeurIPS>=5, AAAI>=4, Short>=3)"
  fix_hint: "增加图表：实验结果对比、消融分析、关键可视化。"

- id: FIG-002
  title: 向量格式
  severity: blocking
  evaluator: script
  depends_on: ["FIG-001"]
  pass_condition: "除 figures/ai_generated/ 目录外，所有图表为 .pdf 或 .eps 格式。"
  fix_hint: "使用 matplotlib 保存 PDF：plt.savefig('fig.pdf', dpi=300, bbox_inches='tight')。"

- id: FIG-003
  title: 图表引用与文件一致
  severity: blocking
  evaluator: script
  depends_on: ["FIG-001"]
  pass_condition: "draft.tex 中每个 \\includegraphics 引用的文件在 figures/ 下存在。"
  fix_hint: "补齐缺失图表文件，或修正引用路径。"

- id: FIG-004
  title: 栅格图 DPI 达标
  severity: blocking
  evaluator: script
  depends_on: ["FIG-002"]
  pass_condition: "所有栅格图 (PNG/JPG) DPI >= 300。"
  fix_hint: "使用高分辨率图像（>=300 DPI），或用矢量格式替代。"

- id: FIG-005
  title: 表格数量与格式
  severity: blocking
  evaluator: script
  pass_condition: "表格数量 >= min_tables (>=1)；使用 booktabs 宏包。"
  fix_hint: "添加结果对比表，使用 \\usepackage{booktabs} 的三线表格式。"

- id: FIG-006
  title: 图表质量综合评估
  severity: blocking
  evaluator: llm
  depends_on: ["FIG-001"]
  pass_condition: "图表通过 8 维度综合评估（准确性、可读性、标题完整、轴完整、误差棒说明、色盲友好、风格一致、无截断），综合评分 >= 8.0/10。AI 生成架构图（figures/ai_generated/）使用专项标准评估。"
  fix_hint: "修复评分最低的维度。确保：1) 数值与 logs/ 一致；2) 字号>=8pt；3) 有完整 caption（含实验条件）；4) 色盲友好配色；5) 误差棒说明类型（std/ste/CI）。"

- id: FIG-007
  title: 无伪造数据图表
  severity: blocking
  evaluator: llm
  depends_on: ["FIG-001", "FIG-006"]
  pass_condition: "所有图表数据来自真实实验，无伪造。图表数据与 logs/run_*.log 一致。"
  fix_hint: "确保图表基于真实数据。若有数据选取，说明选取标准。"

- id: FIG-008
  title: 图表可复现性
  severity: advisory
  evaluator: script
  depends_on: ["FIG-001"]
  pass_condition: "figures/ 下存在共享样式文件（paper_plot_style.py 或 .mplstyle），或每个图表有对应的 gen_fig_*.py 生成脚本。"
  fix_hint: "创建共享样式文件或图表生成脚本，确保图表可从数据复现。"

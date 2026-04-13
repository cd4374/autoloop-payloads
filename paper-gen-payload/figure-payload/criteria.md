- id: FIG-001
  title: 图表数量门槛
  severity: blocking
  evaluator: script
  pass_condition: "图表数量 >= payload 配置的 min_figures (NeurIPS/ICML/ICLR/Journal>=5, AAAI>=4, Short>=3, Letter>=2)"
  fix_hint: "增加图表至达标。优先展示实验结果对比、消融分析、关键可视化。"

- id: FIG-002
  title: 向量格式
  severity: blocking
  evaluator: script
  depends_on: ["FIG-001"]
  pass_condition: "所有图表为 .pdf 或 .eps 格式（函数曲线、流程图、网络结构图必须为矢量）。"
  fix_hint: "将栅格图（PNG/JPG）转换为矢量格式（PDF/EPS）。使用 matplotlib 生成 PDF 输出。"

- id: FIG-018
  title: 栅格图 DPI 达标
  severity: blocking
  evaluator: script
  depends_on: ["FIG-002"]
  pass_condition: "所有位图图像 DPI >= 300。若无法检测（工具不可用），在 figure caption 中注明原始图像分辨率。"
  fix_hint: "使用高分辨率图像（>=300 DPI），或使用矢量格式替代。"

- id: FIG-003
  title: 8 维度质量 - 内容准确性
  severity: blocking
  evaluator: llm
  depends_on: ["FIG-001"]
  pass_condition: "图表数据与论文声称数值一致，无数据错误。图表数字与实验日志一致。"
  fix_hint: "修正图表数据错误，确保图表与正文数值一致。"

- id: FIG-004
  title: 8 维度质量 - 可读性（字体）
  severity: blocking
  evaluator: llm
  depends_on: ["FIG-001"]
  pass_condition: "图中文字字号 >=8pt（印刷尺寸），图例清晰，无文字重叠。字体嵌入完整。"
  fix_hint: "增大图中文字字号，确保可读性。使用 Times New Roman 或配套字体包。"

- id: FIG-005
  title: 8 维度质量 - 无截断
  severity: blocking
  evaluator: llm
  depends_on: ["FIG-001"]
  pass_condition: "所有图表内容完整显示，无截断、无溢出。坐标轴完整展示数据范围。"
  fix_hint: "调整图表比例和数据范围，确保内容完整。"

- id: FIG-006
  title: 8 维度质量 - 色盲友好
  severity: blocking
  evaluator: llm
  depends_on: ["FIG-001"]
  pass_condition: "不使用纯红-绿对比，采用 Okabe-Ito / Viridis / Color Universal Design 色板。若需区分两类，推荐使用蓝-橙色板。"
  fix_hint: "更换配色方案。推荐色盲友好色板：Okabe-Ito、Viridis、ColorBrewer RdBu。"

- id: FIG-007
  title: 8 维度质量 - 标题完整
  severity: blocking
  evaluator: llm
  depends_on: ["FIG-001"]
  pass_condition: "每个 figure 有编号（Figure X）和完整 caption，描述实验条件（数据集、模型、参数）。"
  fix_hint: "补充 figure caption，描述实验设置和关键发现。"

- id: FIG-008
  title: 8 维度质量 - 轴完整
  severity: blocking
  evaluator: llm
  depends_on: ["FIG-001"]
  pass_condition: "坐标轴含变量名和单位（如 Accuracy(%)、Time(s)），刻度线完整，无多余空白边距。"
  fix_hint: "补充轴标签和单位。检查是否有被裁剪的轴范围。"

- id: FIG-009
  title: 8 维度质量 - 误差棒说明
  severity: blocking
  evaluator: llm
  depends_on: ["FIG-001"]
  pass_condition: "若图中含误差棒，caption 或正文中说明其含义（标准差 std / 标准误 ste / 置信区间 CI）。"
  fix_hint: "在 figure caption 中说明误差棒类型，如'误差棒表示 3 次运行的标准差'。"

- id: FIG-010
  title: 8 维度质量 - 风格一致
  severity: blocking
  evaluator: llm
  depends_on: ["FIG-001"]
  pass_condition: "同类曲线（如同一数据集上的不同方法）在全文所有图中使用相同颜色和线型。字体风格统一。"
  fix_hint: "统一全文图表配色和线型。使用统一的 matplotlib 样式文件（.mplstyle）。"

- id: FIG-011
  title: 综合评分
  severity: blocking
  evaluator: llm
  depends_on: ["FIG-003", "FIG-004", "FIG-005", "FIG-006", "FIG-007", "FIG-008", "FIG-009", "FIG-010"]
  pass_condition: "所有图表综合评分 >= 8.0/10。评分基于 8 维度加权平均（准确性30%、可读性15%、无截断10%、色盲友好10%、标题完整10%、轴完整10%、误差棒说明10%、风格一致5%）。注：AI 生成的架构图（figures/ai_generated/）应使用架构图专项审查标准（FIG-030~033）评估，不适用此 8 维度标准。"
  fix_hint: "根据评分结果，优先修复评分最低的维度。"

- id: FIG-012
  title: 图表引用与文件一致
  severity: blocking
  evaluator: script
  depends_on: ["FIG-001"]
  pass_condition: "draft.tex 中每个 \\includegraphics 引用的文件在 figures/ 目录下存在。"
  fix_hint: "补齐缺失的图表文件，或修正引用路径。"

- id: FIG-013
  title: 表格数量门槛
  severity: blocking
  evaluator: script
  pass_condition: "表格数量 >= payload 配置的 min_tables (>=1，含结果对比表）。"
  fix_hint: "增加表格。至少包含主要结果对比表。"

- id: FIG-014
  title: 表格格式规范
  severity: advisory
  evaluator: script
  depends_on: ["FIG-013"]
  pass_condition: "所有表格使用 \\begin{tabular} 环境，含列对齐、表头加粗（使用 booktabs）。"
  fix_hint: "使用 booktabs 宏包（\\usepackage{booktabs}），三线表格式。"

- id: FIG-015
  title: 无伪造数据图表
  severity: blocking
  evaluator: llm
  depends_on: ["FIG-001", "FIG-003"]
  pass_condition: "所有图表数据来自真实实验运行，无伪造或选择性展示。图表数据与 logs/run_*.log 一致。"
  fix_hint: "确保图表基于真实数据绘制。若有数据选取，说明选取标准。"

- id: FIG-016
  title: 每轮最多修复 top-3 问题
  severity: advisory
  evaluator: llm
  depends_on: ["FIG-001"]
  pass_condition: "每轮修复优先处理评分最低的 3 个图表问题，其他图表保留当前版本。"
  fix_hint: "聚焦 top-3 问题，避免一轮内修改过多图表导致回归。"

- id: FIG-017
  title: 图表与数据集/方法一致
  severity: blocking
  evaluator: llm
  depends_on: ["FIG-001"]
  pass_condition: "图表展示的方法和数据集与论文正文中描述的一致，无张冠李戴。"
  fix_hint: "核对每个图表的标题、caption 和正文描述，确保数据集和方法名称一致。"

# ═══════════════════════════════════════════════════════════════
# 数据驱动图表质量标准（来自 /paper-figure）
# ═══════════════════════════════════════════════════════════════

- id: FIG-020
  title: 共享样式配置
  severity: advisory
  evaluator: script
  depends_on: ["FIG-001"]
  pass_condition: "存在 figures/paper_plot_style.py 或 .mplstyle 文件，定义统一字体、颜色、线宽配置。"
  fix_hint: "创建共享样式配置文件，统一所有图表的字体 (Times New Roman)、颜色 (tab10/colorblind)、线宽、 DPI(300)。"

- id: FIG-021
  title: 一图表一脚本
  severity: advisory
  evaluator: script
  depends_on: ["FIG-001"]
  pass_condition: "每个数据驱动图表有对应的 gen_fig_*.py 脚本，脚本从 JSON/CSV读取数据，不硬编码数值。"
  fix_hint: "为每个图表创建独立的生成脚本，确保可复现。脚本读取数据文件而非硬编码。"

- id: FIG-022
  title: 矢量图优先
  severity: blocking
  evaluator: llm
  depends_on: ["FIG-001"]
  pass_condition: "所有函数曲线、流程图、网络结构图为 .pdf 或 .eps 格式（非.png/.jpg）。"
  fix_hint: "使用 matplotlib 的 PDF 输出：plt.savefig('fig.pdf', dpi=300, bbox_inches='tight')。"

- id: FIG-023
  title: 无图内标题
  severity: blocking
  evaluator: llm
  depends_on: ["FIG-001"]
  pass_condition: "图表内部无 plt.title 或类似标题，标题仅在 LaTeX \\caption{} 中。"
  fix_hint: "移除图中的 title，确保标题只在 LaTeX caption 中。"

# ═══════════════════════════════════════════════════════════════
# AI 生成架构图质量标准（来自 /paper-illustration）
# ═══════════════════════════════════════════════════════════════

- id: FIG-030
  title: AI 架构图迭代审查
  severity: blocking
  evaluator: llm
  depends_on: ["FIG-001"]
  pass_condition: "AI 生成的架构图（figures/ai_generated/）有审查记录，评分 >= 9/10，所有箭头方向正确。"
  fix_hint: "执行多阶段迭代：Claude 规划 → Gemini 布局 → Gemini 风格 → Paperbanana 渲染 → Claude 严格审查 (≥9 分)。"

- id: FIG-031
  title: 架构图箭头规范
  severity: blocking
  evaluator: llm
  depends_on: ["FIG-001"]
  pass_condition: "所有箭头粗细≥5px、黑色/深灰、有清晰箭头、每个箭头都有标签说明数据流。"
  fix_hint: "加粗箭头、添加标签、确保箭头方向正确指向目标模块。"

- id: FIG-032
  title: 架构图 CVPR 风格
  severity: blocking
  evaluator: llm
  depends_on: ["FIG-001"]
  pass_condition: "白色背景、无彩虹配色 (3-4 种协调色)、无重阴影/发光效果、圆角矩形 (6-10px)。"
  fix_hint: "使用学术专业配色（蓝/绿/紫/橙），添加适度渐变和圆角，移除过度装饰。"

- id: FIG-033
  title: 架构图模块内部结构
  severity: advisory
  evaluator: llm
  depends_on: ["FIG-001"]
  pass_condition: "大模块内部显示子组件结构（如 Encoder 内部的 layer），不是纯空白方块。"
  fix_hint: "在主要模块内部展示子组件层次，增强信息密度。"

# ═══════════════════════════════════════════════════════════════
# 外部审查机制（来自 /auto-review-loop）
# ═══════════════════════════════════════════════════════════════

- id: FIG-040
  title: 外部审查者评分
  severity: blocking
  evaluator: llm
  depends_on: ["FIG-011"]
  pass_condition: "外部审查者 (gpt-5.4 或同级) 对图表综合评分 >= 6/10，或 verdict 含'accept'/'ready'。"
  fix_hint: "发送完整上下文给外部审查者，根据反馈迭代修复直至通过。"

- id: FIG-041
  title: 审查迭代日志
  severity: advisory
  evaluator: script
  pass_condition: "存在 AUTO_REVIEW.md 或 figure-review-log.json，记录每轮审查评分、弱点、修复动作。"
  fix_hint: "每轮审查结果完整记录到日志文件，包含原始审查响应、修复动作、新结果。"

- id: FIG-042
  title: 每轮修复 top-3 问题
  severity: advisory
  evaluator: llm
  depends_on: ["FIG-001"]
  pass_condition: "每轮优先修复评分最低的 3 个图表问题，其他图表保留当前版本。"
  fix_hint: "聚焦 top-3 问题，避免一轮内修改过多图表导致回归。"

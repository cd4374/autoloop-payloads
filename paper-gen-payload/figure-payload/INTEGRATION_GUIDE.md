# 图片质量保障集成指南

本文档说明如何在 paper-gen-payload 的 figure-loop 中使用 01-Auto-claude-code-research-in-sleep 项目的完整图片质量保障机制。

## 前置条件

### 1. 技能可用性

确保以下技能可用（通过 skills 目录或 MCP 配置）：

| 技能 | 来源 | 用途 |
|------|------|------|
| `/paper-figure` | 01-Auto-claude-code-research-in-sleep/skills/paper-figure/SKILL.md | 数据驱动图表生成 |
| `/paper-illustration` | 01-Auto-claude-code-research-in-sleep/skills/paper-illustration/SKILL.md | AI 架构图生成 |
| `/auto-review-loop` | 01-Auto-claude-code-research-in-sleep/skills/auto-review-loop/SKILL.md | 外部审查迭代 |

### 2. 环境变量

```bash
# AI 绘图需要 Gemini API 密钥
export GEMINI_API_KEY="your-gemini-api-key"

# 外部审查需要 OpenAI API 密钥（可选，如需 gpt-5.4 审查）
export OPENAI_API_KEY="your-openai-api-key"
```

### 3. 目录结构

```
your-project/
├── .loop/                          # autoloop 运行时状态
├── paper-gen-payload/
│   └── figure-payload/
│       ├── criteria.md             # 增强后的质量标准
│       ├── eval.sh                 # 增强后的评估脚本
│       └── session.md              # 增强后的工作流文档
├── figures/
│   ├── paper_plot_style.py         # 共享样式配置
│   ├── gen_fig_*.py                # 图表生成脚本
│   ├── *.pdf                       # 生成的矢量图
│   └── ai_generated/               # AI 架构图目录
│       ├── layout_description.txt
│       ├── style_spec.txt
│       ├── figure_v*.png
│       ├── figure_final.png
│       └── review_log.json
├── PAPER_PLAN.md                   # 图表规划（来自/paper-plan）
└── AUTO_REVIEW.md                  # 审查迭代日志
```

## 使用流程

### 步骤 1：启动 figure-loop

```bash
/loop-run PAYLOAD=paper-gen-payload/figure-payload
```

### 步骤 2：数据驱动图表生成

当 `FIG-001`（图表数量）或 `FIG-021`（一图表一脚本）失败时，调用：

```
/paper-figure PAPER_PLAN.md
```

**技能行为**：
1. 读取 `PAPER_PLAN.md` 中的 Figure Plan 表
2. 识别哪些图表可以从数据生成
3. 创建共享样式文件 `figures/paper_plot_style.py`
4. 为每个数据驱动图表生成脚本 `gen_fig_*.py`
5. 运行所有脚本生成 PDF 矢量图
6. 输出 `figures/latex_includes.tex` 包含 LaTeX 引用片段

**质量保障**：
- 300 DPI 输出
- 矢量格式（PDF/EPS）
- 无图内标题（title 仅在 caption 中）
- 色盲友好配色
- 字体大小≥8pt

### 步骤 3：AI 架构图生成

当需要架构图/流程图时，调用：

```
/paper-illustration "多模态融合架构：左侧 Encoder 处理图像，右侧 Encoder 处理文本，中间 Fusion Module 进行跨模态注意力融合，输出到 Decoder"
```

**技能行为**：
1. **Claude 规划**：解析用户需求，创建详细提示词
2. **Gemini 布局优化**：优化组件位置、间距、箭头路由
3. **Gemini 风格验证**：确保 CVPR/NeurIPS 风格合规
4. **Paperbanana 渲染**：生成高质量图像
5. **Claude 严格审查**：
   - 检查每个箭头方向（错误=≤6 分）
   - 检查每个模块内容（错误=≤7 分）
   - 检查箭头可见性（≥5px 粗细）
   - 检查 CVPR 风格（白色背景、3-4 色协调）
   - 评分 1-10，**TARGET_SCORE=9**

**迭代机制**：
- 若评分 < 9，生成具体改进反馈
- 返回步骤 2 重新优化
- 最多 5 轮迭代

### 步骤 4：外部审查迭代

当 `FIG-040`（外部审查者评分）或 `FIG-011`（综合评分）失败时，调用：

```
/auto-review-loop "图表质量审查" — difficulty: medium
```

**审查者配置**：
- `REVIEWER_MODEL = gpt-5.4`
- `config: {"model_reasoning_effort": "xhigh"}`

**审查内容**：
1. 图表类型是否匹配数据
2. 对比是否公平清晰
3. 是否缺少基线或消融实验图
4. 图表与 claims 是否一致
5. 视觉设计是否符合顶会标准

**迭代流程**：
1. 审查者输出评分 + 弱点 + 修复建议
2. 若评分≥6 或 verdict 含"ready"→停止
3. 否则实施修复→重新审查→最多 4 轮

## 审查标准详解

### FIG-030：AI 架构图迭代审查（blocking）

**pass_condition**：
```
AI 生成的架构图（figures/ai_generated/）有审查记录，评分 >= 9/10，
所有箭头方向正确。
```

**检查清单**：
- [ ] `figures/ai_generated/figure_final.png` 存在
- [ ] `figures/ai_generated/review_log.json` 存在，记录评分≥9
- [ ] 所有箭头方向经 Claude 逐一验证正确
- [ ] 箭头粗细≥5px，黑色/深灰
- [ ] 每个箭头都有标签说明数据流

**CVPR 风格合规**：
- [ ] 白色背景，无花纹
- [ ] 3-4 种协调色（蓝/绿/紫/橙），非彩虹
- [ ] 无重阴影、发光效果、3D 透视
- [ ] 圆角矩形（6-10px radius）
- [ ] 适度同色系渐变，非平淡方块

### FIG-040：外部审查者评分（blocking）

**pass_condition**：
```
外部审查者 (gpt-5.4 或同级) 对图表综合评分 >= 6/10，
或 verdict 含'accept'/'ready'/'submission-ready'。
```

**审查提示词模板**：
```
Please act as a senior ML reviewer (NeurIPS/ICML level).

Review these figures for a [ICLR/NeurIPS/ICML] submission.

For each figure:
1. Is the figure type appropriate for the data being shown?
2. Is the comparison fair and clear?
3. Are all axis labels readable with units?
4. Is the color scheme accessible (colorblind-safe, print-friendly)?
5. Is the caption self-contained and informative?
6. Any missing baselines or ablations?

Score 1-10 and state clearly: is this READY for submission?
```

## 故障排除

### 问题：eval.sh 报错"缺少共享样式配置文件"

**解决**：
```bash
# 创建共享样式文件
cat > figures/paper_plot_style.py << 'EOF'
import matplotlib.pyplot as plt
import matplotlib
matplotlib.rcParams.update({
    'font.size': 10,
    'font.family': 'serif',
    'font.serif': ['Times New Roman', 'Times', 'DejaVu Serif'],
    'axes.labelsize': 10,
    'axes.titlesize': 11,
    'xtick.labelsize': 9,
    'ytick.labelsize': 9,
    'legend.fontsize': 9,
    'figure.dpi': 300,
    'savefig.dpi': 300,
    'savefig.bbox': 'tight',
    'savefig.pad_inches': 0.05,
    'axes.spines.top': False,
    'axes.spines.right': False,
})
COLORS = plt.cm.tab10.colors
EOF
```

### 问题：AI 架构图评分始终<9

**常见原因**：
1. **箭头方向错误** → 检查提示词中的连接关系描述
2. **箭头太细/颜色太浅** → 要求"thick black arrows, ≥5px stroke"
3. **配色过于花哨** → 要求"professional academic colors, no rainbow"
4. **模块内部空白** → 要求"show internal structure with sub-components"

**改进提示词示例**：
```
Create a PROFESSIONAL, VISUALLY APPEALING publication-quality academic diagram.

## Visual Style (科研风格 - Balanced Academic Style)

#### DO (应该有):
- **Subtle gradients** — 同色系淡雅渐变（如 #2563EB → #3B82F6）
- **Rounded corners** — 圆角矩形（6-10px），现代感
- **Clear visual hierarchy** — 通过大小、深浅区分层次
- **Internal structure** — 大模块内显示子组件结构
- **Consistent color coding** — 统一的 3-4 色方案

#### DON'T (不要有):
- ❌ Rainbow/multi-color gradients (彩虹渐变)
- ❌ Heavy drop shadows (重阴影)
- ❌ 3D effects / perspective (3D 效果)
- ❌ Glowing effects (发光效果)
- ❌ Excessive decorative icons (过多装饰图标)
- ❌ Plain boring rectangles (完全平淡的方块)

## CRITICAL: Arrow Requirements
1. ALL arrows must be VERY THICK — minimum 5-6px stroke width
2. ALL arrows must have CLEAR arrowheads — large, visible triangular heads
3. ALL arrows must be BLACK or DARK GRAY (#333333) — not colored
4. Label EVERY arrow with what data flows through it
5. VERIFY arrow direction — each arrow MUST point to the correct target
```

### 问题：外部审查者始终不通过

**策略**：
1. **优先修复 top-3 弱点** — 不要一轮内改太多
2. **添加消融实验图** — 这是最常见的新增实验要求
3. **补充基线对比** — 审查者常要求更多 baselines
4. **改进 caption** — 确保自包含、描述实验设置和关键发现

## 验收清单

完成集成后，验证以下项目：

- [ ] `/paper-figure` 可调用，生成 PDF 矢量图
- [ ] `/paper-illustration` 可调用，输出 figures/ai_generated/
- [ ] `AUTO_REVIEW.md` 有审查迭代记录
- [ ] 所有 blocking criteria 通过
- [ ] 综合评分≥8.0/10
- [ ] AI 架构图评分≥9/10
- [ ] 外部审查者评分≥6/10 或 verdict="ready"

## 参考资料

- 01-Auto-claude-code-research-in-sleep/skills/paper-figure/SKILL.md
- 01-Auto-claude-code-research-in-sleep/skills/paper-illustration/SKILL.md
- 01-Auto-claude-code-research-in-sleep/skills/auto-review-loop/SKILL.md
- 01-Auto-claude-code-research-in-sleep/skills/shared-references/writing-principles.md
- 01-Auto-claude-code-research-in-sleep/skills/shared-references/venue-checklists.md

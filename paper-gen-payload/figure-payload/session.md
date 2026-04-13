---
payload: "figure-loop"
version: "2.0"
max_iter: 5
---

# Figure Loop: 完整图片质量保障工作流

## 目标

集成 01-Auto-claude-code-research-in-sleep 项目的完整图片质量保障机制：
1. **/paper-figure** - 数据驱动图表生成（matplotlib 样式配置、质量检查清单、矢量图输出）
2. **/paper-illustration** - AI 生成架构图（多阶段迭代、Gemini+Paperbanana、9 分门槛）
3. **/auto-review-loop** - 外部审查者驱动的迭代改进

## 图片分类处理

| 图片类型 | 处理方式 | 质量门槛 | 负责 skill |
|----------|----------|----------|-----------|
| **数据驱动图** | /paper-figure 生成 | 8 维度≥8 分 | paper-figure + eval.sh |
| **架构图/流程图** | /paper-illustration 生成 | 审查≥9/10 | paper-illustration |
| **对比表格** | /paper-figure 生成 LaTeX | 内容准确 | paper-figure |
| **定性结果图** | 手动/实验输出 | 300 DPI | 用户提供 + eval.sh 验证 |

## 多阶段工作流

### 阶段 1：图表规划（/paper-plan 输出）

期望输入：`PAPER_PLAN.md` 中的 Figure Plan 表

```markdown
| ID | Type | Description | Data Source | Priority |
|----|------|-------------|-------------|----------|
| Fig 1 | Architecture | 系统架构图 | manual | HIGH |
| Fig 2 | Line plot | 训练曲线对比 | figures/exp_A.json | HIGH |
| Fig 3 | Bar chart | 消融实验 | figures/ablation.json | MEDIUM |
```

### 阶段 2：数据驱动图表生成（/paper-figure）

**执行步骤**：

1. **设置共享样式** (`figures/paper_plot_style.py`)：
   ```python
   import matplotlib.pyplot as plt
   import matplotlib
   matplotlib.rcParams.update({
       'font.size': 10, 'font.family': 'serif',
       'font.serif': ['Times New Roman', 'Times', 'DejaVu Serif'],
       'axes.labelsize': 10, 'axes.titlesize': 11,
       'xtick.labelsize': 9, 'ytick.labelsize': 9,
       'legend.fontsize': 9, 'figure.dpi': 300,
       'savefig.dpi': 300, 'savefig.bbox': 'tight',
       'axes.spines.top': False, 'axes.spines.right': False,
   })
   COLORS = plt.cm.tab10.colors  # 或 colorblind
   ```

2. **生成每个图表**（一图表一脚本）：
   ```bash
   for script in figures/gen_fig_*.py; do
       python "$script"
   done
   ```

3. **质量检查清单**（来自 /paper-figure Step 8）：
   - [ ] 字体大小在打印尺寸下可读（≥8pt）
   - [ ] 颜色在灰度模式下可区分
   - [ ] **图内无标题** — 标题仅在 LaTeX `\caption{}` 中
   - [ ] 图例不遮挡数据
   - [ ] 轴标签有单位
   - [ ] 图宽符合单栏 (0.48\textwidth) 或双栏 (0.95\textwidth)
   - [ ] PDF 输出是矢量图（非光栅化文字）
   - [ ] 使用色盲友好配色

### 阶段 3：AI 架构图生成（/paper-illustration）

**五阶段迭代工作流**：

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Claude (Planner) → 解析需求，创建详细提示词               │
│ 2. Gemini 3-pro (Layout) → 优化布局/间距/箭头路由            │
│ 3. Gemini 3-pro (Style) → CVPR/NeurIPS 风格合规验证          │
│ 4. Paperbanana (Render) → 高质量图像渲染                     │
│ 5. Claude (STRICT Reviewer) → 严格视觉审查 + 评分 (1-10)    │
└─────────────────────────────────────────────────────────────┘
```

**审查标准**（TARGET_SCORE = 9）：
- ✅ **每个箭头方向正确**（错误 = 自动≤6 分）
- ✅ **每个模块内容正确**（错误 = 自动≤7 分）
- ✅ **箭头可见性**（粗细≥5px，有清晰箭头）
- ✅ **CVPR 风格**（白色背景、3-4 色协调、无彩虹/重阴影）
- ✅ **视觉吸引力平衡**（适度渐变/圆角，不平淡也不花哨）

**输出目录**：
```
figures/ai_generated/
├── layout_description.txt
├── style_spec.txt
├── figure_v1.png
├── figure_v2.png
├── figure_final.png      # 评分≥9 的版本
├── latex_include.tex
└── review_log.json
```

### 阶段 4：外部审查迭代（/auto-review-loop）

**审查者模型**：`gpt-5.4`（通过 Codex MCP）

**迭代流程**：
1. 发送完整上下文（图表 + 数据 + 论文 claims）给审查者
2. 审查者输出：评分 (1-10) + 弱点列表 + 最小修复建议
3. 若评分≥6 或 verdict 含 "accept/ready" → 停止
4. 否则实施修复 → 重新审查 → 最多 4 轮

**记录到** `AUTO_REVIEW.md`：
```markdown
## Round N (timestamp)

### Assessment (Summary)
- Score: X/10
- Verdict: [ready/almost/not ready]
- Key criticisms: [...]

### Reviewer Raw Response
<details>
<summary>Click to expand full reviewer response</summary>
[完整原始审查响应]
</details>

### Actions Taken
- [实现的修复]

### Results
- [实验结果]
```

## 8 维度审查（原有机制保留）

1. **Content accuracy**: 数据与论文一致
2. **Readability**: 字体可读，图例清晰
3. **No truncation**: 无内容截断或溢出
4. **Color-blind friendly**: 色盲友好配色
5. **Title/caption completeness**: 图号 + 完整 caption
6. **Axis completeness**: 变量名、单位、刻度
7. **Error bar meaning**: caption 说明 std/ste/CI
8. **Style consistency**: 跨图颜色和线型一致

## 停止条件

满足以下任一条件时停止 loop：

1. **所有 blocking criteria 通过**（包含新增的 FIG-020~042）
2. **达到 MAX_ITER=5**
3. **外部审查者评分≥6/10 且 verdict 为 "ready" 或 "almost"**

## 状态输出

- `.paper/loop-logs/figure-round-{N}.json`: 各轮次图表评分
- `.paper/state/figure-review.json`: 外部审查记录
- `figures/ai_generated/review_log.json`: AI 图审查记录
- `AUTO_REVIEW.md`: 完整审查迭代日志

## 配置参数

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `TARGET_SCORE` | 9 | AI 架构图最低可接受评分 (1-10) |
| `MAX_ITERATIONS` | 5 | AI 图最大迭代轮数 |
| `DPI` | 300 | 栅格图输出分辨率 |
| `FORMAT` | pdf | 矢量图输出格式 |
| `COLOR_PALETTE` | tab10 | 默认 matplotlib 调色板 |
| `FONT_SIZE` | 10 | 基础字号 (pt) |
| `REVIEWER_MODEL` | gpt-5.4 | 外部审查者模型 |

---
payload: "figure-loop"
version: "2.0"
max_iter: 5
---

目标：集成图片质量保障机制，生成符合顶会标准的图表。

## 图片分类处理

| 图片类型 | 处理方式 | 质量门槛 | 负责 skill |
|----------|----------|----------|-----------|
| **数据驱动图** | /paper-figure 生成 | 8 维度≥8 分 | paper-figure + eval.sh |
| **架构图/流程图** | /paper-illustration 生成 | 审查≥9/10 | paper-illustration |
| **对比表格** | /paper-figure 生成 LaTeX | 内容准确 | paper-figure |
| **定性结果图** | 手动/实验输出 | 300 DPI | 用户提供 + eval.sh 验证 |

详细流程、matplotlib 样式配置、AI 架构图五阶段迭代、审查标准、故障排除指南，见 `figure-payload/INTEGRATION_GUIDE.md`。

## 停止条件

满足以下任一条件时停止 loop：

1. **所有 blocking criteria 通过**（FIG-001~FIG-042）
2. **达到 MAX_ITER=5**
3. **外部审查者评分≥6/10 且 verdict 为 "ready" 或 "almost"**

## 状态输出

- `.paper/loop-logs/figure-round-{N}.json`: 各轮次图表评分
- `.paper/state/figure-review.json`: 外部审查记录
- `figures/ai_generated/review_log.json`: AI 图审查记录

## Actions

### Step 1: 准备
- action: bash
  cmd: "echo 'figure-loop 准备就绪，等待基座评估 criteria...'"

---
payload: "writing-loop"
version: "1.0"
max_iter: 3
---

目标：从实验结果和想法生成完整论文内容，并按目标 venue 自动选择内置 LaTeX 模板并执行约束。

## 论文结构

1. Abstract（受模板约束）
2. Introduction（背景、动机、贡献）
3. Related Work（文献综述）
4. Method（方法描述）
5. Experiments（实验设置、结果、分析）
6. Ablation Study（消融实验，如果需要）
7. Conclusion（总结、未来工作）
8. Limitations（局限性声明）
9. References（引用列表）

## 模板选择

- 内置模板注册表：`writing-payload/templates/registry.json`
- 模板目录：`writing-payload/templates/<template_id>/`（使用官方 LaTeX 模板文件，如 `entry_tex` 指定入口）
- venue 来源优先级：
  1) writing loop 显式指定 venue（如有）
  2) `.paper/state/paper-type.json` 的 `venue`
  3) `.paper/state/paper-type.json` 的 `paper_type`
  4) 默认 `NeurIPS`

## 停止条件

- 所有必需章节完整
- 模板选择状态与 draft.tex 一致
- Abstract 字数满足模板约束
- 或达到 MAX_ITER=3

## 输入

- `.paper/input/idea.md`: 用户研究想法
- `.paper/output/experiment-results.json`: 实验结果
- `.paper/state/lit-review.json`: 文献综述信息
- `.paper/state/paper-type.json`: 目标 venue 与阈值配置

## 输出

- `.paper/output/draft.tex`: LaTeX 源文件
- `.paper/state/template-selection.json`: 模板选择状态（target_venue/selected_template_id/source_of_truth/constraints/selected_at）
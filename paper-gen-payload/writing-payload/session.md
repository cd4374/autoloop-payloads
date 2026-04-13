---
payload: "writing-loop"
version: "1.0"
max_iter: 3
---

目标：从实验结果和想法生成完整的论文内容。

## 论文结构

1. Abstract（≤250 words for long）
2. Introduction（背景、动机、贡献）
3. Related Work（文献综述）
4. Method（方法描述）
5. Experiments（实验设置、结果、分析）
6. Ablation Study（消融实验，如果需要）
7. Conclusion（总结、未来工作）
8. Limitations（局限性声明）
9. References（引用列表）

## 停止条件

- 所有必需章节完整
- Abstract 字数达标
- 或达到 MAX_ITER=3

## 输入

- `.paper/input/idea.md`: 用户研究想法
- `.paper/output/experiment-results.json`: 实验结果
- `.paper/state/lit-review.json`: 文献综述信息

## 输出

- `.paper/output/draft.tex`: LaTeX 源文件
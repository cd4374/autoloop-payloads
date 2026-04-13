---
payload: "literature-loop"
version: "1.0"
max_iter: 2
---

目标：验证文献综述的完整性和覆盖面。

## 检查项目

1. 相关工作的覆盖面
2. 关键论文的引用
3. 与现有工作的对比
4. 近五年文献的比例

## 停止条件

- 文献综述覆盖领域关键工作
- 或达到 MAX_ITER=2

## 状态输出

- `.paper/state/lit-status.json`: 文献综述状态

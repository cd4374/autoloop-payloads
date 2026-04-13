---
payload: "dataset-license-loop"
version: "1.0"
max_iter: 2
---

目标：验证数据集版本、来源与许可证约束，确保可重复与合规。

## 检查项目

1. 数据集清单存在并结构完整
2. 每个数据集都有 version 或 DOI/URL
3. 许可证信息与使用约束无冲突

## 状态输出

- `.paper/state/dataset-inventory.json`

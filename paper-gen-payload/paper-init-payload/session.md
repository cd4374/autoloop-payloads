---
payload: "paper-init"
version: "1.0"
max_iter: 3
---

目标：初始化论文项目结构，生成 draft.tex、references.bib、实验代码等基础文件。

## 输入

- 父 payload (paper-gen-payload) 的 session.md 定义配置
- .paper/input/idea.md 包含研究想法（若不存在，需用户提供）

## 流程

1. 检查目录结构完整性
2. 检查 pipeline-status.json 已初始化
3. **核心任务**：生成 draft.tex（包含完整章节内容）
4. **核心任务**：生成 references.bib（至少 5 个真实引用）
5. **核心任务**：生成实验代码 main.py
6. 生成 requirements.txt
7. 填写 reproducibility.json
8. 创建 figures 目录

## 配置继承

配置从父 payload (../session.md) 读取：
- paper_type: NeurIPS, ICML, ICLR, AAAI, Journal, Short, Letter
- domain: ai-exp, ai-theory, numerical, physics
- min_references: 引用数门槛
- min_recent_refs_pct: 近五年引用占比
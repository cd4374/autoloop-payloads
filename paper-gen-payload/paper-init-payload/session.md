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

1. **检测计算环境** — 运行 `scripts/compute-detect.sh`，生成 `.paper/state/compute-env.json`（SSH GPU → CUDA → MPS → CPU 优先级）
2. 检查目录结构完整性
3. 检查 pipeline-status.json 已初始化
4. **核心任务**：生成 draft.tex（包含完整章节内容）
5. **核心任务**：生成 references.bib（至少 5 个真实引用）
6. **核心任务**：生成实验代码 main.py
7. 生成 requirements.txt
8. 填写 reproducibility.json
9. 创建 figures 目录

## 配置继承

配置从父 payload (../session.md) 读取：
- paper_type: NeurIPS, ICML, ICLR, AAAI, Journal, Short, Letter
- domain: ai-exp, ai-theory, numerical, physics
- min_references: 引用数门槛
- min_recent_refs_pct: 近五年引用占比

## 模板初始化约定

paper-init 阶段需初始化模板选择状态，供 writing-loop 使用：
- `.paper/state/template-selection.json`（若不存在则创建）
- 字段最小集合：`target_venue`、`selected_template_id`、`source_of_truth`、`constraints`、`selected_at`
- `selected_template_id` 必须可在 `writing-payload/templates/registry.json` 解析

## Actions

### Step 1: 准备
- action: bash
  cmd: "echo 'paper-init 准备就绪，等待基座评估 criteria...'"
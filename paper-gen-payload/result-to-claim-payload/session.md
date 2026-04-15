---
payload: "result-to-claim"
version: "1.0"
max_iter: 2
---

目标：判断实验结果是否支持主张（Core Claims）。这是 exp-loop 和 writing-loop 之间的强制门控，防止在实验不支持主张的情况下继续写论文。

## 输入文件

- `.paper/input/research-contract.md`: 研究契约（含 Core Claims）
- `.paper/state/experiment-results.json` 或 `.paper/output/logs/`: 实验结果
- `.paper/state/reproducibility.json`: 可复现性信息

## 工作流程

### Step 1: 收集实验证据

从以下来源收集实验数据：
1. `.paper/output/logs/run_*.log` — 实验运行日志
2. `.paper/output/experiment-results.json` — 结构化实验结果
3. research-contract.md 中的预期 claims

### Step 2: LLM 判定

调用 LLM（gpt-5.4 xhigh）判断：
- 每个 Core Claim 是否被实验结果支持
- claim_supported: **yes** | **partial** | **no**
- what_results_support / what_results_dont_support
- missing_evidence（具体缺少哪些实验）
- suggested_claim_revision（如需修正主张措辞）
- next_experiments_needed（如需补充实验）

### Step 3: 路由决策

根据 verdict 路由：

| verdict | 动作 |
|---------|------|
| `yes` | 写入 claim_verdict.json → 进入 writing-loop |
| `partial` | 修正主张措辞，补充缺失实验 → 重新判定 |
| `no` | 将 idea 标记到 `.paper/state/idea-candidates.json` 的 killed 区域 → 切换下一候选 idea |

### Step 4: 输出

- `.paper/state/claim_verdict.json`: 主张判定结构化结果
- 更新 `.paper/state/idea-candidates.json`（如 verdict == no）

## 停止条件

- `verdict = yes` → 停止，进入 writing-loop
- `verdict = partial` 且补充实验完成 → 重新判定
- `verdict = no` 且 idea 已标记为 killed → 切换下一候选
- 或达到 MAX_ITER=2

## 约束

- 不夸大主张：结果不支持的 claim 绝不圆滑
- single positive result on one dataset ≠ general claim
- confidence: high | medium | low — 低置信度视为 inconclusive，需补充实验

## Actions

### Step 1: 审计实验完整性
- action: skill
  skill: experiment-audit
  args: "读取 .paper/output/logs/ 和 .paper/output/experiment-results.json，审计实验诚实度，输出 .paper/state/experiment-audit.json"

### Step 2: 判定主张
- action: skill
  skill: result-to-claim
  args: "读取 .paper/input/research-contract.md 和 .paper/output/experiment-results.json，判定实验结果支持哪些主张，输出 .paper/state/claim_verdict.json"

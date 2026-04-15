---
payload: "experiment-loop"
version: "1.0"
max_iter: 3
---

目标：实验设计与执行验证。

## 验证要点

1. **实验设计**: 数据集、基线、指标合理性
2. **代码正确性**: 逻辑正确，无运行时错误
3. **实验执行**: 真实运行，非伪造结果
4. **Ablation Study**: 消融实验完整性

## 停止条件

- 实验代码可独立运行
- 实验结果来自真实运行
- 独立运行次数达标
- 或达到 MAX_ITER=3

## 状态输出

- `.paper/state/experiment-status.json`: 实验状态和结果
- `.paper/loop-logs/experiment-round-{N}.json`: 各轮次实验结果

## Actions

### Step 1: 制定实验计划
- action: skill
  skill: experiment-plan
  args: "读取 .paper/input/research-contract.md，将研究方案转化为 claim 驱动的实验路线图，输出 EXPERIMENT_PLAN.md"

### Step 2: 执行实验
- action: skill
  skill: run-experiment
  args: "读取 EXPERIMENT_PLAN.md 和 .paper/state/compute-env.json，在检测到的计算环境上部署并运行实验"

### Step 3: 分析实验结果
- action: skill
  skill: analyze-results
  args: "读取 .paper/output/logs/ 中的实验日志，计算统计量并输出 .paper/output/experiment-results.json"

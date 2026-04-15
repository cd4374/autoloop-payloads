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

### Step 1: 准备
- action: bash
  cmd: "echo 'exp-loop 准备就绪，等待基座评估 criteria...'"

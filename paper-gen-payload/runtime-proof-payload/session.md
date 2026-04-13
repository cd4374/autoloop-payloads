---
payload: "runtime-proof-loop"
version: "1.0"
max_iter: 2
---

目标：验证代码在受限冒烟模式下可真实执行，避免仅 py_compile 造成的假通过。

## 检查项目

1. 冒烟命令可解析（默认 `python3 .paper/output/code/main.py`）
2. 在超时和受限参数下能成功执行
3. 运行证据文件完整（command/timeout/exit_code/timestamp）

## 约束

- 仅做受限冒烟运行，不做完整训练
- 默认超时 30 秒（可通过环境变量覆盖）

## 状态输出

- `.paper/state/runtime-proof.json`: 冒烟运行证据记录

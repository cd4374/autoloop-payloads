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

## 计算环境

- `.paper/state/compute-env.json` 记录了当前可用的计算设备（SSH GPU / CUDA / MPS / CPU）
- 冒烟运行命令应使用实际检测到的设备：
  - CUDA: `CUDA_VISIBLE_DEVICES=0 python3 ...`
  - MPS: `PYTORCH_ENABLE_MPS_FALLBACK=1 python3 ...`（代码中需设置 `device = torch.device('mps')` 或 `'cuda' if torch.cuda.is_available() else 'cpu'`）
  - SSH GPU: 通过 SSH 执行，设备信息在 compute-env.json 的 ssh_host 字段
  - CPU: 直接执行

## 约束

- 仅做受限冒烟运行，不做完整训练
- 默认超时 30 秒（可通过环境变量覆盖）

## 状态输出

- `.paper/state/runtime-proof.json`: 冒烟运行证据记录

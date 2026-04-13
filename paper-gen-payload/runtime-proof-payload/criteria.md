- id: RTP-001
  title: 冒烟命令可解析
  severity: blocking
  evaluator: script
  pass_condition: "可解析受限冒烟命令：优先使用 .paper/state/runtime-proof.json.command，否则默认 python3 .paper/output/code/main.py。"
  fix_hint: "生成或更新 .paper/state/runtime-proof.json，填入 command 与 timeout_sec；若无 command，至少保证 code/main.py 可执行。"

- id: RTP-002
  title: 受限冒烟运行通过
  severity: blocking
  evaluator: script
  depends_on: ["RTP-001"]
  pass_condition: "在 timeout 约束下执行冒烟命令，退出码为 0，且 stdout/stderr 不包含 traceback/fatal error。"
  fix_hint: "修复运行时错误并简化执行路径，确保在受限参数下可快速跑通（非完整训练）。"

- id: RTP-003
  title: 运行证据完整
  severity: blocking
  evaluator: script
  depends_on: ["RTP-001"]
  pass_condition: ".paper/state/runtime-proof.json 存在且包含 command、timeout_sec、exit_code、timestamp、stdout_excerpt 字段。"
  fix_hint: "补全 runtime-proof.json 的证据字段，记录最近一次受限冒烟运行结果。"

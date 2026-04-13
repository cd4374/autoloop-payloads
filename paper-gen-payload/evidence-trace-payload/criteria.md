- id: ETR-001
  title: 证据追溯索引存在
  severity: blocking
  evaluator: script
  pass_condition: ".paper/state/evidence-trace.json 存在且可解析，包含 claims 数组。"
  fix_hint: "生成 evidence-trace.json，列出论文关键数值 claim 与对应日志映射。"

- id: ETR-002
  title: claim 映射字段完整
  severity: blocking
  evaluator: script
  depends_on: ["ETR-001"]
  pass_condition: "claims 中每个条目包含 claim_id、value、source_log、locator 字段，且非空。"
  fix_hint: "补全每个 claim 的 source_log 和 locator（如行号、正则或片段锚点）。"

- id: ETR-003
  title: 映射日志可访问
  severity: blocking
  evaluator: script
  depends_on: ["ETR-002"]
  pass_condition: "claims 引用的 source_log 文件全部存在且非空，路径位于 .paper/output/logs/。"
  fix_hint: "修复日志路径映射或补齐缺失日志文件，避免引用无效来源。"

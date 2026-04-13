- id: ERE-001
  title: 固定外审日志路径存在
  severity: blocking
  evaluator: script
  pass_condition: ".paper/state/external-review-log.json 存在且可解析为 JSON。"
  fix_hint: "在固定路径生成 external-review-log.json，不使用替代路径。"

- id: ERE-002
  title: 外审日志 schema 完整
  severity: blocking
  evaluator: script
  depends_on: ["ERE-001"]
  pass_condition: "external-review-log.json 包含 provider、model、timestamp、verdict、raw_feedback、reviewer_role、request_id 字段，均非空。"
  fix_hint: "补全外审日志 schema，写入必需字段并保留原始评审反馈。"

- id: ERE-003
  title: 外部审查结果可接受
  severity: blocking
  evaluator: script
  depends_on: ["ERE-002"]
  pass_condition: "model 不属于本地自审占位（如 local/self/internal），且 verdict 不为 blocking。"
  fix_hint: "重新触发外部模型审查，确保使用外部 provider 并修复 blocking issues 后更新日志。"

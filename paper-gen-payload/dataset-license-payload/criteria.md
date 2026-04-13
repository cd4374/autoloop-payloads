- id: DLC-001
  title: 数据集清单结构完整
  severity: blocking
  evaluator: script
  pass_condition: ".paper/state/dataset-inventory.json 存在且 datasets 为非空数组；每项包含 name、source、license、usage_terms。"
  fix_hint: "创建/补全 dataset-inventory.json，逐个数据集填写来源、许可证与使用条款。"

- id: DLC-002
  title: 版本或引用信息完整
  severity: blocking
  evaluator: script
  depends_on: ["DLC-001"]
  pass_condition: "每个 dataset 至少包含 version 或 doi/url 字段之一，且非空。"
  fix_hint: "为每个数据集补齐 version、DOI 或 URL 证据。"

- id: DLC-003
  title: 许可证约束无冲突
  severity: blocking
  evaluator: script
  depends_on: ["DLC-001"]
  pass_condition: "不存在标记为 prohibited/incompatible 的 license_status；若 restricted=true，必须包含 compliance_note。"
  fix_hint: "替换冲突数据集或补充合规说明，确保许可证与用途兼容。"

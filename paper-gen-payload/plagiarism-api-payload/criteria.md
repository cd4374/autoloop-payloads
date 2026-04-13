- id: PLG-001
  title: 查重 API 配置存在
  severity: blocking
  evaluator: script
  pass_condition: "存在有效 API 配置：PLAGIARISM_API_PROVIDER、PLAGIARISM_API_ENDPOINT、PLAGIARISM_API_KEY（环境变量或报告内 provider/endpoint 元数据）。"
  fix_hint: "配置真实查重 API 凭据与 endpoint，禁止本地启发式替代。"

- id: PLG-002
  title: 外部查重调用证据存在
  severity: blocking
  evaluator: script
  depends_on: ["PLG-001"]
  pass_condition: ".paper/state/plagiarism-report.json 存在，且包含 report_id、checked_at、provider、status、response_hash 字段。"
  fix_hint: "触发真实外部查重调用并保存完整报告元数据。"

- id: PLG-003
  title: 相似度阈值达标
  severity: blocking
  evaluator: script
  depends_on: ["PLG-002"]
  pass_condition: "plagiarism-report.json 中 similarity_pct <= 15，且 status=success。"
  fix_hint: "根据查重报告重写高重合段落并重新调用外部 API，直至 similarity_pct <= 15。"

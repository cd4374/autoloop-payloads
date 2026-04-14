# Statistics Payload — 精简版（轻量壳）
# 核心检查已合并到 exp-payload；此 payload 仅保留数值领域专项检查

- id: STAT-001
  title: 统计报告规范
  severity: blocking
  evaluator: script
  pass_condition: "实验结果包含 mean±std 报告，无裸数值。"
  fix_hint: "补充误差报告。格式：0.85±0.03。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/exp-payload"

- id: STAT-002
  title: 统计显著性检验
  severity: blocking
  evaluator: llm
  depends_on: ["STAT-001"]
  pass_condition: "包含 p-value 或 confidence interval 或 effect size。"
  fix_hint: "添加统计显著性检验。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/exp-payload"

- id: STAT-003
  title: 无 Cherry-picking
  severity: blocking
  evaluator: llm
  depends_on: ["STAT-001"]
  pass_condition: "所有报告结果与 logs/ 一致，无选择性展示。"
  fix_hint: "确保所有结果来自完整实验记录。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/exp-payload"

- id: STAT-004
  title: Grid Independence（numerical domain）
  severity: blocking
  evaluator: script
  pass_condition: "当 paper_domain=numerical 时，至少 2 个不同网格验证。"
  fix_hint: "添加网格独立性测试。"

- id: STAT-005
  title: Convergence Order（numerical domain）
  severity: advisory
  evaluator: script
  depends_on: ["STAT-004"]
  pass_condition: "当 paper_domain=numerical 时，报告收敛阶数。"
  fix_hint: "计算并报告收敛阶数。"

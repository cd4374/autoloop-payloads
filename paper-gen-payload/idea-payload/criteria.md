- id: IDEA-001
  title: Novelty 验证
  severity: blocking
  evaluator: llm
  pass_condition: "想法与 Semantic Scholar 搜索结果的前 10 篇相关论文存在明确差异，不存在完全相同的方法"
  fix_hint: "调整研究方向，增加差异化元素"

- id: IDEA-002
  title: Feasibility 验证
  severity: blocking
  evaluator: llm
  pass_condition: "想法在现有技术条件下可实现，无不可逾越的技术障碍，预计工作量合理"
  fix_hint: "调整方法复杂度，选择更可行的实现路径"

- id: IDEA-003
  title: Impact 验证
  severity: blocking
  evaluator: llm
  pass_condition: "想法对目标领域有明确贡献，预期结果有学术或应用价值"
  fix_hint: "明确应用场景，加强理论贡献"

- id: IDEA-004
  title: 综合评分
  severity: blocking
  evaluator: llm
  depends_on: ["IDEA-001", "IDEA-002", "IDEA-003"]
  pass_condition: "novelty × feasibility × impact 综合评分 >=80"
  fix_hint: "优化想法以提升综合评分"
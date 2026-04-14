- id: CITE-001
  title: Layer 1 字段完整性
  severity: blocking
  evaluator: script
  pass_condition: "所有 BibTeX 条目包含 author、title、year 字段"
  fix_hint: "补充缺失字段。对缺少必需字段的条目，查询原文献或移除该条目。"

- id: CITE-002
  title: Layer 2 DOI/arXiv URL 可访问性
  severity: blocking
  evaluator: script
  depends_on: ["CITE-001"]
  pass_condition: "所有有 DOI 或 arXiv ID 的条目，其 URL 必须可访问（HTTP 200/301/302）。允许 ≤20% 的失败率作为 graceful degradation。"
  fix_hint: "移除不可访问的 DOI/arXiv URL，或替换为有效的替代引用。"

- id: CITE-003
  title: Layer 3 CrossRef 一致性验证
  severity: blocking
  evaluator: script
  depends_on: ["CITE-002"]
  pass_condition: "通过 CrossRef API (https://api.crossref.org/works/{doi}) 验证 DOI，比对返回的 title 和 year 与 BibTeX 条目。title 相似度 >=0.7（使用 difflib.SequenceMatcher）且 year 一致。"
  fix_hint: "修正与 CrossRef 不一致的 DOI 条目（title 或 year 偏差过大）。移除错误的 DOI，或修正 BibTeX 条目以匹配 CrossRef 数据。"

- id: CITE-004
  title: 引用数量达标
  severity: blocking
  evaluator: script
  pass_condition: "references.bib 条目数 >= payload 配置的 min_references (NeurIPS/ICML/ICLR>=30, AAAI>=25, Journal>=40, Short>=15, Letter>=10)"
  fix_hint: "补充引用至达标。优先补充近五年文献和领域关键论文。"

- id: CITE-005
  title: 近五年占比达标
  severity: blocking
  evaluator: script
  pass_condition: "近五年引用占比 >= payload 配置的 min_recent_refs_pct (ai-exp>=30%, ai-theory>=15%, physics/numerical>=20%)，或已豁免。"
  fix_hint: "补充近期文献引用。ai-theory 类可申请豁免并说明理论基础性质。"

- id: CITE-006
  title: Layer 4 语义关联（LLM 评估）
  severity: advisory
  evaluator: llm
  depends_on: ["CITE-003"]
  pass_condition: "每个引用与其支持的 claim 在语义上相关。BibTeX 条目与正文引用位置匹配。"
  fix_hint: "调整引用位置或更换不相关的引用。"

- id: CITE-007
  title: BibTeX 格式一致
  severity: blocking
  evaluator: script
  depends_on: ["CITE-001"]
  pass_condition: "references.bib 全文使用同一 BibTeX style（如 IEEEtran / NeurIPS / APS），无混用格式。"
  fix_hint: "统一 BibTeX 格式，使用同一参考文献样式。"

- id: CITE-008
  title: 引用正文一致性
  severity: blocking
  evaluator: script
  depends_on: ["CITE-001"]
  pass_condition: "references.bib 中每个条目在 draft.tex 中有 \\cite{} 使用。无未使用的孤立条目。"
  fix_hint: "清理未使用引用或补充正文引用。"

- id: CITE-009
  title: citation card 与 bib 映射完整
  severity: blocking
  evaluator: script
  depends_on: ["CITE-001"]
  pass_condition: "`.paper/output/citation-cards/*.md` 中每个卡片都能映射到 references.bib 的条目（通过 bib key、DOI 或 arXiv 任一）。"
  fix_hint: "在 citation card 中补充 `Bibliography` 字段，包含 bib key/DOI/arXiv 至少一项。"

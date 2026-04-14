# Citation Payload — 精简版（6 criteria）
# 保留核心引用质量检查，LLM 处理语义关联

- id: CITE-001
  title: Layer 1 字段完整性
  severity: blocking
  evaluator: script
  pass_condition: "所有 BibTeX 条目包含 author、title、year 字段。"
  fix_hint: "补充缺失字段。查询原文献或移除缺少必需字段的条目。"

- id: CITE-002
  title: DOI/arXiv URL 可访问性
  severity: blocking
  evaluator: script
  depends_on: ["CITE-001"]
  pass_condition: "所有有 DOI 或 arXiv ID 的条目，其 URL 必须可访问（HTTP 200/301/302）。允许 ≤20% 失败率作为 graceful degradation。"
  fix_hint: "移除不可访问的 DOI/arXiv URL，或替换为有效的替代引用。"

- id: CITE-003
  title: CrossRef 一致性验证
  severity: blocking
  evaluator: script
  depends_on: ["CITE-002"]
  pass_condition: "通过 CrossRef API 验证 DOI，title 相似度 >=0.7（difflib.SequenceMatcher），year 一致。"
  fix_hint: "修正与 CrossRef 不一致的 DOI 条目，或移除错误 DOI。"

- id: CITE-004
  title: 引用数量达标
  severity: blocking
  evaluator: script
  pass_condition: "references.bib 条目数 >= paper-type.json 中 derived_thresholds.min_references（默认：NeurIPS/ICML/ICLR>=30, AAAI>=25, Journal>=40, Short>=15）。"
  fix_hint: "补充引用至达标。优先补充近五年文献和领域关键论文。"

- id: CITE-005
  title: 引用正文一致性
  severity: blocking
  evaluator: script
  depends_on: ["CITE-001"]
  pass_condition: "references.bib 中每个条目在 draft.tex 中有 \\cite{} 使用。无未使用的孤立条目。"
  fix_hint: "清理未使用引用或补充正文引用。"

- id: CITE-006
  title: BibTeX 格式一致
  severity: blocking
  evaluator: script
  depends_on: ["CITE-001"]
  pass_condition: "references.bib 全文使用同一 BibTeX style（如 IEEEtran/NeurIPS/APS），无混用格式。"
  fix_hint: "统一 BibTeX 格式，使用同一参考文献样式。"

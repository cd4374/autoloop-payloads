- id: LIT-001
  title: Related Work 章节存在
  severity: blocking
  evaluator: script
  pass_condition: "draft.tex 包含 Related Work 或 Background 或 Literature Review 章节（通过关键词检测）。"
  fix_hint: "添加 Related Work 章节，综述相关研究工作。"

- id: LIT-002
  title: 关键论文覆盖
  severity: blocking
  evaluator: llm
  depends_on: ["LIT-001"]
  pass_condition: "领域关键论文（根据 Semantic Scholar 搜索结果前 20 篇相关论文）已被引用，且与本文工作形成对比。"
  fix_hint: "补充相关领域关键论文引用。搜索相关工作并引用。"

- id: LIT-003
  title: 与现有工作对比
  severity: blocking
  evaluator: llm
  depends_on: ["LIT-002"]
  pass_condition: "Related Work 包含与现有工作的对比分析，说明本文与前人工作的差异和贡献。"
  fix_hint: "在 Related Work 中添加与现有方法的对比分析。明确说明本文的创新点。"

- id: LIT-004
  title: 近五年文献比例
  severity: advisory
  evaluator: script
  depends_on: ["LIT-001"]
  pass_condition: "近五年文献占比 >= payload 配置的 min_recent_refs_pct (ai-exp>=30%, ai-theory>=15%, physics/numerical>=20%)"
  fix_hint: "补充近期文献引用。搜索近五年相关工作。"

- id: LIT-005
  title: 领域旗舰论文引用
  severity: advisory
  evaluator: script
  depends_on: ["LIT-001"]
  pass_condition: "draft.tex 中引用了至少 5 处领域旗舰期刊/会议论文（NeurIPS/ICML/ICLR/Nature ML/arxiv）。"
  fix_hint: "补充领域旗舰会议论文引用。优先引用 NeurIPS/ICML/ICLR 等顶会论文。"

- id: LIT-006
  title: Novelty 与现有方法区分
  severity: blocking
  evaluator: llm
  depends_on: ["LIT-003"]
  pass_condition: "Related Work 中明确说明本文方法与现有工作的差异，使用'we differ from'/'in contrast to'/'different from'等对比语言。"
  fix_hint: "在 Related Work 中添加 novelty comparison，明确与现有工作的区别。"

- id: LIT-007
  title: 文献综述无幻觉引用
  severity: blocking
  evaluator: llm
  depends_on: ["LIT-002"]
  pass_condition: "Related Work 中引用的每篇论文其 title/author/year 可在 references.bib 和实际文献中验证一致。"
  fix_hint: "验证所有引用条目的准确性，移除幻觉引用。"

- id: LIT-008
  title: 文献综述完整性（LLM 语义评估）
  severity: advisory
  evaluator: llm
  depends_on: ["LIT-001", "LIT-002", "LIT-003"]
  pass_condition: "Related Work 涵盖问题定义、方法分类、代表性工作、研究空白等方面，无重大遗漏。"
  fix_hint: "扩展 Related Work，确保覆盖该领域主要研究方向和代表工作。"

- id: LIT-009
  title: 文献语料目录存在
  severity: blocking
  evaluator: script
  pass_condition: "`.paper/input/papers/` 存在，且至少包含一篇文献（支持 papers/ 根目录、downloaded/、manual/）。"
  fix_hint: "创建 `.paper/input/papers/` 并放入文献文件（pdf/txt/md 均可）。"

- id: LIT-010
  title: 文献语料索引完整
  severity: blocking
  evaluator: script
  depends_on: ["LIT-009"]
  pass_condition: "`.paper/state/lit-corpus-index.json` 存在且包含 `papers[]`，每项至少含 `paper_id/source_type/path`。"
  fix_hint: "生成 lit-corpus-index.json，补齐 papers 列表和关键字段。"

- id: LIT-011
  title: Markdown citation cards 产物存在
  severity: blocking
  evaluator: script
  depends_on: ["LIT-010"]
  pass_condition: "`.paper/output/citation-cards/` 存在，且至少 1 个 `.md` 卡片文件。"
  fix_hint: "在 citation-cards 目录生成 Markdown 引文卡片。"

- id: LIT-012
  title: citation cards 格式约束
  severity: blocking
  evaluator: script
  depends_on: ["LIT-011"]
  pass_condition: "`.paper/output/citation-cards/` 下仅允许 `.md` 文件，不允许 json/yaml/txt 等其他格式。"
  fix_hint: "将 citation cards 统一转换为 `.md`，删除或迁移非 md 文件。"

# =============================================================================
# paper-gen-payload criteria — 精简版
# =============================================================================
# 设计原则：
#   - P0 blocking criteria: 必须全部通过才能交付（6 个）
#   - Quality advisory criteria: 指导改进方向，不阻断迭代（6 个）
#   - 子 payload 拥有全部质量标准；主 payload 只管 P0 门控 + 关键质量产出
#   - 去掉所有"转发层"criteria（触发子 payload 然后检查文件存在）
#   - 主 payload 通过 .paper/state/*.json 文件感知子 payload 完成状态
# =============================================================================

# ---------------------------------------------------------------------------
# PG-G*: P0 Blocking — All must pass for delivery
# ---------------------------------------------------------------------------

- id: PG-G01
  title: 论文基础文件已生成
  severity: blocking
  evaluator: script
  pass_condition: ".paper/output/draft.tex 存在 (>100字节，含 LaTeX 结构)、references.bib 存在 (≥5 条目)、code/main.py 存在 (>10行)。由 paper-init-payload 生成。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/paper-init-payload"

- id: PG-G02
  title: LaTeX 编译成功
  severity: blocking
  evaluator: script
  depends_on: ["PG-G01"]
  pass_condition: "paper.pdf 存在且 pdfinfo 可读取页数。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/writing-payload"

- id: PG-G03
  title: P0 外部查重通过
  severity: blocking
  evaluator: script
  depends_on: ["PG-G02"]
  pass_condition: ".paper/state/plagiarism-report.json 存在，status='success'，similarity_pct ≤ 15。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/plagiarism-api-payload"

- id: PG-G04
  title: P0 运行时冒烟验证
  severity: blocking
  evaluator: script
  depends_on: ["PG-G01"]
  pass_condition: ".paper/state/runtime-proof.json 存在，exit_code=0，command/timeout_sec/timestamp/stdout_excerpt 字段完整。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/runtime-proof-payload"

- id: PG-G05
  title: P0 外部审查通过
  severity: blocking
  evaluator: script
  depends_on: ["PG-G01", "PG-G02"]
  pass_condition: ".paper/state/external-review-log.json 存在，字段完整（provider/model/timestamp/verdict/raw_feedback/reviewer_role/request_id），verdict ≠ 'blocking'。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/external-review-enforcer-payload"

- id: PG-G06
  title: P0 证据链可追溯
  severity: blocking
  evaluator: script
  depends_on: ["PG-G04"]
  pass_condition: ".paper/state/evidence-trace.json 存在，每个 claim 的 source_log 文件存在且非空。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/evidence-trace-payload"

# ---------------------------------------------------------------------------
# PG-Q*: Quality Advisory — Guide improvement, don't block delivery
# ---------------------------------------------------------------------------

- id: PG-Q01
  title: 论文写作质量
  severity: advisory
  evaluator: llm
  depends_on: ["PG-G01"]
  pass_condition: "draft.tex 包含 Abstract/Introduction/Method/Experiments/Conclusion；无明显逻辑错误；语言连贯；格式规范。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/writing-payload"

- id: PG-Q02
  title: 引用质量
  severity: advisory
  evaluator: script
  depends_on: ["PG-G01"]
  pass_condition: "references.bib 条目数 ≥ 配置阈值；近五年引用占比 ≥ min_recent_refs_pct%；所有条目在正文中被使用。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/lit-payload"

- id: PG-Q03
  title: 实验可复现性
  severity: advisory
  evaluator: script
  depends_on: ["PG-G01"]
  pass_condition: "reproducibility.json 包含 hardware/software/hyperparameters/dataset/preprocessing；code/main.py 包含随机种子设置；logs/ 目录存在。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/exp-payload"

- id: PG-Q04
  title: 图表质量
  severity: advisory
  evaluator: script
  depends_on: ["PG-G01"]
  pass_condition: "figures/ 目录存在；所有图表为 .pdf/.eps 格式（无栅格图）；图表数量 ≥ min_figures。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/figure-payload"

- id: PG-Q05
  title: 数据集合规
  severity: advisory
  evaluator: script
  depends_on: ["PG-Q03"]
  pass_condition: ".paper/state/dataset-inventory.json 存在且包含 name/source/license/usage_terms；无许可证冲突。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/dataset-license-payload"

- id: PG-Q06
  title: Vx 交付包完整
  severity: advisory
  evaluator: script
  depends_on: ["PG-G03", "PG-G04", "PG-G05", "PG-G06"]
  pass_condition: "项目根目录存在最新 Vx/ 目录（Vx/code/ + Vx/latex/ + Vx/else-supports/）；.paper/state/release-package.json 存在且字段完整。"
  fix_skill: loop-run
  fix_skill_args: "PAYLOAD=paper-gen-payload/file-complete-payload"

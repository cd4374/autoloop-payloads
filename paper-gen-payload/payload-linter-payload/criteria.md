- id: LNT-001
  title: payload 三件套完整
  severity: blocking
  evaluator: script
  pass_condition: "paper-gen-payload 下每个 *-payload 目录都包含 criteria.md、eval.sh、session.md。"
  fix_hint: "为缺失目录补齐三件套文件，确保可被 loop-run 驱动。"

- id: LNT-002
  title: criteria 依赖图合法
  severity: blocking
  evaluator: script
  depends_on: ["LNT-001"]
  pass_condition: "所有 criteria.md 的 id 唯一且格式合法，depends_on 引用存在且无环。"
  fix_hint: "修复重复/非法 id，补齐悬空 depends_on，消除依赖环。"

- id: LNT-003
  title: script 输出与 criteria 对齐
  severity: blocking
  evaluator: script
  depends_on: ["LNT-001"]
  pass_condition: "每个 payload 的 eval.sh 输出 ID 集合与该 payload 中 evaluator=script 的 criteria ID 集合完全一致。"
  fix_hint: "修复 eval.sh 输出集合，避免缺漏或多报 script criteria。"

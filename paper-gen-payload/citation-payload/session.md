---
payload: "citation-loop"
version: "1.0"
max_iter: 3
---

目标：四层引用验证，移除幻觉引用，补充缺失引用。

## 四层验证

1. **Layer 1 字段完整性**: author/title/year/venue
2. **Layer 2 存在性验证**: DOI 或 arXiv URL 可访问性验证
3. **Layer 3 交叉验证**: CrossRef API 交叉检查（title/year 一致性验证）
4. **Layer 4 语义关联**: 引用与 claim 的相关性（LLM 评估）

## 停止条件

- 所有引用通过 Layer 1-3
- verified_count >= payload 配置的 min_references
- recent_refs_pct >= payload 配置的 min_recent_refs_pct (unless exempted)
- 或达到 MAX_ITER=3

## 状态输出

- `.paper/state/citation-status.json`: 验证状态、verified_count、hallucinated_count
- `.paper/loop-logs/citation-round-{N}.json`: 各轮次验证结果
- `.paper/output/citation-cards/`: 引文卡片目录（仅 Markdown）

## Actions

### Step 1: arXiv 引用存在性验证
- action: skill
  skill: arxiv
  args: "读取 .paper/output/references.bib，对每个引用验证 arXiv URL 可访问性，输出 .paper/loop-logs/citation-round-{N}.json"

### Step 2: IEEE/ACM 引用存在性验证
- action: skill
  skill: semantic-scholar
  args: "读取 .paper/output/references.bib，对每个正式发表论文验证 DOI/URL 可访问性"

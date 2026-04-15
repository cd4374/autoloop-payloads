# Research Contract: [Idea Name]

> **聚焦工作文档。** 从 IDEA_REPORT.md 和 novelty-report.json 提取当前活跃 idea，独立维护，避免 context 污染。
>
> **用途**：会话恢复时，LLM 只读此文件——不读完整 idea 池。

---

## Selected Idea

- **Description**: [One-paragraph summary of the idea]
- **Source**: idea.md, novelty-report.json
- **Selection rationale**: [Why this idea — novelty score, feasibility, estimated impact]

## Core Claims

1. **[Main claim]** — [what the method achieves]
2. **[Supporting claim]** — [why it works / when it works best]
3. **[Optional: scope/limitation claim]**

## Method Summary

[2-3 paragraphs: How the method works. Enough detail that a new agent can understand and implement independently without reading the full codebase.]

## Experiment Design

- **Datasets**: [Which datasets, which splits]
- **Baselines**: [What you compare against]
- **Metrics**: [Primary and secondary metrics]
- **Key hyperparameters**: [The ones that matter most]
- **Compute budget**: [GPU hours, hardware]

## Baselines

| Method | Dataset | Metric | Score | Source |
|--------|---------|--------|-------|--------|
| [Baseline A] | [Dataset] | [Metric] | [Number] | [Paper / reproduced] |
| [Baseline B] | [Dataset] | [Metric] | [Number] | [Paper / reproduced] |

## Current Results

> Updated as experiments complete. Start empty, fill in as you go.

| Method | Dataset | Metric | Score | Notes |
|--------|---------|--------|-------|-------|
| [Your method] | [Dataset] | [Metric] | [Number] | [e.g., "3 seeds, mean±std"] |

## Key Decisions

- [Decision 1: Why approach X over Y — with reasoning]
- [Decision 2: Why this hyperparameter / architecture choice]
- [Known limitations / risks and how you plan to handle them]

## Status

- [ ] Novelty check passed (score >= 5)
- [ ] Research contract generated
- [ ] Literature review complete
- [ ] Baseline reproduced
- [ ] Main method implemented
- [ ] Representative dataset results
- [ ] Full dataset results
- [ ] Ablation studies
- [ ] Claim verification (result-to-claim: yes)
- [ ] Paper draft

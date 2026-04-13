---
payload: "plagiarism-api-loop"
version: "1.0"
max_iter: 2
---

目标：通过真实外部查重 API 验证相似度，不允许本地启发式替代通过。

## 检查项目

1. API 配置存在（provider/endpoint/key）
2. 真实 API 调用结果证据存在（report_id/checked_at/response_hash）
3. similarity_pct <= 15

## 硬约束

- 无 API 配置、无外部调用证据、调用失败 -> 直接 FAIL
- 不允许“本地降级通过”

## 状态输出

- `.paper/state/plagiarism-report.json`

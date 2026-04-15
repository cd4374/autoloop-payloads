---
payload: "paper-gen"
version: "1.1"
max_iter: 5
paper_type: "NeurIPS"
domain: "ai-exp"
---

目标：从研究想法自动生成一篇高质量、可验证、可重复、真实的学术论文。

## 输入

payload 目录内的 `.paper/input/idea.md` 定义研究想法。若不存在，需用户提供。

## 配置

| 参数 | 值 | 说明 |
|------|-----|------|
| paper_type | NeurIPS | 会议/期刊类型 |
| domain | ai-exp | 论文领域 |
| min_references | 30 | 引用数门槛 |
| min_figures | 5 | 图表数门槛 |
| min_tables | 1 | 表格数门槛 |
| page_limit | 9 | 页数限制 |
| abstract_max_words | 250 | Abstract 字数上限 |
| min_experiment_runs | 3 | 独立运行次数 |
| require_ablation | true | 是否需要 Ablation Study |
| min_recent_refs_pct | 30 | 近五年引用占比 (%) |

## 计算环境配置

计算环境在 `.paper/state/compute-env.json` 中记录，优先级顺序：

1. **SSH 远程 GPU** — 通过 `COMPUTE_SSH_HOST` / `COMPUTE_SSH_KEY` 配置，`nvidia-smi` 远程执行
2. **本地 CUDA GPU** — 检测 `nvidia-smi` 或 `torch.cuda.is_available()`
3. **本地 MPS** — Apple Silicon M系列芯片，`torch.backends.mps.is_available()`
4. **本地 CPU** — 无可用 GPU 时的最终回退

### 环境变量（优先级高于配置）

| 变量 | 默认值 | 说明 |
|------|--------|------|
| COMPUTE_SSH_HOST | "" | SSH 远程 GPU 主机 (user@gpu-server) |
| COMPUTE_SSH_KEY | "" | SSH 私钥路径 |
| COMPUTE_SSH_ENABLED | true | 启用 SSH GPU 检测 |
| COMPUTE_CUDA_ENABLED | true | 启用本地 CUDA 检测 |
| COMPUTE_MPS_ENABLED | true | 启用本地 MPS 检测 |
| COMPUTE_CONDA_ENV | scf-paper | Conda 环境名称（不存在时自动创建） |
| COMPUTE_TIMEOUT | 10 | SSH 连接超时秒数 |

### 状态文件

- `.paper/state/compute-env.json`: 检测结果（device/gpu_name/cuda_version 等字段）
- `.paper/state/compute-config.json`（可选）: 用户持久化配置，字段同环境变量（snake_case）

## 子 Loop

通过 `fix_skill: loop-run` 触发子 loop：

1. **idea-loop** (`idea-payload/`): MAX_ITER=3，验证 idea 清晰性
   - 内嵌 novelty-check-payload (NC-001~004): 新颖性核查，新评分体系
   - 内嵌 research-contract-payload (RC-001~006): 研究契约生成
2. **lit-loop** (`lit-payload/`): MAX_ITER=2，文献综述完整性
3. **exp-loop** (`exp-payload/`): MAX_ITER=3，实验设计与执行
4. **result-to-claim-loop** (`result-to-claim-payload/`): MAX_ITER=2，实验→主张判定门控
5. **writing-loop** (`writing-payload/`): MAX_ITER=3，论文写作
6. **citation-loop** (`citation-payload/`): MAX_ITER=3，四层引用验证
7. **figure-loop** (`figure-payload/`): MAX_ITER=5，图表质量 8 维度
8. **review-loop** (`review-payload/`): MAX_ITER=4，跨模型审查
9. **runtime-proof-loop** (`runtime-proof-payload/`): 受限冒烟运行验证（P0 强门控）
10. **external-review-enforcer-loop** (`external-review-enforcer-payload/`): 固定外审证据 schema（P0 强门控）
11. **evidence-trace-loop** (`evidence-trace-payload/`): 数值到日志追溯链验证（P0 强门控）
12. **plagiarism-api-loop** (`plagiarism-api-payload/`): 真实外部查重 API 验证（P0 强门控）
13. **dataset-license-loop** (`dataset-license-payload/`): 数据集版本与许可合规（P1 补强）
14. **payload-linter-loop** (`payload-linter-payload/`): payload 协议 lint（P1 补强）

## 状态文件

- `.loop/results.jsonl`: 每轮评估结果
- `.loop/session.md`: session 上下文
- `.paper/output/`: 生成的论文文件
- `.paper/state/pipeline-status.json`: 主流水线状态（可选，用于追踪进度）
- `.paper/state/lit-corpus-index.json`: 文献语料索引（downloaded/manual/path/title/doi/arxiv）
- `.paper/state/template-selection.json`: venue 模板选择状态
- `.paper/state/release-package.json`: 交付包版本记录与证据引用
- `.paper/state/idea-candidates.json`: 候选 idea 池状态（含 active、candidates、killed）
- `.paper/state/novelty-report.json`: 新颖性报告
- `.paper/state/claim_verdict.json`: 实验→主张判定结果

## 新增产物目录契约

- `.paper/input/papers/`: 文献语料根目录
  - `.paper/input/papers/downloaded/`: 自动检索下载文献
  - `.paper/input/papers/manual/`: 用户手工补充文献
- `.paper/output/citation-cards/`: 引文卡片目录（仅 Markdown）
- `.paper/input/research-contract.md`: 研究契约锚点文档
- `Vx/`（项目根目录）: 版本化交付包（`code/`、`latex/`、`else-supports/`）

## 约束

- 不伪造实验数据
- 不捏造引用
- reviewer agents 只读不写
- 所有数字来自真实运行
- result-to-claim verdict == no 时，必须将 idea 标记到 killed 区域并切换候选

## Actions

### Step 1: 判断是否完成
- action: if
  condition: "json_path:.loop:results.jsonl:last/blocking_fail eq 0"
  then:
    - action: write
      file: .loop/done
      content: "完成\n"
  else:
    - action: skill
      skill: loop-run
      args: "PAYLOAD=. RESUME"

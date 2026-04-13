- id: EXP-001
  title: 实验代码可运行
  severity: blocking
  evaluator: script
  pass_condition: "code/main.py 可执行，无语法错误（python3 -m py_compile 通过）。"
  fix_hint: "修复代码语法错误，确保可运行。"

- id: EXP-002
  title: 实验结果来自真实运行
  severity: blocking
  evaluator: llm
  depends_on: ["EXP-001", "EXP-003"]
  pass_condition: "所有数字来自 code/main.py 输出，可从 .paper/output/logs/run_*.log 追溯。无捏造数据。"
  fix_hint: "运行实验获取真实结果，确保 logs/ 目录下有 run_*.log 文件。"

- id: EXP-003
  title: 独立运行次数达标
  severity: blocking
  evaluator: script
  depends_on: ["EXP-001"]
  pass_condition: ".paper/output/logs/ 目录下至少有 min_experiment_runs 个 run_*.log 文件 (>= payload 配置的 min_experiment_runs，默认 ai-exp>=3)。"
  fix_hint: "增加独立运行次数至达标。每次运行生成独立的 run_N.log 文件。"

- id: EXP-004
  title: Ablation Study 完整（需消融时）
  severity: blocking
  evaluator: llm
  depends_on: ["EXP-001", "EXP-003"]
  pass_condition: "当 payload 配置的 require_ablation=true 时，消融实验覆盖所有关键组件。"
  fix_hint: "设计消融实验，逐一移除关键组件，分析贡献。"

- id: EXP-005
  title: 数据集真实可用
  severity: blocking
  evaluator: script
  depends_on: ["EXP-001"]
  pass_condition: "实验使用真实数据集加载（torchvision/tensorflow_datasets/sklearn.datasets/huggingface/datasets）或可下载数据，非随机生成。"
  fix_hint: "替换为真实数据集，确保数据集有引用（version/DOI）。"

- id: EXP-006
  title: 基线选择合理
  severity: advisory
  evaluator: llm
  pass_condition: "比较方法覆盖领域标准基线，论文中有明确对比。"
  fix_hint: "补充标准基线方法。"

- id: EXP-007
  title: 随机种子固定
  severity: blocking
  evaluator: script
  depends_on: ["EXP-001"]
  pass_condition: "code/main.py 包含随机种子固定（torch.manual_seed/np.random.seed/random.seed 等）。"
  fix_hint: "在代码开头添加随机种子设置。"

- id: EXP-008
  title: 超参数完整列出
  severity: blocking
  evaluator: llm
  depends_on: ["EXP-001"]
  pass_condition: "所有关键超参数（learning_rate/batch_size/weight_decay/optimizer/epoch）在代码中有明确设置，论文中有说明。"
  fix_hint: "补充完整超参数列表。"

- id: EXP-009
  title: 实验结果可追溯
  severity: blocking
  evaluator: script
  depends_on: ["EXP-003"]
  pass_condition: "logs 目录下每个 run_*.log 对应一次完整实验运行，包含超参数和最终指标。"
  fix_hint: "运行实验并保存完整日志。确保每个 run_*.log 包含指标数值。"

- id: EXP-010
  title: GPU 加速信息（如适用）
  severity: advisory
  evaluator: script
  depends_on: ["EXP-001"]
  pass_condition: "若使用 GPU，在代码和 reproducibility.json 中记录 GPU 型号和 CUDA 版本。"
  fix_hint: "在代码中添加 CUDA 可用性检测，记录 GPU 信息到 reproducibility.json。"

- id: EXP-011
  title: 物理实验误差分析（physics domain）
  severity: blocking
  evaluator: llm
  depends_on: ["EXP-001"]
  pass_condition: "当 paper_domain=physics 时，论文必须包含误差分析章节，明确区分系统误差（systematic error）和随机误差（random error）。"
  fix_hint: "添加误差分析章节：1) 列出所有可能的误差来源；2) 区分系统误差和随机误差；3) 说明每种误差的估计方法。"

- id: EXP-012
  title: 不确定度传递（physics domain）
  severity: blocking
  evaluator: script
  depends_on: ["EXP-011"]
  pass_condition: "当 paper_domain=physics 时，实验结果包含不确定度（uncertainty）计算和传递公式。"
  fix_hint: "在 Method 章节添加不确定度计算方法，包括误差传递公式和置信区间说明。"

- id: EXP-013
  title: 设备精度与校准（physics domain）
  severity: blocking
  evaluator: script
  depends_on: ["EXP-001"]
  pass_condition: "当 paper_domain=physics 时，论文列出主要实验设备的精度指标和校准状态。"
  fix_hint: "在 Experiments 章节添加设备说明：1) 测量仪器型号和精度；2) 校准方法和日期；3) 分辨率限制。"

- id: STAT-001
  title: Mean±Std 报告（全覆盖）
  severity: blocking
  evaluator: script
  pass_condition: "所有实验结果包含 mean±std 报告，不存在无误差报告的裸数值。表格中每个含数值的结果单元必须包含 ±std，正文中的结果描述也必须附带误差指标。"
  fix_hint: "补充误差报告。所有定量结果必须附带标准差或标准误。表格单元中的每个数值列必须有对应的 ±std 值。"

- id: STAT-002
  title: 统计显著性检验
  severity: blocking
  evaluator: llm
  depends_on: ["STAT-001"]
  pass_condition: "实验结果包含统计显著性检验（p-value 或 confidence interval 或 effect size）。"
  fix_hint: "添加统计显著性检验。使用 t-test、Welch's t-test 或报告置信区间。"

- id: STAT-003
  title: 无 Cherry-picking（信号词检测）
  severity: blocking
  evaluator: script
  pass_condition: "draft.tex 不包含 cherry-picking 信号词（如'best result'、'selectively reported'、'only show'等）。"
  fix_hint: "报告完整实验结果，移除或重新表述疑似 cherry-picking 的描述。"

- id: STAT-012
  title: 无 Cherry-picking（语义验证）
  severity: blocking
  evaluator: llm
  depends_on: ["STAT-003"]
  pass_condition: "所有报告结果与实验日志一致，无选择性展示。报告中使用的数字应可从 logs/ 目录的 run_*.log 中追溯。"
  fix_hint: "确保所有结果来自完整实验记录，补充缺失实验。"

- id: STAT-004
  title: Grid Independence（numerical）
  severity: blocking
  evaluator: script
  pass_condition: "当 paper_domain=numerical 时，包含至少 2 个不同网格的验证结果。"
  fix_hint: "在多个网格上运行数值实验，报告网格无关性验证。"

- id: STAT-005
  title: Convergence Order（numerical）
  severity: blocking
  evaluator: script
  pass_condition: "当 paper_domain=numerical 时，报告收敛阶数（first order、second order 等）。"
  fix_hint: "计算并报告数值方法的收敛阶数。"

- id: STAT-006
  title: 随机种子固定
  severity: blocking
  evaluator: script
  pass_condition: "实验代码包含随机种子设置（torch.manual_seed/np.random.seed/random.seed 等）。"
  fix_hint: "在实验代码中添加随机种子固定，并在正文或 Reproducibility Statement 中声明。"

- id: STAT-007
  title: 超参数完整列出
  severity: blocking
  evaluator: script
  pass_condition: "论文中列出所有关键超参数（learning rate、batch size、weight decay、optimizer 等），无'按经验选取'等模糊表述。"
  fix_hint: "补充完整超参数列表，明确说明每个参数的选择依据。"

- id: STAT-008
  title: 数据集来源引用
  severity: blocking
  evaluator: script
  pass_condition: "使用的数据集在论文中包含版本号、DOI 或 URL 来源引用。"
  fix_hint: "为每个数据集补充版本信息或来源引用。"

- id: STAT-009
  title: 独立运行次数达标
  severity: blocking
  evaluator: script
  pass_condition: "独立运行次数 >= payload 配置的 min_experiment_runs (ai-exp>=3)。logs 目录包含至少 min_experiment_runs 个 run_*.log 文件。"
  fix_hint: "增加独立运行次数至达标，确保每个 run_*.log 对应一次完整实验。"

- id: STAT-010
  title: Ablation Study 完整（需消融时）
  severity: blocking
  evaluator: script
  depends_on: ["STAT-006"]
  pass_condition: "当 payload 配置的 require_ablation=true 时，draft.tex 包含 Ablation Study 章节，对每个关键组件进行消融。"
  fix_hint: "补充 Ablation Study 实验，分析每个组件的贡献。"

- id: STAT-011
  title: 神经网络可视化方法披露
  severity: blocking
  evaluator: script
  pass_condition: "若使用神经网络可视化方法（attention map、saliency map、t-SNE 等），在 method 或 appendix 中披露生成方法。"
  fix_hint: "在论文中披露神经网络可视化的具体方法（如 Grad-CAM 的实现工具、t-SNE 的参数设置）。"

# GitHub 科研 Skills 配置记录

日期：2026-09-11  
项目：油罐车侧翻——车辆横向动力学、罐内液体晃动与侧翻稳定性研究  
目标：为半年期、面向中科院三区期刊的研究流程配置可追溯的科研辅助能力。

## 结论

- 核验了用户指定的 10 个 GitHub 项目；其中“Al-Research-SKILLs”按检索结果校正为“AI-Research-SKILLs”。
- 从候选集合中静态审计 39 个子技能：启用 27 个，隔离 12 个。
- 没有执行任何上游 setup/install/update 脚本，没有注册 hooks，没有配置 API key，没有启动自动研究循环，也没有安装额外 Python/npm/系统依赖。
- 13 个上游技能的 YAML 顶层包含 Codex 校验器不接受的兼容性字段；只把这些字段迁移到 `metadata`，正文和其余文件不变。
- 这是一轮来源、结构与静态风险审计，不等同于对每个附带脚本的完整安全证明，也不等同于科学结论验证。

## 来源、固定版本与决策

| # | 用户给出的名称 | 核验后的 GitHub 来源 | 审计提交 | 启用 | 隔离/未启用 |
| --- | --- | --- | --- | --- | --- |
| 1 | Academic Research Skills | [Imbad0202/academic-research-skills-codex](https://github.com/Imbad0202/academic-research-skills-codex) | `925975e933a20893b81681d925a3404e3b7f73b7` | `academic-research-suite` | 未运行 setup、hooks、跨模型传输或程序化文献核验；该包为 CC BY-NC 4.0，限非商业学术用途并保留署名 |
| 2 | Scientific Agent Skills | [K-Dense-AI/scientific-agent-skills](https://github.com/K-Dense-AI/scientific-agent-skills) | `15e77e6215425bd9a498ca54e049a06176277189` | `experimental-design`、`matlab`、`statistical-analysis`、`statistical-power`、`uncertainty-and-units` | `fluidsim` 与本项目 Fluent-VOF/真实罐体边界不匹配；`literature-review` 含远程 `curl | bash` 路线 |
| 3 | nature-skills | [Yuan1z0825/nature-skills](https://github.com/Yuan1z0825/nature-skills) | `c4e4c99fbeaf0168cda090f8739e1508017a610e` | `nature-shared`、`nature-experiment-log`、`nature-figure`、`nature-ref-verifier`、`nature-response`、`nature-reviewer`、`nature-statistics`、`nature-writing` | 其余 12 个功能与当前阶段无直接关系；OpenRouter、飞书和 Zotero 写入路线不配置 |
| 4 | Auto-claude-code-research-in-sleep | [wanshuiyin/Auto-claude-code-research-in-sleep](https://github.com/wanshuiyin/Auto-claude-code-research-in-sleep) | `f1bd907b58f653131ebe6807c482e2554e07f9b9` | `analyze-results`（低优先级辅助） | `experiment-plan`、`experiment-audit`、`novelty-check`、`paper-claim-audit`、`result-to-claim`：自动派生代理/写追踪文件，且所选子集缺共享依赖 |
| 5 | Al-Research-SKILLs | [Orchestra-Research/AI-Research-SKILLs](https://github.com/Orchestra-Research/AI-Research-SKILLs) | `773a52944ba4747a18bd4ae9ade53fff041adcbc` | `brainstorming-research-ideas`、`creative-thinking-for-research` | `academic-plotting` 的 Gemini 外部生成路线未启用 |
| 6 | Research Paper Writing Skills | [Master-cai/Research-Paper-Writing-Skills](https://github.com/Master-cai/Research-Paper-Writing-Skills) | `77e7c2c1ba06f7d71844873147665437a03aac1b` | `research-paper-writing` | 无 |
| 7 | Claude Scholar | [Galaxy-Dawn/claude-scholar](https://github.com/Galaxy-Dawn/claude-scholar/tree/codex)（Codex 分支） | `f0edf5f0d78d5487518fccbe9bec9dba74761c83` | `citation-verification`、`research-ideation`、`results-analysis`、`results-report`、`paper-self-review`、`review-response` | 未安装仓库级 setup、hooks、settings；Zotero 自动导入与附带引文脚本默认不运行 |
| 8 | Auto Empirical Research Skills | [brycewang-stanford/Auto-Empirical-Research-Skills](https://github.com/brycewang-stanford/Auto-Empirical-Research-Skills) | `d31f17f0e26a2086a3efa6d982d7fc089fed33ce` | 0 | `00.1-Full-empirical-analysis-skill_Python`：入口约 11.5 万字符、触发范围过宽、未锁定依赖，且以经济学/流行病学因果推断为主；保留在审计区，不做全局自动触发 |
| 9 | codex-claude-academic-skills | [zLanqing/codex-claude-academic-skills](https://github.com/zLanqing/codex-claude-academic-skills) | `7ed6377f0efb6a38951b48ef03b19d996e454b1f` | `office-academic-skill`、`research-writing-skill` | `scientific-toolkit-skill` 捆绑远程安装、API key 与大批未锁定依赖，暂不启用 |
| 10 | medical-research-skills | [aipoch/medical-research-skills](https://github.com/aipoch/medical-research-skills) | `f5ef65b9bea79b6dd9553f52f95b0d08f7d64d26` | `basic-research-design`（仅医学研究草案，和油罐车项目默认不联动） | `sample-size-basic`、`systematic-review-screener` 存在文档—CLI 不一致、缺依赖声明与输出边界问题 |

## 当前项目的调用优先级

1. 文献与问题定义：已有 `zotero` + `academic-research-suite` + `research-ideation`。任何引文必须回到 DOI、出版社页或原文核验；不得把“检索到”当作“支持主张”。
2. 试验/仿真设计：`experimental-design` + `uncertainty-and-units`。优先处理装液率定义、自由液面初始几何、网格/时间步独立性、车辆—液体耦合、工况随机化与不确定度。
3. 数值与数据处理：`matlab` + `statistical-analysis` + `statistical-power`。附带脚本运行前先检查依赖、输入和输出路径。
4. 图表：`nature-figure` 只走本地 Python/R 路线，图必须由可追溯数据生成；不使用生成式图片承载定量证据。
5. 写作：已有 `scientific-writing` 为证据边界主技能，`nature-writing`、`research-paper-writing`、`research-writing-skill`只补充结构和语言。
6. 投稿前审查：已有 `peer-review` + `paper-self-review` + `nature-reviewer` + `nature-statistics`；`review-response` 只在收到真实审稿意见后使用。

## 运行边界

- 不自动安装软件包，不执行 `curl | bash`，不运行仓库 updater/sync/setup。
- 不启用 ARIS 自动循环、自动代理链、自动提交、自动推送或云端实验。
- 不上传未发表论文、Zotero 库、事故数据、仿真数据或实验数据到第三方 API。
- `nature-ref-verifier` 与 `citation-verification` 默认只读；Zotero 新建、修改、附加 PDF 等写操作必须由用户明确要求。
- `nature-figure` 不配置 OpenRouter；`academic-plotting` 的 Gemini 路线保持隔离。
- 医疗技能不得用于临床决策、患者处置或伦理替代；当前油罐车研究不会默认调用医疗技能。
- 任何技能输出都只是辅助材料，不能替代网格/时间步独立性、实验复现、数据审计、领域专家判断与期刊同行评审。

## Codex 兼容性调整

以下 13 个技能先在官方 `quick_validate.py` 中出现非法顶层字段，随后只将这些字段迁入 `metadata`：

`experimental-design`、`matlab`、`statistical-power`、`uncertainty-and-units`、`brainstorming-research-ideas`、`creative-thinking-for-research`、`citation-verification`、`research-ideation`、`results-analysis`、`results-report`、`paper-self-review`、`review-response`、`basic-research-design`。

正文未改；除根 `SKILL.md` 的上述 YAML 迁移外，其余载荷与审计区副本一致。

## 验证证据

- 安装目录：`C:/Users/LENOVO/.codex/skills`
- 审计隔离目录：`C:/Users/LENOVO/Documents/Codex/2026-09-09/new-chat/work/github-skills-audit`
- Codex 快速结构校验：27/27 通过。
- 文件数量：27/27 与审计区一致。
- 除根 `SKILL.md` 外，换行规范化后的载荷：27/27 与审计区一致。
- 根 `SKILL.md` 正文：27/27 与审计区一致。
- Nature 共享引用、Claude Scholar research-contract 与关键脚本依赖：9/9 路径存在。
- 10 个仓库的审计提交在安装后再次查询，10/10 与审计前一致。

新技能需要重启 Codex 后加载。隔离项保留供后续修复和再次审计，但当前不属于可调用技能。

# 科研Skills配置记录

安装日期：2026-09-10。

来源：[K-Dense-AI/claude-scientific-writer](https://github.com/K-Dense-AI/claude-scientific-writer)。固定提交：`0c7260603be3de4dd5161565ab92e85b31c45eb5`。使用Skill Installer的GitHub安装脚本，先下载至工作区审查，再安装到个人Skills目录；没有安装整个仓库或修改已有Skills。

| Skill | 版本 | 安装路径 | 本项目用途 |
| --- | --- | --- | --- |
| scientific-writing | 2.0 | C:/Users/LENOVO/.codex/skills/scientific-writing | 科学写作、引用/结论证据追溯、数字与方法一致性 |
| peer-review | 2.1 | C:/Users/LENOVO/.codex/skills/peer-review | 有授权的研究方案/论文自查，构建可执行评审意见 |
| scientific-critical-thinking | 1.2 | C:/Users/LENOVO/.codex/skills/scientific-critical-thinking | 实验设计、混杂因素、数据泄漏、推断边界检查 |

## 边界

- 三者均声明MIT许可；保留上游说明与版本，不宣称为官方SCI认证工具。
- 已阅读三个SKILL.md，检查脚本导入与网络、进程执行、环境访问等风险点，并检查共用写入函数。这是基本静态检查，不是完整安全审计。
- 科学写作与同行评审的附带脚本是本地校验工具；不以校验通过代替人工科学审核或实际复现实验。
- 科学批判性思维包含可选第三方绘图提示；本次没有配置密钥、安装其外部绘图依赖或调用该流程。
- 未上传论文全文、Zotero库、未发表稿件或仿真数据；联网仅用于公开资料检索与技能下载。
- 其中GRADE、Cochrane和临床报告规范只在适用研究中使用，不直接套到车辆动力学仿真。油罐车项目优先使用独立验证、场景分组、数值收敛、量纲检查和事件级统计。
- 新Skills从下一回合可用。后续调用前仍需遵守其授权、保密和人工审核边界。

配套产物《油罐车侧翻_半年研究指导书》是研究设计评审稿，不是已经完成的平台或可直接投稿论文。当前未修改原仿真项目代码。

# Simulink Skills 与 MCP 审查记录（2026-10-12）

## 项目环境

- 项目：Truck
- MATLAB 根目录：本机安装路径（不纳入仓库记录）
- MATLAB/Simulink 版本基线：R2022a
- 已配置 MCP：MathWorks MATLAB MCP Server v0.14.0
- 安装范围：当前 Truck 项目的 `.github/skills/`

## GitHub 候选审查

| 候选 | 审查时 Stars | 结论 | 主要原因 |
|---|---:|---|---|
| `matlab/matlab-mcp-server` | 1645 | 保留现有安装 | MathWorks 官方；支持 MATLAB R2021a+；当前项目已配置 v0.14.0；基础工具可通过受审 MATLAB 代码调用 R2022a Simulink API。 |
| `matlab/simulink-agentic-toolkit` | 1217 | 暂不安装 | MathWorks 官方且维护活跃，但仓库和各 Skill manifest 要求 MATLAB R2023a+；其专用 `model_*` 扩展不符合当前 R2022a 基线。 |
| `sohumsuthar/simulink-mcp` | 25 | 不安装 | 文档仅列 R2024a–R2025b；依赖 Python 3.10+ MATLAB Engine；会另启独立 MATLAB 会话；许可证为 PolyForm Noncommercial；与现有官方 MCP 重复。 |
| `summer521521/MATLAB_Simulink_plugin` | 2 | 仅安装单个文本 Skill | MCP 启动器仍包装同一官方 MATLAB MCP，不增加必要能力；完整插件含会话启动与广泛写操作。只取无脚本依赖的 `simulink-simulation` Skill，并进行本项目安全加固。 |
| `turboboost17/simulink-mcp-server-skill` | 1 | 不安装 | 维护与采用度低；依赖 MATLAB Python Engine 和共享工作区；会扩大执行面，收益不足。 |
| `rohailamalik/matlab-simulink-mcp` | 0 | 不安装 | 无 Stars/分叉；另建 Python MCP 与 MATLAB Engine 链路；缺少相对现有官方 MCP 的必要优势。 |

Stars 为 2026-10-12 审查时 GitHub 返回值，只作为采用度信号，不代替代码与兼容性审查。

## 已安装内容

- 来源：`summer521521/MATLAB_Simulink_plugin`
- 固定提交：`536af4dbde3c7bd0765cd3d7cd5160679c94f3e4`
- 上游路径：`skills/simulink-simulation`
- 本地路径：`.github/skills/simulink-simulation/SKILL.md`
- 本地改动：增加 R2022a 兼容性门槛；禁止静默启动 MATLAB 或回退到 `matlab -batch`/Python Engine；要求仿真、并行池和保存动作先获确认；要求记录单位、采样时间、输入输出和验证证据。

## MCP 决策

不新增第二个 Simulink MCP。继续使用项目 `.mcp.json` 中的 MathWorks MATLAB MCP Server v0.14.0；它已固定 MATLAB 根目录并关闭遥测。当前 R2022a 不启用 `matlab/simulink-agentic-toolkit` 的 `tools/tools.json` 扩展。

## 未执行事项

- 未启动或关闭 MATLAB、Simulink、TruckSim 或 Fluent。
- 未运行仿真、模型编译或测试。
- 未安装 MATLAB Add-On、Python Engine 或新的 Python 包。
- 未修改或保存任何 `.slx` 模型。

## 后续升级条件

升级到 MATLAB R2023a 或更高版本后，可重新审查并优先迁移到 MathWorks 官方 `matlab/simulink-agentic-toolkit`；迁移前应先核对所需工具箱、工具清单、遥测设置和现有 MCP 配置，避免并存重复服务器。

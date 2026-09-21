# TruckSim 2022 七自由度半挂液罐车配置指南

## 概述

本指南详细说明如何在 TruckSim 2022 中配置七自由度半挂式液罐车模型，设置 I/O 通道，并与 Simulink 2022a 中的 LDP 液体晃动模型进行联合仿真。

## 配置流程总览

1. 选择车辆模板 → 2. 调整车辆参数 → 3. 配置 I/O 通道 → 4. 配置道路 → 5. 生成 Simulink 模型

---

## 第一步：新建仿真文件

1. 启动 TruckSim 2022
2. 菜单栏：`File → New (New Database)`
3. 命名数据库：`tanker_ldp_cosim`
4. 创建新的 simfile：右键数据库 → `Add New Dataset`
5. 命名为：`tanker_7dof_base`

---

## 第二步：选择车辆模型

### 2.1 牵引车选择
- 在左侧导航树中选择：`Vehicle: Assembly`
- 点击 `Tractor` 下拉框 → 选择类似车型：
  - 推荐：`2A Cab Over 4x2`（四轴牵引车）
  - 或 `2A Conventional 6x4`（六轮牵引车）

### 2.2 半挂车选择
- 在 Vehicle Assembly 页面的 `Trailer` 部分：
  - 选择：`3A Tri axle Van Trailer`（三轴厢式半挂车）
  - 后续将其修改为罐车参数

---

## 第三步：车辆七自由度参数配置

> 七自由度说明：纵向位移、横向位移、横摆、侧倾（簧载质量）、侧倾（非簧载质量前）、侧倾（非簧载质量后）、俯仰

### 3.1 牵引车质心高度
- 导航到：`Vehicle: Assembly → Tractor → Sprung Mass`
- 设置：
  - **CG Height (质心高度)**: `1100 mm`
  - **Roll Inertia (Ixx)**: `4500 kg·m²`
  - **Pitch Inertia (Iyy)**: `12000 kg·m²`
  - **Yaw Inertia (Izz)**: `18000 kg·m²`
  - **Sprung Mass**: `7500 kg`

### 3.2 牵引车轮距
- 导航到：`Vehicle: Assembly → Tractor → Front Suspension`
- 设置 `Track Width`: `2050 mm`

- 导航到：`Vehicle: Assembly → Tractor → Rear Suspension`
- 设置 `Track Width`: `1860 mm`

### 3.3 牵引车悬架刚度/阻尼
- **前悬架** (`Front Suspension → Spring/Damper`):
  - Spring Stiffness: `250 N/mm`（= 250000 N/m）
  - Damper Compression: `15 N·s/mm`
  - Anti-roll Bar Stiffness: `50000 N·m/deg`（如有）
- **后悬架** (`Rear Suspension → Spring/Damper`):
  - Spring Stiffness: `350 N/mm`
  - Damper Compression: `20 N·s/mm`
  - Anti-roll Bar Stiffness: `80000 N·m/deg`

### 3.4 牵引车轮胎侧偏刚度
- 导航到：`Vehicle: Assembly → Tractor → Front Tire`
- 轮胎模型选择：`Pacejka 5.2` 或 `Table Lookup`
- 参考侧偏刚度：`180000 N/rad`

### 3.5 半挂罐车参数
- 导航到：`Vehicle: Assembly → Trailer → Sprung Mass`
- 设置：
  - **Sprung Mass**: `26500 kg`（空罐6500 + 液体20000）
  - **CG Height**: `1800 mm`
  - **Roll Inertia (Ixx)**: `12000 kg·m²`
  - **Pitch Inertia (Iyy)**: `95000 kg·m²`
  - **Yaw Inertia (Izz)**: `85000 kg·m²`

### 3.6 挂车轮距与悬架
- 挂车轮距：`1860 mm`（三轴相同）
- 挂车悬架（三轴钢板弹簧）：
  - Spring Stiffness: `400 N/mm`
  - Damper: `25 N·s/mm`
- 轴间距：`1310 mm`

### 3.7 第五轮（鞍座）
- 导航到：`Vehicle: Assembly → Trailer → Hitch/5th Wheel`
- 设置：
  - **5th Wheel Lead**: `300 mm`（鞍座前置距）
  - **5th Wheel Height**: `1150 mm`

---

## 第四步：配置 I/O 通道（关键步骤！）

这是联合仿真最关键的配置，决定了 TruckSim 与 Simulink 之间交换哪些数据。

### 4.1 Export 通道（TruckSim → Simulink）

点击左侧导航树：`Models → Simulink`，然后选择 Export 标签页。

在 Export Channels 表格中添加以下通道：

| 序号 | 变量名 (Variable)          | 说明               | 单位     |
|------|---------------------------|--------------------|----------|
| 1    | `Vx`                      | 纵向车速           | km/h     |
| 2    | `Ay`                      | 侧向加速度(簧载)   | g        |
| 3    | `AVz`                     | 横摆角速度         | deg/s    |
| 4    | `Roll`                    | 簧载质量侧倾角     | deg      |
| 5    | `AVx_Roll`                | 侧倾角速度         | deg/s    |
| 6    | `Steer_SW`                | 方向盘转角         | deg      |
| 7    | `Ax`                      | 纵向加速度         | g        |
| 8    | `Fz_L1`                   | 左前轮垂向力       | N        |
| 9    | `Fz_R1`                   | 右前轮垂向力       | N        |
| 10   | `Fz_L2`                   | 左后轮垂向力       | N        |
| 11   | `Fz_R2`                   | 右后轮垂向力       | N        |
| 12   | `Fz_L3`                   | 挂车左1轴垂向力    | N        |
| 13   | `Fz_R3`                   | 挂车右1轴垂向力    | N        |
| 14   | `Fz_L4`                   | 挂车左2轴垂向力    | N        |
| 15   | `Fz_R4`                   | 挂车右2轴垂向力    | N        |
| 16   | `Fz_L5`                   | 挂车左3轴垂向力    | N        |
| 17   | `Fz_R5`                   | 挂车右3轴垂向力    | N        |
| 18   | `Ay_T`                    | 挂车/罐体侧向加速度 | g        |

> **重要**: 变量名可通过右侧搜索框查找，不同 TruckSim 版本命名可能略有差异。

### 4.2 Import 通道（Simulink → TruckSim）

选择 Import 标签页，添加以下通道：

| 序号 | 变量名 (Variable)      | 说明                         | 单位  |
|------|------------------------|------------------------------|-------|
| 1    | `IMP_FY_T`             | 罐体处横向力（液体晃动）     | N     |
| 2    | `IMP_MX_T`             | 罐体处侧倾力矩（液体晃动）   | N·m   |
| 3    | `IMP_STEER_SW`         | 方向盘转角（Simulink 输入）  | deg   |

> **注意**: 
> - `IMP_FY_T` 和 `IMP_MX_T` 施加点在挂车簧载质心处
> - `IMP_STEER_SW` 用于从 Simulink 控制方向盘，若使用 TruckSim 内置驾驶员可省略

### 4.3 力/力矩施加点设置

- 在 Import 通道配置中，为 `IMP_FY_T` 和 `IMP_MX_T` 设置施加点坐标：
  - **X**: 牵引销后方 `4200 mm`（挂车质心位置）
  - **Y**: `0 mm`（中心线）
  - **Z**: 罐体质心高度 `1800 mm`

---

## 第五步：道路与工况配置

### 5.1 道路横坡（超高）设置

- 导航到：`Miscellaneous → Road: 3D Surface`
- 在道路摩擦系数设置旁找到横坡选项：
  - **Cross Slope / Superelevation**: 设为变量，以便从 Simulink 或批量仿真中修改
  - 初始值设为 `0%`

### 5.2 道路摩擦系数
- 设置 `Mu (Friction Coefficient)`: `0.85`（干沥青路面）

### 5.3 车速控制
- 导航到：`Procedure → Driver Controls`
- **目标车速 (Target Speed)**: 设为变量，默认 `80 km/h`
- **初始车速 (Initial Speed)**: 与目标车速一致

### 5.4 驾驶员模型
- 导航到：`Procedure → Driver Model`
- 路径跟踪控制：使用 `Driver Path Follower`（用于双移线）
- 若使用 Simulink 输入方向盘转角，此处应关闭路径跟踪

### 5.5 仿真设置
- 导航到：`Miscellaneous → Run Control`
- **Simulation Step Size**: `0.001 s`（与 Simulink 一致）
- **Output Step Size**: `0.01 s`

---

## 第六步：生成 Simulink 联合仿真模型

### 6.1 检查配置
1. 确认所有 I/O 通道已正确配置
2. 确认仿真步长与 Simulink 一致（0.001s）
3. 保存 simfile：`File → Save`

### 6.2 发送到 Simulink
1. 点击菜单栏：`Models → Simulink`
2. 检查 Export/Import 通道数量是否与配置一致
3. 点击 **`Send to Simulink`** 按钮
4. 等待生成完成

### 6.3 生成的模型说明
TruckSim 会生成以下组件：
- **S-Function 块**：封装了 TruckSim 的车辆动力学求解器
- **Import 块**：接收来自 Simulink 的输入信号
- **Export 块**：输出车辆状态给 Simulink

### 6.4 接入 LDP 模型
1. 打开生成的 Simulink 模型
2. 从 Export 端口中提取 `Ay_T`（罐体侧向加速度）
3. 连接到 LDP 子系统（`ldp_slosh_model.slx`）的输入端
4. 将 LDP 输出的 `F_slosh_y` 和 `M_slosh_x` 连接到 TruckSim 的 Import 端口

---

## 第七步：运行验证仿真

### 7.1 运行测试
在 MATLAB 中执行：
```matlab
cd('C:\Users\LENOVO\tanker_trucksim_cosim\matlab');
init_params;
setup_ldp_model;

% 运行单次联合仿真测试
results = run_cosim('maneuver', 'step_steer', 'speed', 80, ...
    'steer_amplitude', 150, 'superelevation', 0);
```

### 7.2 验证检查清单
- [ ] TruckSim S-Function 加载成功
- [ ] Export 信号正确显示（检查侧向加速度、侧倾角等）
- [ ] LDP 模型输出在合理范围（F_slosh_y: ±20000N, M_slosh_x: ±50000N·m）
- [ ] 联合仿真稳定运行，无发散
- [ ] 有/无液体晃动对比明显（侧倾角幅值差异）

---

## 常见问题

### Q1: "Send to Simulink" 灰色不可点击
**原因**: 未正确配置 I/O 通道或仿真设置。  
**解决**: 确保 Export 和 Import 通道数量 > 0，保存 simfile 后重试。

### Q2: Simulink 报错 "S-Function not found"
**原因**: MATLAB 未找到 TruckSim S-Function。  
**解决**: 运行 TruckSim 安装目录下的 `startup.m` 将 TruckSim 路径添加到 MATLAB：
```matlab
addpath('C:\Program Files\TruckSim2022\Matlab');
```

### Q3: 仿真到一半发散/数值错误
**原因**: 仿真步长过大或 LDP 参数不合理。  
**解决**: 
1. 减小仿真步长至 0.0005s
2. 检查 LDP 模型中的摆长和质量参数是否与罐体几何匹配
3. 增大阻尼比至 0.1~0.2 提高数值稳定性

### Q4: 无法找到特定的 TruckSim 变量名
**原因**: TruckSim 版本间变量名有差异。  
**解决**: 在 Export/Import 配置界面的搜索框中输入关键词（如 "roll", "ay", "Fz"），从下拉列表中选取。

---

## 参考参数来源

- 郑淳心. 液罐车侧翻稳定性研究[D]. 吉林大学
- NHTSA. Fishhook Maneuver Test Procedure, FMVSS No. 126
- ISO 3888-2. Double Lane Change Test
- TruckSim 2022 User Manual - Simulink Co-simulation

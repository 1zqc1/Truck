# Fluent 第一步操作指导

## 2D 液体晃动 VOF 仿真（从 Workbench 到求解）

---

## 第一步：Workbench 建系统

1. 在 Workbench 左侧 Toolbox 找到 **Fluid Flow (Fluent)**
2. 拖到右侧 Project Schematic
3. 双击 **Geometry** 单元格，打开 SpaceClaim（或 DesignModeler）

## 第二步：几何建模（2D 圆形罐截面）

在 SpaceClaim 中：
1. 用 **Circle** 工具画一个圆，圆心 (0,0)，直径 2.5 m
2. 切换到 **Concept → 2D Analysis** 模式（确保是 2D 平面）
3. 关闭 SpaceClaim，返回 Workbench

> 简化替代：也可以先在 SpaceClaim 画矩形（2.5m × 2.5m），后续升级到圆。

## 第三步：网格划分（Mesh）

1. 双击 **Mesh** 单元格
2. 右键 Mesh → Insert → **Face Meshing**（选择圆面）
3. 设置网格尺寸：右键 Mesh → Insert → **Sizing**，单元尺寸 **0.02 m**
4. 点击 **Generate Mesh**
5. 检查网格量（2D 圆，0.02m 尺寸约 1~2 万单元）
6. 关闭 Mesh，返回 Workbench

## 第四步：Fluent 求解器设置

双击 **Setup** 单元格，启动 Fluent Launcher：
- **Dimension**: 2D
- **Double Precision**: 勾选（VOF 推荐）
- **Parallel**: 可不勾（2D 网格小）

### 4.1 General 设置

1. **General** 面板
   - Solver → **Transient**（瞬态）
   - Gravity → 勾选，设置 g = -9.81 m/s²（y 方向）

### 4.2 Models 设置

1. **Models → Multiphase** → 选择 **Volume of Fluid (VOF)**
   - Number of Phases = 2
   - 其余默认

2. **Models → Viscous** → 保持 **Laminar**（层流）

### 4.3 Materials 设置

1. 确认 **air** 材料（默认已有，密度 1.225）
2. 添加 **water-liquid**：
   - 从 Fluent Database 复制 water-liquid
   - 密度 998.2，粘度 0.001003

### 4.4 Phases 设置

1. **Phases → phase-1 (Primary Phase)** → 设为 **air**
2. **Phases → phase-2 (Secondary Phase)** → 设为 **water-liquid**
3. **Phases → Interaction → Surface Tension** → 勾选，0.072 N/m

### 4.5 边界条件

1. 圆形壁面（默认 wall）→ 无滑移，接触角默认
2. 检查 **Operating Conditions**：压力 101325 Pa，参考位置 (0,0)

### 4.6 编译 UDF（侧向激励）

1. 把 `udf_sideways.c` 放到 Fluent 工作目录
2. **User-Defined → Functions → Compiled**（或 Interpreted）
   - 编译 udf_sideways.c
   - 加载库

### 4.7 添加源项

1. **Cell Zone Conditions** → 双击流体域
2. 勾选 **Source Terms**
3. 在 **X Momentum** 的源项数量填 1
4. 从下拉框选择编译好的 UDF `x_momentum_source`

### 4.8 初始化（标记液面）

1. **Solution → Initialization** → 标准初始化
2. 初始化后，**Adapt → Region** 或 **Solution → Patch**：
   - 用 **Patch** 功能，把液面以下区域标记为 water

   **Region 设置（圆形罐，直径 2.5m，70% 充液比，液面在圆心上方约 0.4m）：**
   ```
   Quad Region: x ∈ [-1.25, 1.25]，y ∈ [-1.25, 0.4]
   ```
   （矩形覆盖液面以下区域，超出圆的部分 Patch 时自动忽略）

3. Patch 方法：
   - **Solution → Initialization → Patch**
   - Phase 选 water-liquid，Volume Fraction = 1
   - Region 选择标记的区域（即液面以下的矩形）

### 4.9 求解设置

1. **Solution → Methods**
   - Pressure: **PRESTO!**（VOF 必需）
   - Momentum: Second Order Upwind
   - Volume Fraction: **Geo-Reconstruct**（默认）

2. **Solution → Controls** → 默认

3. **Run Calculation**
   - Time Step Size: **0.001 s**
   - Number of Time Steps: **2000**（模拟 2s）
   - Max Iterations/Time Step: **20**

4. 点击 **Calculate**

## 第五步：后处理（提取晃动力）

1. **Results → Reports → Forces**
   - 选择壁面
   - Direction Vector: (1, 0, 0)（x 方向，即侧向晃动力）
   - Print / Plot 输出

2. 保存结果：
   - **File → Write → Case & Data**

---

## 关键提示

1. **第一次先跑短时间验证**：先设 100 步（0.1s），确认不发散，再跑完整 2000 步
2. **时间步长**：VOF 仿真时间步长要满足 CFL 条件，0.001s 是安全值
3. **液面 Patch 是关键**：Patch 不对，仿真一开始就错
4. **观察残差和液面**：每步迭代后看液面是否合理

## 遇到问题

- **发散**：减小时间步长到 0.0005s
- **液面破碎**：加密液面附近网格
- **UDF 报错**：检查 UDF 编译是否成功、源项是否挂钩正确

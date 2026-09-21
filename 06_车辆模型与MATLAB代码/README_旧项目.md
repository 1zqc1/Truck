# 七自由度半挂液罐车联合仿真与LSTM侧翻预测

## 项目状态（2026-07-03）

✅ 已完成：TruckSim建模 → 14组工况仿真 → 数据提取 → LTR/TTR标签 → LSTM训练 → 模型保存
⏸ 未完成：TruckSim-Simulink实时联合仿真闭环、侧翻控制策略

## 快速恢复工作

### MATLAB路径
```matlab
cd('C:\Users\LENOVO\tanker_trucksim_cosim\matlab')
```

### 查看已保存的模型和数据
```matlab
load('..\simulation_data\ts_all_runs.mat')     % 14组仿真详细数据
load('..\simulation_data\ts_dataset.mat')      % LSTM训练数据集
load('..\simulation_data\lstm_ts_model.mat')   % 训练好的LSTM模型
```

### 新增TruckSim工况后提取数据
```powershell
powershell -ExecutionPolicy Bypass -File extract_ts.ps1 -outName <工况名>
```

### 重新处理数据并训练
```matlab
process_ts_data
train_lstm_ts
```

### TruckSim CLI仿真
```powershell
"VS_SolverWrapper_CLI_64.exe" -sim "simfile.sim"
```
注意：运行前需要注释掉simfile中的EXT_MODEL_STEP和PORTS行，DLLFILE改为trucksim_64.dll

## 项目结构

```
tanker_trucksim_cosim/
├── matlab/
│   ├── init_params.m              # 车辆+LDP参数初始化
│   ├── vehicle_7dof.m             # 7-DOF车辆动力学模型
│   ├── build_ldp_subsystem.m      # LDP双摆Simulink子系统
│   ├── setup_ldp_model.m          # LDP Simulink模型生成
│   ├── build_cosim_model.m        # 联合仿真Simulink模型（未完成）
│   ├── run_full_simulation_v2.m   # 离线仿真（637工况，含横坡）
│   ├── process_ts_data.m          # TruckSim CSV → LSTM数据集
│   ├── train_lstm_ts.m            # LSTM训练+评估
│   ├── extract_ts.ps1             # VSB二进制→CSV提取工具
│   ├── fix_model.m                # Simulink模型修复（历史遗留）
│   ├── setup_complete.m           # 联合仿真环境配置（历史遗留）
│   └── run_cosim.m / run_dangerous_maneuvers.m  # 离线仿真（旧版）
├── simulation_data/
│   ├── ts_*.csv                   # 14组TruckSim仿真原始数据
│   ├── ts_all_runs.mat            # 全部仿真数据（MATLAB格式）
│   ├── ts_dataset.mat             # LSTM训练数据集
│   ├── lstm_ts_model.mat          # 训练好的LSTM模型
│   ├── lstm_rollover_model.mat    # 离线模型训练的LSTM（效果差）
│   └── training_dataset.mat       # 离线仿真数据集（旧）
├── trucksim_config/
│   └── Export_tanker_ldp.par      # TruckSim I/O通道配置模板
└── docs/
    └── TruckSim配置指南.md        # TruckSim GUI配置步骤
```

## LSTM模型性能

| 指标 | 值 |
|------|-----|
| R² | 0.958 |
| RMSE | 0.066 |
| F1 | 0.946 |
| Accuracy | 99.0% |
| Precision | 91.9% |
| Recall | 97.4% |

## 14组仿真工况

| 工况 | 车速 | 转角 | Ay max | 侧倾 | LTR | 状态 |
|------|------|------|--------|------|-----|------|
| DLC 70km/h | 70 | - | 0.37g | 4.1° | 0.65 | 警告 |
| SS 80/60° | 80 | 60° | 0.27g | 2.6° | 0.48 | 安全 |
| SS 60/120° | 60 | 120° | 0.33g | 3.3° | 0.55 | 安全 |
| SS 80/90° | 80 | 90° | 0.39g | 6.6° | 0.77 | 警告 |
| SS 80/120° | 80 | 120° | 0.49g | 79.7° | 1.00 | 侧翻 |
| DLC 100 LowMu | 100 | - | 2.05g | 5.8° | 0.55 | 警告 |
| SS 60/180° | 60 | 180° | 0.47g | 79.5° | 1.00 | 侧翻 |
| SS 70/120° | 70 | 120° | 0.42g | 79.1° | 1.00 | 侧翻 |
| SS 70/180° | 70 | 180° | 0.62g | 78.6° | 1.00 | 侧翻 |
| SS 90/90° | 90 | 90° | 0.45g | 77.9° | 1.00 | 侧翻 |
| SS 90/120° | 90 | 120° | 0.55g | 79.8° | 1.00 | 侧翻 |
| SS 100/60° | 100 | 60° | 0.36g | 3.7° | 0.48 | 安全 |
| SS 100/90° | 100 | 90° | 0.49g | 79.7° | 1.00 | 侧翻 |
| SS 100/120° | 100 | 120° | 0.59g | 77.4° | 1.00 | 侧翻 |

## 下一步
1. 增加鱼钩(Fishhook)工况
2. TruckSim-Simulink联合仿真闭环
3. 侧翻控制策略
4. 跨工况泛化验证

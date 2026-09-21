%% fix_model.m —— 修复 tanker_cosim.slx 的 S-Function 配置

% 添加 TruckSim 路径
addpath('D:\Program Files (x86)\TruckSim\TruckSim2022.1_Prog\Programs\solvers\Matlab');

% 打开模型
model = 'tanker_cosim';
if ~bdIsLoaded(model)
    load_system(model);
end

% 修复 S-Function 名称和参数（TruckSim 2022 使用 vs_sf）
set_param([model '/TruckSim_Vehicle'], 'FunctionName', 'vs_sf');
set_param([model '/TruckSim_Vehicle'], ...
    'Parameters', '''D:\Program Files (x86)\TruckSim\data\simfile.sim'',2,0');

% 修复 Demux 输出数量（5 个 Export 通道）
set_param([model '/Demux_18ch'], 'Outputs', '5');

% 修复 Selector 输入宽度
set_param([model '/Sel_Ay'], 'InputPortWidth', '5');

% 修复 Mux 输入数量（2 个 Import 通道）
set_param([model '/Mux_Import'], 'Inputs', '2');

% 保存
save_system(model);
fprintf('===== tanker_cosim.slx 已修复 =====\n');
fprintf('S-Function: vs_sf\n');
fprintf('Export 通道(5): Vx, Ay, AVz, Roll, AVx\n');
fprintf('Import 通道(2): IMP_FYEXA2, IMP_MX_EXT\n');
fprintf('\n运行: sim(''tanker_cosim'')\n');

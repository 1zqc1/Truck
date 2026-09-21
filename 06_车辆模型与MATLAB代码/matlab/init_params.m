%% init_params.m —— 七自由度半挂液罐车联合仿真参数初始化
%  参考：郑淳心等学者的液罐车侧翻稳定性研究
%  用途：定义车辆、LDP模型、工况的全部参数，供其他脚本调用

%% ==================== 车辆结构参数（七自由度半挂液罐车）====================
% 参考某典型6轴半挂液罐车参数

% --- 牵引车参数 ---
veh.tractor.mass       = 7500;      % 牵引车整备质量 [kg]
veh.tractor.wheelbase  = 3.8;       % 轴距 [m]
veh.tractor.track_f    = 2.05;      % 前轮距 [m]
veh.tractor.track_r    = 1.86;      % 后轮距 [m]
veh.tractor.cg_height  = 1.10;      % 牵引车质心高度 [m]
veh.tractor.cg_front   = 1.50;      % 质心距前轴 [m]
veh.tractor.roll_inertia = 4500;    % 侧倾转动惯量 [kg·m²]
veh.tractor.yaw_inertia  = 18000;   % 横摆转动惯量 [kg·m²]
veh.tractor.pitch_inertia = 12000;  % 俯仰转动惯量 [kg·m²]

% 牵引车悬架参数
veh.tractor.susp_f.stiffness  = 250000;   % 前悬架刚度 [N/m]
veh.tractor.susp_f.damping    = 15000;    % 前悬架阻尼 [N·s/m]
veh.tractor.susp_r.stiffness  = 350000;   % 后悬架刚度 [N/m]
veh.tractor.susp_r.damping    = 20000;    % 后悬架阻尼 [N·s/m]
veh.tractor.susp_f.anti_roll  = 50000;    % 前稳定杆刚度 [N·m/rad]
veh.tractor.susp_r.anti_roll  = 80000;    % 后稳定杆刚度 [N·m/rad]

% 牵引车轮胎参数 (295/80R22.5)
veh.tractor.tire.cornering_stiffness = 180000;  % 轮胎侧偏刚度 [N/rad]
veh.tractor.tire.vertical_stiffness  = 1000000; % 轮胎垂向刚度 [N/m]
veh.tractor.tire.rolling_radius      = 0.51;    % 滚动半径 [m]

% --- 半挂罐车参数 ---
veh.trailer.mass       = 6500;      % 空罐挂车整备质量 [kg]
veh.trailer.cargo_mass = 20000;     % 液体货物满载质量 [kg]
veh.trailer.total_mass = 26500;     % 挂车总质量 [kg]
veh.trailer.wheelbase  = 8.5;       % 挂车轴距（三轴中心距牵引销）[m]
veh.trailer.track      = 1.86;      % 挂车轮距 [m]
veh.trailer.cg_height  = 1.80;      % 挂车+罐体质心高度（满载）[m]
veh.trailer.cg_front   = 4.20;      % 质心距牵引销 [m]
veh.trailer.roll_inertia  = 12000;  % 挂车侧倾转动惯量 [kg·m²]
veh.trailer.yaw_inertia   = 85000;  % 挂车横摆转动惯量 [kg·m²]
veh.trailer.pitch_inertia = 95000;  % 挂车俯仰转动惯量 [kg·m²]

% 挂车悬架参数（三轴钢板弹簧悬架）
veh.trailer.susp.stiffness  = 400000;    % 单轴悬架刚度 [N/m]
veh.trailer.susp.damping    = 25000;     % 单轴悬架阻尼 [N·s/m]
veh.trailer.susp.anti_roll  = 30000;     % 稳定杆刚度 [N·m/rad]
veh.trailer.susp.axle_spacing = 1.31;    % 轴间距 [m]（三轴并装）

% 挂车轮胎参数
veh.trailer.tire.cornering_stiffness = 200000;
veh.trailer.tire.vertical_stiffness  = 1200000;
veh.trailer.tire.rolling_radius      = 0.51;

% --- 第五轮（鞍座）参数 ---
veh.fifth_wheel.lead     = 0.30;     % 鞍座前置距（相对后轴）[m]
veh.fifth_wheel.height   = 1.15;     % 鞍座高度 [m]
veh.fifth_wheel.roll_stiffness  = 50000;  % 鞍座侧倾刚度 [N·m/rad]
veh.fifth_wheel.roll_damping    = 5000;   % 鞍座侧倾阻尼 [N·m·s/rad]

% --- 罐体几何参数 ---
veh.tank.length    = 12.0;      % 罐体长度 [m]
veh.tank.diameter  = 2.50;      % 罐体直径 [m]
veh.tank.radius    = 1.25;      % 罐体半径 [m]
veh.tank.fill_level = 0.70;     % 充液比（70%最易诱发大幅晃动）


%% ==================== LDP 线性等效双摆模型参数 ====================
% 将液体晃动等效为两个单摆（主摆+次摆），参数基于罐体几何和充液比

ldp.g = 9.81;  % 重力加速度 [m/s²]

% --- 主摆（基频晃动模态）---
% 承载 60%~80% 的液体晃动质量
ldp.primary.mass_ratio    = 0.75;     % 占液体总质量比例
ldp.primary.mass          = ldp.primary.mass_ratio * veh.trailer.cargo_mass;  % [kg]
ldp.primary.length        = 0.55;     % 等效摆长 [m]（≈0.44*R，与充液比相关）
ldp.primary.freq          = sqrt(ldp.g / ldp.primary.length);  % 固有频率 [rad/s] ≈4.22
ldp.primary.damping_ratio = 0.07;     % 阻尼比（液体晃动阻尼低）
ldp.primary.height        = 0.40;     % 等效质心距罐底高度 [m]

% --- 次摆（高阶晃动模态）---
% 承载 20%~40% 的液体晃动质量
ldp.secondary.mass_ratio    = 0.25;
ldp.secondary.mass          = ldp.secondary.mass_ratio * veh.trailer.cargo_mass;
ldp.secondary.length        = 0.18;   % 等效摆长 [m]
ldp.secondary.freq          = sqrt(ldp.g / ldp.secondary.length);  % ≈7.39 rad/s
ldp.secondary.damping_ratio = 0.05;
ldp.secondary.height        = 0.25;   % 等效质心距罐底高度 [m]

% 构建 LDP 状态空间模型参数
% 状态: x = [θ₁, θ̇₁, θ₂, θ̇₂]'
% 输入: u = a_y (罐体处侧向加速度) [m/s²]
% 输出: [F_slosh_y, M_slosh_x] —— 晃动横向力和侧倾力矩

w1 = ldp.primary.freq;
z1 = ldp.primary.damping_ratio;
m1 = ldp.primary.mass;
L1 = ldp.primary.length;
h1 = ldp.primary.height;

w2 = ldp.secondary.freq;
z2 = ldp.secondary.damping_ratio;
m2 = ldp.secondary.mass;
L2 = ldp.secondary.length;
h2 = ldp.secondary.height;

% 状态空间矩阵
ldp.A = [0,      1,       0,      0;
        -w1^2, -2*z1*w1,  0,      0;
         0,      0,       0,      1;
         0,      0,      -w2^2, -2*z2*w2];

ldp.B = [0;  -1/L1;  0;  -1/L2];

% 输出矩阵（小角度假设：sin(θ)≈θ）
% F_slosh_y = -m1*(g*θ₁ + 2ζ₁ω₁L₁θ̇₁) - m2*(g*θ₂ + 2ζ₂ω₂L₂θ̇₂)
% M_slosh_x = m1*g*h1*θ₁ + m2*g*h2*θ₂
ldp.C = [-m1*ldp.g,        -m1*2*z1*w1*L1,  -m2*ldp.g,        -m2*2*z2*w2*L2;
          m1*ldp.g*h1,      0,                m2*ldp.g*h2,      0];

ldp.D = [0; 0];  % 无直馈项

% 初始状态（静止液体）
ldp.x0 = [0; 0; 0; 0];

% 晃动角度限幅（物理约束）
ldp.theta_max = 30 * pi/180;  % 最大晃动角 [rad]


%% ==================== 仿真参数 ====================
sim.dt        = 0.001;   % 仿真步长 [s]（1kHz，满足晃动模态精度要求）
sim.t_end     = 30;      % 单次仿真时长 [s]
sim.solver    = 'ode4';  % 定步长 Runge-Kutta
sim.output_dt = 0.01;    % 数据输出步长 [s]（100Hz，足够神经网络安全）

% TruckSim 仿真文件路径（用户需根据实际路径修改）
sim.ts_simfile = 'D:\Program Files (x86)\TruckSim\data\tanker_ldp_cosim.sim';
sim.ts_install_path = 'D:\Program Files (x86)\TruckSim';
sim.ts_matlab_path = 'D:\Program Files (x86)\TruckSim\TruckSim2022.1_Prog\Programs\solvers\Matlab';


%% ==================== 危险工况定义 ====================

% --- 车速组合 [km/h] ---
maneuvers.speeds_kmh = [60, 70, 80, 90, 100];

% --- 道路横坡/超高 [%] ---
% 正值表示弯道内倾（有利），负值表示外倾（不利/危险）
maneuvers.superelevations = [-6, -4, -2, 0, 2, 4, 6];

% --- 工况1：鱼钩转向（Fishhook）---
% NHTSA 侧翻稳定性测试标准
% 先快速左转→保持→快速右转→保持
maneuvers.fishhook.steer_amplitude = 270;   % 方向盘转角幅值 [deg]
maneuvers.fishhook.steer_rate       = 720;   % 转向速率 [deg/s]
maneuvers.fishhook.dwell_time       = 0.25;  % 保持时间 [s]

% --- 工况2：阶跃转向 ---
% 快速将方向盘打到指定角度并保持
maneuvers.step_steer.steer_amplitudes = [90, 120, 150, 180, 210];  % [deg]
maneuvers.step_steer.steer_rate       = 1000;  % 快速转向 [deg/s]
maneuvers.step_steer.hold_time        = 5.0;   % 保持时间 [s]

% --- 工况3：双移线（ISO 3888 紧急避障）---
% 模拟紧急变道避障
maneuvers.dlc.lateral_offset  = 3.5;  % 侧向偏移量 [m]
maneuvers.dlc.section_lengths = [15, 30, 25, 25, 15];  % ISO 3888 各段长度 [m]


%% ==================== LTR / TTR 标签参数 ====================
labels.ltr.threshold_high = 0.90;   % LTR 高危阈值
labels.ltr.threshold_low  = 0.70;   % LTR 注意阈值
labels.ttr.roll_threshold = 25 * pi/180;  % 侧翻临界侧倾角 [rad]（≈25°）
labels.ttr.horizon        = 3.0;    % TTR 预测时间范围 [s]

% LTR 分类标签
labels.ltr.class_safe    = 0;  % LTR < 0.7
labels.ltr.class_warning = 1;  % 0.7 ≤ LTR < 0.9
labels.ltr.class_danger  = 2;  % LTR ≥ 0.9


%% ==================== 输出配置 ====================
output.data_dir  = fullfile(fileparts(mfilename('fullpath')), '..', 'simulation_data');
output.mat_file  = fullfile(output.data_dir, 'training_dataset.mat');
output.csv_dir   = fullfile(output.data_dir, 'csv_export');

% 确保输出目录存在
if ~exist(output.data_dir, 'dir')
    mkdir(output.data_dir);
end
if ~exist(output.csv_dir, 'dir')
    mkdir(output.csv_dir);
end


%% ==================== 显示初始化信息 ====================
fprintf('=============================================================\n');
fprintf('  七自由度半挂液罐车 LDP 联合仿真参数初始化完成\n');
fprintf('=============================================================\n');
fprintf('  车辆总质量:       %.0f kg\n', veh.tractor.mass + veh.trailer.total_mass);
fprintf('  液体货物质量:     %.0f kg\n', veh.trailer.cargo_mass);
fprintf('  充液比:           %.0f%%\n', veh.tank.fill_level * 100);
fprintf('  主摆固有频率:     %.2f rad/s (%.2f Hz)\n', w1, w1/(2*pi));
fprintf('  次摆固有频率:     %.2f rad/s (%.2f Hz)\n', w2, w2/(2*pi));
fprintf('  主摆等效质量:     %.0f kg\n', m1);
fprintf('  次摆等效质量:     %.0f kg\n', m2);
fprintf('  仿真步长:         %.0f ms\n', sim.dt*1000);
fprintf('  测试车速:         %s km/h\n', mat2str(maneuvers.speeds_kmh));
fprintf('  道路横坡:         %s %%\n', mat2str(maneuvers.superelevations));
fprintf('  总工况数:         %d\n', ...
    length(maneuvers.speeds_kmh) * length(maneuvers.superelevations) * ...
    (1 + length(maneuvers.step_steer.steer_amplitudes) + 1));
fprintf('=============================================================\n');

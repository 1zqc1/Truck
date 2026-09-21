%% run_cosim.m —— 七自由度半挂液罐车 TruckSim-Simulink 联合仿真主控脚本
%  功能：
%    1. 加载 TruckSim 产生的 Simulink 模型
%    2. 将 LDP 液体晃动模型接入反馈回路
%    3. 配置工况参数（车速、方向盘转角、道路横坡）
%    4. 运行仿真并提取结果
%
%  前提条件：
%    - 已在 TruckSim 中完成车辆模型配置
%    - 已运行 setup_ldp_model.m 生成 LDP 模型
%    - 已在 TruckSim 中点击 "Send to Simulink" 生成联合仿真模型
%
%  使用示例：
%    run_cosim('maneuver', 'fishhook', 'speed', 80, 'superelevation', 4);

function results = run_cosim(varargin)
    %% 参数解析
    p = inputParser;
    p.addParameter('maneuver', 'fishhook', @(x) ismember(x, ...
        {'fishhook', 'step_steer', 'dlc'}));
    p.addParameter('speed', 80, @isnumeric);           % [km/h]
    p.addParameter('superelevation', 0, @isnumeric);   % [%]
    p.addParameter('steer_amplitude', 270, @isnumeric); % [deg]（阶跃/鱼钩用）
    p.addParameter('lateral_offset', 3.5, @isnumeric); % [m]（双移线用）
    p.addParameter('with_sloshing', true, @islogical);  % 是否包含液体晃动
    p.addParameter('sim_model', 'tanker_cosim', @ischar); % Simulink 模型名
    p.addParameter('show_animation', false, @islogical);
    p.parse(varargin{:});
    args = p.Results;

    %% 初始化参数
    init_params;
    warning('off', 'Simulink:Engine:OutputPortNotConnected');

    %% 检查 Simulink 模型
    model_name = args.sim_model;
    if ~bdIsLoaded(model_name)
        try
            load_system(model_name);
            fprintf('[INFO] 已加载模型: %s\n', model_name);
        catch
            error(['无法加载模型: %s.slx\n' ...
                   '请确保已在 TruckSim 中点击 "Send to Simulink" 生成模型,\n' ...
                   '并将模型文件放在 MATLAB 路径中。'], model_name);
        end
    end

    %% ==================== 工况配置 ====================
    speed_ms = args.speed / 3.6;
    fprintf('\n========== 联合仿真工况配置 ==========\n');
    fprintf('  工况类型:     %s\n', args.maneuver);
    fprintf('  车速:         %.0f km/h (%.2f m/s)\n', args.speed, speed_ms);
    fprintf('  道路横坡:     %.0f%%\n', args.superelevation);
    fprintf('  液体晃动:     %s\n', ternary(args.with_sloshing, '开启', '关闭'));
    fprintf('=======================================\n\n');

    %% ==================== 生成方向盘转角时间序列 ====================
    t_total = sim.t_end;
    t = (0:sim.dt:t_total)';
    steer_deg = zeros(size(t));

    switch args.maneuver
        case 'fishhook'
            steer_deg = generate_fishhook(t, args.steer_amplitude, ...
                maneuvers.fishhook.steer_rate, maneuvers.fishhook.dwell_time);

        case 'step_steer'
            steer_deg = generate_step_steer(t, args.steer_amplitude, ...
                maneuvers.step_steer.steer_rate, maneuvers.step_steer.hold_time);

        case 'dlc'
            steer_deg = generate_dlc_steer(t, speed_ms, args.lateral_offset, ...
                maneuvers.dlc.section_lengths);
    end

    %% ==================== 设置 Simulink 模型参数 ====================
    % 设置仿真时间
    set_param(model_name, 'StopTime', num2str(t_total));
    set_param(model_name, 'FixedStep', num2str(sim.dt));
    set_param(model_name, 'Solver', sim.solver);

    % 将方向盘转角信号注入工作空间
    steer_signal = [t, steer_deg];
    assignin('base', 'steer_signal', steer_signal);
    assignin('base', 'speed_kmh', args.speed);
    assignin('base', 'superelevation_pct', args.superelevation);
    assignin('base', 'with_sloshing', args.with_sloshing);

    %% ==================== 设置 TruckSim 参数 ====================
    % 更新 TruckSim 仿真文件中的车速和道路横坡
    % 通过 MATLAB 调用 TruckSim API（如果可用）
    try
        % TruckSim 2022 提供 vs_set_value 等 API 函数
        % 注意：具体 API 函数名可能因版本而异
        if exist('vs_set_value', 'file')
            % 设置车速
            vs_set_value('SPEED_TARGET', speed_ms * 3.6);  % km/h
            % 设置道路横坡
            vs_set_value('ROAD_SUPER', args.superelevation / 100);  % 转为小数
            fprintf('[INFO] TruckSim 参数已通过 API 更新\n');
        else
            fprintf('[WARN] TruckSim API 不可用，请手动在 TruckSim 中设置:\n');
            fprintf('       - 目标车速: %.0f km/h\n', args.speed);
            fprintf('       - 道路横坡: %.0f%%\n', args.superelevation);
        end
    catch ME
        fprintf('[WARN] TruckSim 参数更新失败: %s\n', ME.message);
        fprintf('       请手动在 TruckSim 中设置车速和道路横坡\n');
    end

    %% ==================== 运行仿真 ====================
    fprintf('[INFO] 开始仿真...\n');
    tic;

    try
        simOut = sim(model_name, ...
            'SaveOutput', 'on', ...
            'OutputSaveName', 'yout', ...
            'SaveTime', 'on', ...
            'TimeSaveName', 'tout');

        elapsed = toc;
        fprintf('[INFO] 仿真完成，耗时 %.2f 秒\n', elapsed);
    catch ME
        fprintf('[ERROR] 仿真失败: %s\n', ME.message);
        fprintf('[HINT] 常见原因:\n');
        fprintf('       1. TruckSim S-Function 未正确配置\n');
        fprintf('       2. 模型 I/O 通道数不匹配\n');
        fprintf('       3. TruckSim 许可证问题\n');
        rethrow(ME);
    end

    %% ==================== 提取结果 ====================
    results = extract_results(simOut, args);

    %% ==================== 快速绘图 ====================
    if args.show_animation
        plot_results(results, args);
    end

    fprintf('[INFO] 仿真数据已提取，包含 %d 个时间步\n', length(results.t));
end


%% ==================== 方向盘转角生成函数 ====================

function steer = generate_fishhook(t, amplitude, rate, dwell)
    % 鱼钩转向工况（NHTSA 标准）
    % 先向左快速转向 → 保持 → 向右快速转向 → 保持
    steer = zeros(size(t));
    t_rise1 = amplitude / rate;  % 第一段上升时间
    t_fall  = 2 * amplitude / rate;  % 反向时间

    for i = 1:length(t)
        ti = t(i);
        if ti < 1.0
            steer(i) = 0;  % 直线行驶
        elseif ti < 1.0 + t_rise1
            steer(i) = amplitude * (ti - 1.0) / t_rise1;  % 左转上升
        elseif ti < 1.0 + t_rise1 + dwell
            steer(i) = amplitude;  % 保持
        elseif ti < 1.0 + t_rise1 + dwell + t_fall
            frac = (ti - 1.0 - t_rise1 - dwell) / t_fall;
            steer(i) = amplitude * (1 - 2 * frac);  % 反转至 -amplitude
        elseif ti < 1.0 + t_rise1 + dwell + t_fall + dwell
            steer(i) = -amplitude;  % 保持反向
        else
            steer(i) = 0;  % 回正
        end
    end
end

function steer = generate_step_steer(t, amplitude, rate, hold_time)
    % 阶跃转向工况
    steer = zeros(size(t));
    t_rise = amplitude / rate;

    for i = 1:length(t)
        ti = t(i);
        if ti < 1.0
            steer(i) = 0;
        elseif ti < 1.0 + t_rise
            steer(i) = amplitude * (ti - 1.0) / t_rise;
        elseif ti < 1.0 + t_rise + hold_time
            steer(i) = amplitude;
        else
            steer(i) = 0;
        end
    end
end

function steer = generate_dlc_steer(t, speed, offset, sections)
    % 双移线工况（ISO 3888），基于单点预瞄驾驶员模型
    % 使用正弦函数近似理想的路径跟踪转向
    steer = zeros(size(t));

    % 简化处理：使用分段正弦输入模拟双移线转向
    % 实际应用中可由 TruckSim 内部的驾驶员模型执行路径跟踪
    L = sum(sections);  % 总长度
    T = L / speed;       % 通过时间

    freq = 0.4;  % 转向频率 [Hz]
    for i = 1:length(t)
        ti = t(i);
        if ti >= 1.0 && ti <= 1.0 + T
            phase = (ti - 1.0) / T;
            % 双正弦波形模拟先左后右的变道
            steer(i) = 150 * (sin(2*pi*phase) - 0.5*sin(4*pi*phase));
        elseif ti > 1.0 + T
            steer(i) = 0;
        end
    end
end


%% ==================== 结果提取函数 ====================

function results = extract_results(simOut, args)
    % 从 Simulink 输出中提取关键状态变量
    % 数据结构需根据实际 TruckSim Export 通道映射调整

    results.t = simOut.tout;
    n = length(results.t);

    % 尝试提取 TruckSim 输出的标准通道
    % 通道映射取决于 TruckSim 中的 Export 配置
    try
        y = simOut.yout;
        % TruckSim 典型输出通道顺序（需与 TruckSim Export 配置对应）:
        % 1: Vx (纵向车速)
        % 2: Ay (侧向加速度)
        % 3: AVz (横摆角速度)
        % 4: Roll (侧倾角)
        % 5: AVx_Roll (侧倾角速度)
        % 6: Steer_SW (方向盘转角)
        % 7: Ax (纵向加速度)
        % 8: Fz_L1 (左前轮垂向力)
        % 9: Fz_R1 (右前轮垂向力)
        % 10: Fz_L2 (左后轮垂向力)
        % ...

        if isa(y, 'timeseries')
            results.Vx     = y.Data(:, 1);
            results.Ay     = y.Data(:, 2);
            results.AVz    = y.Data(:, 3);
            results.Roll   = y.Data(:, 4);
            results.AVx    = y.Data(:, 5);
            results.Steer  = y.Data(:, 6);
            results.Ax     = y.Data(:, 7);
        else
            % 如果输出是结构体
            results.raw = y;
            warning('请检查 TruckSim Export 通道映射');
        end
    catch ME
        warning('结果提取需要根据实际 TruckSim 输出配置调整: %s', ME.message);
        results.raw = simOut;
    end

    % 记录工况信息
    results.maneuver       = args.maneuver;
    results.speed_kmh      = args.speed;
    results.superelevation = args.superelevation;
    results.with_sloshing  = args.with_sloshing;
end


%% ==================== 结果绘图函数 ====================

function plot_results(results, args)
    figure('Name', sprintf('联合仿真结果 - %s @ %.0f km/h', ...
        args.maneuver, args.speed), 'Position', [100, 100, 1200, 800]);

    subplot(3, 2, 1);
    plot(results.t, results.Ay);
    xlabel('时间 [s]'); ylabel('侧向加速度 [m/s²]');
    title('侧向加速度'); grid on;

    subplot(3, 2, 2);
    plot(results.t, results.AVz * 180/pi);
    xlabel('时间 [s]'); ylabel('横摆角速度 [deg/s]');
    title('横摆角速度'); grid on;

    subplot(3, 2, 3);
    plot(results.t, results.Roll * 180/pi);
    xlabel('时间 [s]'); ylabel('侧倾角 [deg]');
    title('车身侧倾角'); grid on;

    subplot(3, 2, 4);
    plot(results.t, results.Steer);
    xlabel('时间 [s]'); ylabel('方向盘转角 [deg]');
    title('方向盘转角'); grid on;

    subplot(3, 2, 5);
    plot(results.t, results.Vx * 3.6);
    xlabel('时间 [s]'); ylabel('车速 [km/h]');
    title('纵向车速'); grid on;

    subplot(3, 2, 6);
    plot(results.t, results.Ax);
    xlabel('时间 [s]'); ylabel('纵向加速度 [m/s²]');
    title('纵向加速度'); grid on;

    sgtitle(sprintf('工况: %s | 车速: %.0f km/h | 横坡: %.0f%% | 晃动: %s', ...
        args.maneuver, args.speed, args.superelevation, ...
        ternary(args.with_sloshing, '开', '关')));
end


%% ==================== 辅助函数 ====================

function out = ternary(cond, a, b)
    if cond, out = a; else, out = b; end
end

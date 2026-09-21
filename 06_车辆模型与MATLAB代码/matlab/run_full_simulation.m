%% run_full_simulation.m —— 完整离线仿真：7-DOF车辆 + LDP晃动 + LTR/TTR标签
%  不依赖TruckSim，纯MATLAB实现，直接产出LSTM训练数据集
%  运行: run_full_simulation

function run_full_simulation()
    %% ==================== 1. 车辆参数 ====================
    p.m1 = 7500;    p.m2  = 26500;   % 牵引车/挂车质量 [kg]
    p.Iz1 = 18000;  p.Iz2 = 85000;   % 横摆惯量 [kg·m²]
    p.Ix1 = 4500;   p.Ix2 = 12000;   % 侧倾惯量 [kg·m²]
    p.a1 = 1.5;     p.b1  = 2.3;     % 前轴/后轴距CG [m]
    p.a2 = 4.2;     p.b2  = 4.3;     % 挂车轴距CG [m]
    p.c  = 0.3;     p.d   = 1.15;    % 第五轮位置 [m], 高度 [m]
    p.h1 = 1.10;    p.h2  = 1.80;    % CG高度 [m]
    p.hc = 1.5;                        % 侧倾中心高度 [m]
    p.Cf = 180000;  p.Cr  = 250000;   % 轮胎侧偏刚度 [N/rad]
    p.Ct = 600000;                     % 挂车三轴等效侧偏刚度
    p.K_roll1 = 200000; p.K_roll2 = 480000; % 侧倾刚度 [N·m/rad]
    p.C_roll1 = 15000;  p.C_roll2 = 30000;  % 侧倾阻尼 [N·m·s/rad]
    p.g  = 9.81;
    p.tw1 = 1.86;   p.tw2 = 1.86;     % 轮距 [m]

    %% ==================== 2. LDP 双摆参数 ====================
    cargo_mass = 20000;
    ldp.w1 = 4.22; ldp.z1 = 0.07; ldp.m1 = 0.75*cargo_mass;
    ldp.L1 = 0.55; ldp.h1 = 0.40;
    ldp.w2 = 7.38; ldp.z2 = 0.05; ldp.m2 = 0.25*cargo_mass;
    ldp.L2 = 0.18; ldp.h2 = 0.25;
    ldp.g  = 9.81;
    ldp.x  = [0;0;0;0];  % [θ1, dθ1, θ2, dθ2]

    %% ==================== 3. 仿真参数 ====================
    dt    = 0.001;   % 仿真步长 1ms
    t_end = 20;      % 仿真时长
    t     = 0:dt:t_end;
    N     = length(t);
    output_step = 0.01;  % 100Hz输出
    output_skip = round(output_step / dt);

    %% ==================== 4. 工况列表 ====================
    % 格式: {工况名, 车速km/h, 方向盘幅值deg, 工况类型}
    maneuvers = {
        'Fishhook_60kmh',   60, 270, 'fishhook';
        'Fishhook_80kmh',   80, 270, 'fishhook';
        'Fishhook_100kmh',  100, 270, 'fishhook';
        'StepSteer_60_120', 60, 120, 'step';
        'StepSteer_60_180', 60, 180, 'step';
        'StepSteer_80_120', 80, 120, 'step';
        'StepSteer_80_180', 80, 180, 'step';
        'StepSteer_100_120',100, 120, 'step';
        'DLC_60kmh',       60, 150, 'dlc';
        'DLC_80kmh',       80, 150, 'dlc';
        'DLC_100kmh',      100, 150, 'dlc';
    };
    n_maneuvers = size(maneuvers, 1);

    %% ==================== 5. 批量仿真 ====================
    fprintf('========== 七自由度+LDP 批量仿真 ==========\n');
    fprintf('工况数: %d\n', n_maneuvers);
    fprintf('仿真步长: %.0f ms, 时长: %.0f s\n', dt*1000, t_end);
    fprintf('========================================\n\n');

    all_data = cell(n_maneuvers, 1);

    for m = 1:n_maneuvers
        name  = maneuvers{m,1};
        speed = maneuvers{m,2};
        amp   = maneuvers{m,3};
        type  = maneuvers{m,4};

        fprintf('[%02d/%02d] %s ... ', m, n_maneuvers, name);

        Vx = speed / 3.6;  % km/h -> m/s

        % 生成方向盘转角
        delta = zeros(1, N);
        switch type
            case 'fishhook'
                delta = gen_fishhook(t, amp, 720, 0.25);
            case 'step'
                delta = gen_step(t, amp, 1000, 5.0);
            case 'dlc'
                delta = gen_dlc(t, amp, Vx);
        end

        % 初始化状态
        x_veh = zeros(7, 1);  % [Vy1, r1, phi1, dphi1, Gamma, phi2, dphi2]
        ldp.x = [0;0;0;0];

        % 存储
        store = struct();
        out_idx = 0;
        store.t = zeros(ceil(N/output_skip), 1);
        store.Vx = store.t; store.Ay = store.t; store.AVz = store.t;
        store.Roll1 = store.t; store.Roll2 = store.t;
        store.Delta = store.t; store.LTR = store.t;
        store.Fy_slosh = store.t; store.Mx_slosh = store.t;
        store.theta1 = store.t; store.theta2 = store.t;

        % 仿真循环
        for i = 1:N
            ti = t(i);
            d_i = delta(i);

            % 计算侧向加速度（用于LDP激励）
            Ay_tank = x_veh(1) + Vx*x_veh(2);  % Vy_dot_approx ≈ Vy/tau + Vx*r
            % 更好的估算：使用状态
            Ay_est = (p.Cf*(x_veh(1) + p.a1*x_veh(2))/(Vx+1e-3) + ...
                      p.Cr*(x_veh(1) - p.b1*x_veh(2))/(Vx+1e-3)) / (p.m1 + p.m2);

            % LDP 更新 (RK2)
            for sub = 1:5  % 子步细化
                dldp = ldp_deriv(ldp.x, Ay_est, ldp);
                ldp.x = ldp.x + dldp * (dt/5);
                % 角度限幅
                ldp.x(1) = max(-0.5, min(0.5, ldp.x(1)));
                ldp.x(3) = max(-0.5, min(0.5, ldp.x(3)));
            end

            % LDP 输出力/力矩
            Fy_slosh = -ldp.m1*(ldp.g*ldp.x(1) + 2*ldp.z1*ldp.w1*ldp.L1*ldp.x(2)) ...
                       -ldp.m2*(ldp.g*ldp.x(3) + 2*ldp.z2*ldp.w2*ldp.L2*ldp.x(4));
            Mx_slosh = ldp.m1*ldp.g*ldp.h1*ldp.x(1) + ldp.m2*ldp.g*ldp.h2*ldp.x(3);

            % 车辆动力学更新 (RK2)
            u = [Vx; d_i*pi/180; Fy_slosh; Mx_slosh];
            dx1 = vehicle_7dof(ti, x_veh, u, p);
            x_mid = x_veh + dx1 * (dt/2);
            dx2 = vehicle_7dof(ti+dt/2, x_mid, u, p);
            x_veh = x_veh + (dx1 + dx2) * (dt/2);

            % 限幅
            x_veh(3) = max(-0.7, min(0.7, x_veh(3)));
            x_veh(6) = max(-0.7, min(0.7, x_veh(6)));

            % 记录
            if mod(i-1, output_skip) == 0
                out_idx = out_idx + 1;
                store.t(out_idx)      = ti;
                store.Vx(out_idx)     = Vx * 3.6;
                store.Ay(out_idx)     = Ay_est;
                store.AVz(out_idx)    = x_veh(2) * 180/pi;
                store.Roll1(out_idx)  = x_veh(3) * 180/pi;
                store.Roll2(out_idx)  = x_veh(6) * 180/pi;
                store.Delta(out_idx)  = d_i;
                store.Fy_slosh(out_idx) = Fy_slosh;
                store.Mx_slosh(out_idx) = Mx_slosh;
                store.theta1(out_idx) = ldp.x(1) * 180/pi;
                store.theta2(out_idx) = ldp.x(3) * 180/pi;

                % 实时LTR（基于侧倾角估算）
                store.LTR(out_idx) = abs(x_veh(6)) / (p.m2*p.g*p.tw2/(2*p.K_roll2 + 1));
            end
        end

        % 截断
        fn = fieldnames(store);
        for f = 1:length(fn)
            store.(fn{f}) = store.(fn{f})(1:out_idx);
        end

        % LTR归一化
        max_ltr = max(abs(store.LTR));
        if max_ltr > 0
            store.LTR = store.LTR / max_ltr;
        end
        store.LTR = min(1, store.LTR);
        store.LTR_class = zeros(size(store.LTR));
        store.LTR_class(abs(store.LTR) >= 0.7) = 1;
        store.LTR_class(abs(store.LTR) >= 0.9) = 2;

        % 保存
        store.name = name;
        store.speed_kmh = speed;
        store.maneuver_type = type;
        all_data{m} = store;

        max_roll = max(abs(store.Roll2));
        danger_pct = 100 * sum(store.LTR_class >= 1) / length(store.LTR_class);
        fprintf('MaxRoll=%.1fdeg, Danger=%.0f%%, SloshFy=%.0fN\n', ...
            max_roll, danger_pct, max(abs(store.Fy_slosh)));
    end

    %% ==================== 6. 构建LSTM训练数据集 ====================
    fprintf('\n========== 构建LSTM训练数据集 ==========\n');

    lookback = 50; horizon = 10;
    X_all = {}; Y_all = {};

    for m = 1:n_maneuvers
        s = all_data{m};
        n = length(s.t);

        % 特征矩阵
        F = [s.Ay, s.AVz, s.Roll1, s.Roll2, s.Vx, s.Delta, s.theta1, s.theta2];
        L = s.LTR;

        % 滑动窗口
        seq_len = lookback + horizon;
        if n < seq_len, continue; end

        n_seq = n - seq_len + 1;
        X_seq = zeros(n_seq, lookback, 8);
        Y_seq = zeros(n_seq, horizon);

        for i = 1:n_seq
            X_seq(i,:,:) = F(i:i+lookback-1, :);
            Y_seq(i,:)   = L(i+lookback:i+lookback+horizon-1);
        end

        X_all{end+1} = X_seq;
        Y_all{end+1} = Y_seq;
    end

    X = cat(1, X_all{:});
    Y = cat(1, Y_all{:});

    % 归一化
    X_flat = reshape(X, [size(X,1)*lookback, 8]);
    x_mean = mean(X_flat, 1);
    x_std  = std(X_flat, 0, 1);
    x_std(x_std < 1e-6) = 1;
    X_norm = (X - reshape(x_mean, [1,1,8])) ./ reshape(x_std, [1,1,8]);

    % 数据集划分
    n_total = size(X, 1);
    perm = randperm(n_total);
    X_norm = X_norm(perm,:,:); Y = Y(perm,:);
    n_train = round(0.7*n_total); n_val = round(0.15*n_total);

    dataset.train.X = X_norm(1:n_train,:,:);
    dataset.train.Y = Y(1:n_train,:);
    dataset.val.X   = X_norm(n_train+1:n_train+n_val,:,:);
    dataset.val.Y   = Y(n_train+1:n_train+n_val,:);
    dataset.test.X  = X_norm(n_train+n_val+1:end,:,:);
    dataset.test.Y  = Y(n_train+n_val+1:end,:);

    dataset.x_mean = x_mean; dataset.x_std = x_std;
    dataset.lookback = lookback; dataset.horizon = horizon;
    dataset.feature_names = {'Ay','AVz','Roll1','Roll2','Vx','Delta','theta1','theta2'};

    % 保存
    out_dir = fileparts(mfilename('fullpath'));
    out_dir = fullfile(out_dir, '..', 'simulation_data');
    if ~exist(out_dir, 'dir'), mkdir(out_dir); end

    save(fullfile(out_dir, 'training_dataset.mat'), 'dataset', '-v7.3');
    save(fullfile(out_dir, 'all_runs.mat'), 'all_data', '-v7.3');

    fprintf('总样本: %d | 训练:%d 验证:%d 测试:%d\n', ...
        n_total, n_train, n_val, n_total-n_train-n_val);
    fprintf('特征: %s\n', strjoin(dataset.feature_names, ', '));
    fprintf('数据集已保存至: %s\n', fullfile(out_dir, 'training_dataset.mat'));
    fprintf('========================================\n');
end

%% ==================== LDP 导数函数 ====================
function dx = ldp_deriv(x, Ay, ldp)
    % x = [theta1; dtheta1; theta2; dtheta2]
    dx = zeros(4,1);
    dx(1) = x(2);
    dx(2) = -ldp.w1^2*x(1) - 2*ldp.z1*ldp.w1*x(2) - Ay/ldp.L1;
    dx(3) = x(4);
    dx(4) = -ldp.w2^2*x(3) - 2*ldp.z2*ldp.w2*x(4) - Ay/ldp.L2;
end

%% ==================== 工况生成函数 ====================
function d = gen_fishhook(t, amp, rate, dwell)
    d = zeros(size(t));
    t_rise = amp / rate;
    t_rev = 2 * amp / rate;
    for i = 1:length(t)
        ti = t(i);
        if ti < 1, d(i) = 0;
        elseif ti < 1+t_rise, d(i) = amp * (ti-1)/t_rise;
        elseif ti < 1+t_rise+dwell, d(i) = amp;
        elseif ti < 1+t_rise+dwell+t_rev, d(i) = amp*(1-2*(ti-1-t_rise-dwell)/t_rev);
        elseif ti < 1+t_rise+dwell+t_rev+dwell, d(i) = -amp;
        else d(i) = 0;
        end
    end
end

function d = gen_step(t, amp, rate, hold)
    d = zeros(size(t));
    t_rise = amp / rate;
    for i = 1:length(t)
        ti = t(i);
        if ti < 1, d(i) = 0;
        elseif ti < 1+t_rise, d(i) = amp*(ti-1)/t_rise;
        elseif ti < 1+t_rise+hold, d(i) = amp;
        else d(i) = 0;
        end
    end
end

function d = gen_dlc(t, amp, Vx)
    d = zeros(size(t));
    L = 110; T = L / Vx;
    for i = 1:length(t)
        ti = t(i);
        if ti >= 1 && ti <= 1+T
            phase = (ti-1)/T;
            d(i) = amp * (sin(2*pi*phase) - 0.5*sin(4*pi*phase));
        end
    end
end

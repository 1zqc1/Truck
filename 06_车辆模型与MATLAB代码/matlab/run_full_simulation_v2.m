%% run_full_simulation_v2.m —— 完整仿真框架 v2
%  新增: 道路横坡(超高)叠加 + 50+工况 + TTR标签
%  运行: run_full_simulation_v2

function run_full_simulation_v2()
    close all; rng(42);

    %% ==================== 车辆参数 ====================
    p.m1 = 7500;    p.m2  = 26500;
    p.Iz1= 18000;   p.Iz2 = 85000;
    p.Ix1= 4500;    p.Ix2 = 12000;
    p.a1 = 1.5;     p.b1  = 2.3;
    p.a2 = 4.2;     p.b2  = 4.3;
    p.c  = 0.3;     p.d   = 1.15;
    p.h1 = 1.10;    p.h2  = 1.80;
    p.Cf = 180000;  p.Cr  = 250000;
    p.Ct = 600000;
    p.K1 = 2000000;   p.K2  = 3500000;   % 侧倾刚度 [N·m/rad] (三轴挂车~350万)
    p.C1 = 30000;     p.C2  = 60000;     % 侧倾阻尼 [N·m·s/rad]
    p.g  = 9.81;      p.tw  = 1.86;
    p.roll_threshold = 25 * pi/180;

    %% ==================== LDP 参数 ====================
    cm = 20000;
    ldp.w1=4.22; ldp.z1=0.07; ldp.m1=0.75*cm; ldp.L1=0.55; ldp.h1=0.40;
    ldp.w2=7.38; ldp.z2=0.05; ldp.m2=0.25*cm; ldp.L2=0.18; ldp.h2=0.25;
    ldp.g =9.81;

    %% ==================== 工况生成 ====================
    speeds = [40, 50, 60, 70, 80, 90, 100];   % km/h (加入低速安全工况)
    supers = [-6, -4, -2, 0, 2, 4, 6];       % 道路横坡 %
    fishhook_amps = [90, 150, 200, 270];       % 鱼钩幅值 (加入小角度)
    step_amps    = [30, 60, 90, 120, 180];      % 阶跃幅值 (加入安全小角度)
    dlc_amps     = [60, 120, 150, 180];         % 双移线幅值

    scenario_list = {};
    for sp = speeds
        for su = supers
            for fa = fishhook_amps
                scenario_list{end+1} = struct('type','fishhook','speed',sp,...
                    'super',su,'amp',fa,'name',sprintf('FH_%d_%+d_%d',sp,su,fa));
            end
            for sa = step_amps
                scenario_list{end+1} = struct('type','step','speed',sp,...
                    'super',su,'amp',sa,'name',sprintf('SS_%d_%+d_%d',sp,su,sa));
            end
            for da = dlc_amps
                scenario_list{end+1} = struct('type','dlc','speed',sp,...
                    'super',su,'amp',da,'name',sprintf('DLC_%d_%+d_%d',sp,su,da));
            end
        end
    end

    n_scenarios = length(scenario_list);
    fprintf('========== 批量仿真: %d 工况 ==========\n', n_scenarios);
    fprintf('车速: %s km/h\n', mat2str(speeds));
    fprintf('横坡: %s %%\n', mat2str(supers));
    fprintf('工况: 鱼钩x%d + 阶跃x%d + 双移线x%d\n', ...
        length(fishhook_amps)*length(supers), ...
        length(step_amps)*length(supers), ...
        length(dlc_amps)*length(supers));

    %% ==================== 仿真参数 ====================
    dt = 0.001;  t_end = 20;  t = 0:dt:t_end;  N = length(t);
    ostep = 0.01;  oskip = round(ostep/dt);
    all_data = cell(n_scenarios, 1);

    %% ==================== 批量仿真 ====================
    tic;
    for s = 1:n_scenarios
        sc = scenario_list{s};
        Vx = sc.speed / 3.6;
        super_rad = atan(sc.super / 100);

        % 生成方向盘转角
        switch sc.type
            case 'fishhook'
                delta = gen_fishhook(t, sc.amp, 720, 0.25);
            case 'step'
                delta = gen_step(t, sc.amp, 1000, 5.0);
            case 'dlc'
                delta = gen_dlc(t, sc.amp, Vx);
        end

        % 初始化
        xv = zeros(7,1);  lx = zeros(4,1);
        store = init_store(ceil(N/oskip));

        for i = 1:N
            d_i = delta(i);

            % 估算侧向加速度（含横坡贡献: g·sin(super)）
            Ay_est = (p.Cf*(xv(1)+p.a1*xv(2))/(Vx+1e-3) + ...
                      p.Cr*(xv(1)-p.b1*xv(2))/(Vx+1e-3)) / (p.m1+p.m2) ...
                      + p.g*sin(super_rad);

            % LDP 更新
            for sub = 1:5
                dxl = ldp_deriv(lx, Ay_est, ldp);
                lx = lx + dxl*(dt/5);
                lx(1)=max(-0.5,min(0.5,lx(1))); lx(3)=max(-0.5,min(0.5,lx(3)));
            end

            Fy_s = -ldp.m1*(ldp.g*lx(1)+2*ldp.z1*ldp.w1*ldp.L1*lx(2)) ...
                   -ldp.m2*(ldp.g*lx(3)+2*ldp.z2*ldp.w2*ldp.L2*lx(4));
            Mx_s = ldp.m1*ldp.g*ldp.h1*lx(1) + ldp.m2*ldp.g*ldp.h2*lx(3);

            % 车辆动力学
            u = [Vx; d_i*pi/180; Fy_s; Mx_s; super_rad];
            dx1 = vehicle_7dof_v2(0, xv, u, p);
            xm = xv + dx1*(dt/2);
            dx2 = vehicle_7dof_v2(dt/2, xm, u, p);
            xv = xv + (dx1+dx2)*(dt/2);
            xv(3)=max(-0.7,min(0.7,xv(3))); xv(6)=max(-0.7,min(0.7,xv(6)));

            % 记录
            if mod(i-1, oskip) == 0
                store = append_store(store, i, oskip, t(i), Vx, xv, d_i, ...
                    Fy_s, Mx_s, lx, Ay_est, p, super_rad);
            end
        end
        store = finalize_store(store);
        store.name = sc.name; store.type = sc.type;
        store.speed = sc.speed; store.super = sc.super;
        all_data{s} = store;

        if mod(s, 20) == 0
            fprintf('  [%d/%d] 耗时%.1fs\n', s, n_scenarios, toc);
        end
    end
    elapsed = toc;
    fprintf('仿真完成: %d工况 / %.0f秒\n', n_scenarios, elapsed);

    %% ==================== 构建LSTM数据集 ====================
    fprintf('\n========== LSTM训练数据集 ==========\n');
    lookback = 50; horizon = 10;
    X_all = {}; Y_ltr = {}; Y_ttr = {}; Y_cls = {};

    for s = 1:n_scenarios
        d = all_data{s};
        n = length(d.t);
        F = [d.Ay, d.AVz, d.Roll2, d.Vx, d.Delta, d.theta1, d.theta2, d.dRoll2];
        seq_len = lookback + horizon;
        if n < seq_len, continue; end
        n_seq = n - seq_len + 1;
        X = zeros(n_seq, lookback, 8);
        Yl = zeros(n_seq, horizon); Yt = zeros(n_seq, horizon);
        for i = 1:n_seq
            X(i,:,:) = F(i:i+lookback-1, :);
            Yl(i,:)  = d.LTR(i+lookback:i+lookback+horizon-1);
            Yt(i,:)  = d.TTR(i+lookback:i+lookback+horizon-1);
        end
        X_all{end+1} = X; Y_ltr{end+1} = Yl; Y_ttr{end+1} = Yt;
    end

    X = cat(1, X_all{:}); Y_ltr = cat(1, Y_ltr{:}); Y_ttr = cat(1, Y_ttr{:});
    Y_cls = zeros(size(Y_ltr));
    Y_cls(abs(Y_ltr) >= 0.7) = 1;
    Y_cls(abs(Y_ltr) >= 0.9) = 2;

    % 归一化
    Xf = reshape(X, [size(X,1)*lookback, 8]);
    xm = mean(Xf,1); xs = std(Xf,0,1); xs(xs<1e-6)=1;
    X = (X - reshape(xm,[1,1,8])) ./ reshape(xs,[1,1,8]);

    % 划分
    n_total = size(X,1); perm = randperm(n_total);
    X=X(perm,:,:); Y_ltr=Y_ltr(perm,:); Y_ttr=Y_ttr(perm,:); Y_cls=Y_cls(perm,:);
    nt = round(0.7*n_total); nv = round(0.15*n_total);

    dataset.train.X = X(1:nt,:,:); dataset.train.Y_ltr = Y_ltr(1:nt,:);
    dataset.train.Y_ttr = Y_ttr(1:nt,:);   dataset.train.Y_cls = Y_cls(1:nt,:);
    dataset.val.X = X(nt+1:nt+nv,:,:);     dataset.val.Y_ltr = Y_ltr(nt+1:nt+nv,:);
    dataset.val.Y_ttr = Y_ttr(nt+1:nt+nv,:); dataset.val.Y_cls = Y_cls(nt+1:nt+nv,:);
    dataset.test.X = X(nt+nv+1:end,:,:);   dataset.test.Y_ltr = Y_ltr(nt+nv+1:end,:);
    dataset.test.Y_ttr = Y_ttr(nt+nv+1:end,:); dataset.test.Y_cls = Y_cls(nt+nv+1:end,:);
    dataset.x_mean = xm; dataset.x_std = xs;
    dataset.lookback = lookback; dataset.horizon = horizon;
    dataset.feat_names = {'Ay','AVz','Roll2','Vx','Delta','theta1','theta2','dRoll2'};

    out_dir = fullfile(fileparts(mfilename('fullpath')), '..', 'simulation_data');
    if ~exist(out_dir,'dir'), mkdir(out_dir); end
    save(fullfile(out_dir,'training_dataset.mat'), 'dataset', '-v7.3');
    save(fullfile(out_dir,'all_runs.mat'), 'all_data', '-v7.3');

    fprintf('总样本: %d | 训练:%d 验证:%d 测试:%d\n', n_total, nt, nv, n_total-nt-nv);
    fprintf('特征: %s\n', strjoin(dataset.feat_names, ', '));
    fprintf('危险占比(class≥1): %.1f%%\n', 100*sum(Y_cls(:)>=1)/numel(Y_cls));
    fprintf('已保存: %s\n', fullfile(out_dir,'training_dataset.mat'));
end

%% ==================== 车辆模型 (含超高) ====================
function dx = vehicle_7dof_v2(~, x, u, p)
    Vy1=x(1); r1=x(2); phi1=x(3); dphi1=x(4);
    Gamma=x(5); phi2=x(6); dphi2=x(7);
    Vx=u(1); delta=u(2); Fy_s=u(3); Mx_s=u(4); super=u(5);

    Vy2 = Vy1 - r1*(p.c+p.a2);
    Gd = r1 - (Vy1-r1*p.c)/(p.a2+p.b2);
    if abs(Gamma) > 0.1, Gd = 0; end

    af = (Vy1+p.a1*r1)/(Vx+1e-3) - delta;
    ar = (Vy1-p.b1*r1)/(Vx+1e-3);
    at = (Vy2-p.b2*(r1+Gd))/(Vx+1e-3);

    Fyf=p.Cf*af; Fyr=p.Cr*ar; Fyt=p.Ct*at;

    h1e = p.h1*cos(phi1); h2e = p.h2*cos(phi2);
    g_lat = p.g*sin(super);  % 横坡贡献

    ddphi1 = (p.m1*p.g*h1e*sin(phi1) + p.m1*(x(1)+Vx*r1+g_lat)*h1e - p.K1*phi1 - p.C1*dphi1) / p.Ix1;
    ddphi2 = (p.m2*p.g*h2e*sin(phi2) + p.m2*(Vy2+Vx*(r1+Gd)+g_lat)*h2e - p.K2*phi2 - p.C2*dphi2 + Mx_s) / p.Ix2;
    dVy1 = (Fyf*cos(delta)+Fyr-p.m1*Vx*r1 - p.m2*(Vy1-r1*p.c)*(r1+Gd) + Fy_s) / (p.m1+p.m2*0.5);
    dr1  = (p.a1*Fyf*cos(delta)-p.b1*Fyr+p.c*Fyt*cos(Gamma)+Fy_s*(p.c+p.a2)) / p.Iz1;

    dx=zeros(7,1);
    dx(1)=dVy1; dx(2)=dr1; dx(3)=dphi1; dx(4)=ddphi1;
    dx(5)=Gd;    dx(6)=dphi2; dx(7)=ddphi2;
end

%% ==================== LDP ====================
function dx = ldp_deriv(x, Ay, ldp)
    dx=zeros(4,1);
    dx(1)=x(2); dx(2)=-ldp.w1^2*x(1)-2*ldp.z1*ldp.w1*x(2)-Ay/ldp.L1;
    dx(3)=x(4); dx(4)=-ldp.w2^2*x(3)-2*ldp.z2*ldp.w2*x(4)-Ay/ldp.L2;
end

%% ==================== 存储 ====================
function s = init_store(n)
    s = struct(); s.n = 0; s.max = n;
    f = {'t','Vx','Ay','AVz','Roll2','dRoll2','Delta','LTR','TTR','Fy_s','Mx_s','theta1','theta2'};
    for k=1:length(f), s.(f{k})=zeros(n,1); end
end

function s = append_store(s, i, oskip, ti, Vx, xv, d_i, Fy_s, Mx_s, lx, Ay_est, p, super)
    s.n = s.n + 1;  idx = s.n;
    s.t(idx)=ti; s.Vx(idx)=Vx*3.6; s.Ay(idx)=Ay_est;
    s.AVz(idx)=xv(2)*180/pi; s.Roll2(idx)=xv(6)*180/pi;
    s.dRoll2(idx)=xv(7)*180/pi; s.Delta(idx)=d_i;
    s.Fy_s(idx)=Fy_s; s.Mx_s(idx)=Mx_s;
    s.theta1(idx)=lx(1)*180/pi; s.theta2(idx)=lx(3)*180/pi;
    % LTR = 2*Ay*h_cg / (g*tw)  (标准简化公式，基于侧向加速度)
    Ay_eff = abs(Ay_est - p.g*sin(super));  % 扣除横坡贡献
    ltr_raw = 2 * Ay_eff * p.h2 / (p.g * p.tw);
    s.LTR(idx) = min(1, max(0, ltr_raw));
    % TTR 估算
    roll_th = p.roll_threshold;
    if abs(xv(7)) > 0.001 && abs(xv(6)) < roll_th
        s.TTR(idx) = min(3.0, (roll_th-abs(xv(6)))/abs(xv(7)));
    elseif abs(xv(6)) >= roll_th
        s.TTR(idx) = 0;
    else
        s.TTR(idx) = 3.0;
    end
end

function s = finalize_store(s)
    f = fieldnames(s);
    for k=1:length(f)
        if isnumeric(s.(f{k})) && length(s.(f{k})) == s.max
            s.(f{k}) = s.(f{k})(1:s.n);
        end
    end
    s.max = s.n;
end

%% ==================== 工况生成 ====================
function d = gen_fishhook(t, amp, rate, dwell)
    d=zeros(size(t)); tr=amp/rate; trev=2*amp/rate;
    for i=1:length(t)
        ti=t(i);
        if ti<1, d(i)=0;
        elseif ti<1+tr, d(i)=amp*(ti-1)/tr;
        elseif ti<1+tr+dwell, d(i)=amp;
        elseif ti<1+tr+dwell+trev, d(i)=amp*(1-2*(ti-1-tr-dwell)/trev);
        elseif ti<1+tr+dwell+trev+dwell, d(i)=-amp;
        else d(i)=0; end
    end
end

function d = gen_step(t, amp, rate, hold)
    d=zeros(size(t)); tr=amp/rate;
    for i=1:length(t)
        ti=t(i);
        if ti<1, d(i)=0; elseif ti<1+tr, d(i)=amp*(ti-1)/tr;
        elseif ti<1+tr+hold, d(i)=amp; else d(i)=0; end
    end
end

function d = gen_dlc(t, amp, Vx)
    d=zeros(size(t)); L=110; T=L/Vx;
    for i=1:length(t)
        ti=t(i);
        if ti>=1&&ti<=1+T, ph=(ti-1)/T; d(i)=amp*(sin(2*pi*ph)-0.5*sin(4*pi*ph)); end
    end
end

%% run_ablation.m —— 消融实验: 液体晃动对侧翻预测的影响
%  设计: 使用7-DOF模型生成安全工况数据(避免数值发散)
%        同一场景跑两遍: LDP开启 vs LDP关闭(Fy_s=0,Mx_s=0)
%        用相同5特征+相同LSTM架构训练, 对比预测性能
%  运行: run_ablation

function run_ablation()
    close all; rng(42);
    out_dir = fullfile(fileparts(mfilename('fullpath')), '..', 'simulation_data');

    %% ==================== 车辆参数 ====================
    p.m1 = 7500;    p.m2  = 26500;   p.Iz1= 18000;   p.Iz2 = 85000;
    p.Ix1= 4500;    p.Ix2 = 12000;   p.a1 = 1.5;     p.b1  = 2.3;
    p.a2 = 4.2;     p.b2  = 4.3;     p.c  = 0.3;     p.d   = 1.15;
    p.h1 = 1.10;    p.h2  = 1.80;    p.Cf = 180000;  p.Cr  = 250000;
    p.Ct = 600000;  p.K1 = 2000000;  p.K2  = 3500000;
    p.C1 = 30000;   p.C2  = 60000;   p.g  = 9.81;    p.tw  = 1.86;

    cm = 20000;
    ldp.w1=4.22; ldp.z1=0.07; ldp.m1=0.75*cm; ldp.L1=0.55; ldp.h1=0.40;
    ldp.w2=7.38; ldp.z2=0.05; ldp.m2=0.25*cm; ldp.L2=0.18; ldp.h2=0.25;
    ldp.g =9.81;

    %% ==================== 安全工况(低速+小转角=稳定仿真) ====================
    speeds = [40, 50, 60, 70, 80];       % km/h
    supers = [-2, 0, 2];                 % 横坡%
    step_amps = [30, 60, 90, 120];       % 转向幅值(≤120°避免翻车发散)
    dlc_amps  = [30, 60, 90, 120];

    scenario_list = {};
    for sp = speeds
        for su = supers
            for sa = step_amps
                scenario_list{end+1} = struct('type','step','speed',sp,...
                    'super',su,'amp',sa);
            end
            for da = dlc_amps
                scenario_list{end+1} = struct('type','dlc','speed',sp,...
                    'super',su,'amp',da);
            end
        end
    end
    n_scenarios = length(scenario_list);
    fprintf('========== 消融仿真: %d 安全工况 ==========\n', n_scenarios);

    dt = 0.001; t_end = 15; t = 0:dt:t_end; N_len = length(t);
    ostep = 0.01; oskip = round(ostep/dt);
    n_out = ceil(N_len/oskip);

    lookback = 50; horizon = 10; seq_len = lookback + horizon;

    %% 预分配
    data_on  = cell(n_scenarios, 1);  % LDP开启
    data_off = cell(n_scenarios, 1);  % LDP关闭

    tic;
    for s = 1:n_scenarios
        sc = scenario_list{s};
        Vx = sc.speed / 3.6;
        super_rad = atan(sc.super / 100);

        if strcmp(sc.type, 'step')
            delta = gen_step(t, sc.amp, 1000, 5.0);
        else
            delta = gen_dlc(t, sc.amp, Vx);
        end

        % ---- 跑两次: LDP开启 vs LDP关闭 ----
        for mode = 1:2
            use_slosh = (mode == 1);
            xv = zeros(7,1); lx = zeros(4,1);
            store_t = zeros(n_out,1); store_ay = zeros(n_out,1);
            store_avz = zeros(n_out,1); store_roll = zeros(n_out,1);
            store_vx = zeros(n_out,1); store_delta = zeros(n_out,1);
            store_ltr = zeros(n_out,1); idx = 0;

            for i = 1:N_len
                d_i = delta(i);

                % 限制Vy1和r1防止数值发散
                xv(1) = max(-10, min(10, xv(1)));
                xv(2) = max(-2, min(2, xv(2)));

                Ay_est = (p.Cf*(xv(1)+p.a1*xv(2))/(Vx+1e-3) + ...
                          p.Cr*(xv(1)-p.b1*xv(2))/(Vx+1e-3)) / (p.m1+p.m2) ...
                          + p.g*sin(super_rad);

                Fy_s = 0; Mx_s = 0;
                if use_slosh
                    for sub = 1:5
                        dxl = ldp_deriv(lx, Ay_est, ldp);
                        lx = lx + dxl*(dt/5);
                        lx(1)=max(-0.5,min(0.5,lx(1)));
                        lx(3)=max(-0.5,min(0.5,lx(3)));
                    end
                    Fy_s = -ldp.m1*(ldp.g*lx(1)+2*ldp.z1*ldp.w1*ldp.L1*lx(2)) ...
                           -ldp.m2*(ldp.g*lx(3)+2*ldp.z2*ldp.w2*ldp.L2*lx(4));
                    Mx_s = ldp.m1*ldp.g*ldp.h1*lx(1) + ldp.m2*ldp.g*ldp.h2*lx(3);
                end

                u = [Vx; d_i*pi/180; Fy_s; Mx_s; super_rad];
                dx1 = vehicle_7dof_v2(0, xv, u, p);
                xm = xv + dx1*(dt/2);
                dx2 = vehicle_7dof_v2(dt/2, xm, u, p);
                xv = xv + (dx1+dx2)*(dt/2);
                xv(3)=max(-0.7,min(0.7,xv(3)));
                xv(6)=max(-0.7,min(0.7,xv(6)));

                if mod(i-1, oskip) == 0
                    idx = idx + 1;
                    store_t(idx) = t(i);
                    store_vx(idx) = Vx * 3.6;
                    store_ay(idx) = Ay_est;
                    store_avz(idx) = xv(2) * 180/pi;
                    store_roll(idx) = xv(6) * 180/pi;
                    store_delta(idx) = d_i;
                    Ay_eff = abs(Ay_est - p.g*sin(super_rad));
                    store_ltr(idx) = min(1, max(0, 2 * Ay_eff * p.h2 / (p.g * p.tw)));
                end
            end

            % 构建序列
            if idx >= seq_len
                F = [store_ay(1:idx), store_avz(1:idx), store_roll(1:idx), ...
                     store_vx(1:idx), store_delta(1:idx)];
                L = store_ltr(1:idx);
                n_seq = idx - seq_len + 1;
                X_seq = zeros(n_seq, lookback, 5);
                Y_seq = zeros(n_seq, horizon);
                for j = 1:n_seq
                    X_seq(j,:,:) = F(j:j+lookback-1, :);
                    Y_seq(j,:) = L(j+lookback:j+lookback+horizon-1)';
                end
            else
                X_seq = []; Y_seq = [];
            end

            if mode == 1
                data_on{s}  = struct('X', X_seq, 'Y', Y_seq);
            else
                data_off{s} = struct('X', X_seq, 'Y', Y_seq);
            end
        end

        if mod(s, 15) == 0
            fprintf('  [%d/%d] 耗时%.1fs\n', s, n_scenarios, toc);
        end
    end
    fprintf('仿真完成: %d工况 x 2模式 / %.0f秒\n', n_scenarios, toc);

    %% 合并序列
    X_on = []; Y_on = []; X_off = []; Y_off = [];
    for s = 1:n_scenarios
        if ~isempty(data_on{s}.X)
            X_on  = cat(1, X_on,  data_on{s}.X);
            Y_on  = cat(1, Y_on,  data_on{s}.Y);
            X_off = cat(1, X_off, data_off{s}.X);
            Y_off = cat(1, Y_off, data_off{s}.Y);
        end
    end

    % 移除NaN
    ok_on  = ~any(any(isnan(X_on),3),2)  & ~any(isnan(Y_on),2);
    ok_off = ~any(any(isnan(X_off),3),2) & ~any(isnan(Y_off),2);
    ok = ok_on & ok_off;
    X_on = X_on(ok,:,:); Y_on = Y_on(ok,:); X_off = X_off(ok,:,:); Y_off = Y_off(ok,:);

    % 归一化(分别对两组数据)
    function [X_norm, mu, sg] = normalize_data(X_arr)
        Ns = size(X_arr,1); L = size(X_arr,2); F = size(X_arr,3);
        Xf = reshape(X_arr, [Ns*L, F]);
        mu = mean(Xf,1); sg = std(Xf,0,1); sg(sg<1e-6)=1;
        X_norm = (X_arr - reshape(mu,[1,1,F])) ./ reshape(sg,[1,1,F]);
    end
    [X_on,  ~, ~] = normalize_data(X_on);
    [X_off, ~, ~] = normalize_data(X_off);

    n_total = size(X_on,1);
    fprintf('有效样本: %d (移除NaN: %d)\n', n_total, sum(~ok));

    if n_total < 100
        fprintf('ERROR: 样本不足!\n'); return;
    end

    % 划分
    perm = randperm(n_total);
    X_on=X_on(perm,:,:); Y_on=Y_on(perm,:);
    X_off=X_off(perm,:,:); Y_off=Y_off(perm,:);
    nt = round(0.7*n_total); nv = round(0.15*n_total);
    fprintf('划分: 训练%d 验证%d 测试%d\n', nt, nv, n_total-nt-nv);

    %% 训练
    function [rmse, r2, f1_val, acc] = train_one(X_arr, Y_arr, label)
        function [Xc, Yc] = to_seq(X3d, Y3d)
            Ns = size(X3d,1); L = size(X3d,2); F = size(X3d,3);
            Xc = cell(Ns,1);
            for ii = 1:Ns
                Xc{ii} = reshape(X3d(ii,:,:), L, F)';
            end
            Yc = Y3d(:, end);
        end

        Xt = X_arr(1:nt,:,:); Yt = Y_arr(1:nt,:);
        danger = abs(Yt(:,end)) >= 0.7;
        n_d = sum(danger); n_s = sum(~danger);
        if n_d > 0 && n_s > 0
            n_rep = max(0, round(n_s * 0.3 / 0.7) - n_d);
            if n_rep > 0
                d_idx = find(danger);
                rep_idx = d_idx(randi(n_d, n_rep, 1));
                Xt = cat(1, Xt, Xt(rep_idx,:,:));
                Yt = cat(1, Yt, Yt(rep_idx,:));
            end
        end

        [Xtr, Ytr] = to_seq(Xt, Yt);
        [Xva, Yva] = to_seq(X_arr(nt+1:nt+nv,:,:), Y_arr(nt+1:nt+nv,:));
        [Xte, Yte] = to_seq(X_arr(nt+nv+1:end,:,:), Y_arr(nt+nv+1:end,:));

        if isempty(Xtr), rmse=inf; r2=-inf; f1_val=0; acc=0; return; end

        layers = [
            sequenceInputLayer(5)
            lstmLayer(64, 'OutputMode', 'last')
            dropoutLayer(0.2)
            fullyConnectedLayer(16)
            reluLayer
            fullyConnectedLayer(1)
            regressionLayer
        ];

        vf = max(1, floor(length(Xtr)/64));
        options = trainingOptions('adam', ...
            'MaxEpochs', 50, 'MiniBatchSize', 64, ...
            'ValidationData', {Xva, Yva}, ...
            'ValidationFrequency', vf, ...
            'InitialLearnRate', 0.001, ...
            'LearnRateSchedule', 'piecewise', ...
            'LearnRateDropFactor', 0.5, 'LearnRateDropPeriod', 15, ...
            'Shuffle', 'every-epoch', 'Plots', 'none', ...
            'Verbose', false, 'ExecutionEnvironment', 'auto');

        net = trainNetwork(Xtr, Ytr, layers, options);

        Yp = predict(net, Xte); Yp = Yp(:)'; Yt = Yte(:)';
        rmse = sqrt(mean((Yp-Yt).^2));
        r2 = 1 - sum((Yt-Yp).^2)/sum((Yt-mean(Yt)).^2);
        yt = abs(Yt) >= 0.7; yp = abs(Yp) >= 0.7;
        acc = sum(yt==yp)/length(yt);
        pre = sum(yt&yp)/(sum(yp)+1e-6);
        rec = sum(yt&yp)/(sum(yt)+1e-6);
        f1_val = 2*pre*rec/(pre+rec+1e-6);
        fprintf('  %s: RMSE=%.4f R²=%.4f Acc=%.1f%% F1=%.3f\n', label, rmse, r2, 100*acc, f1_val);
    end

    fprintf('\n========== 消融训练 ==========\n');
    [rmse_on,  r2_on,  f1_on,  acc_on]  = train_one(X_on,  Y_on,  '含液体晃动');
    [rmse_off, r2_off, f1_off, acc_off] = train_one(X_off, Y_off, '无液体晃动');

    fprintf('\n========== 消融实验结果 ==========\n');
    fprintf('%-15s %8s %8s %8s %8s\n', '动力学模型', 'RMSE', 'R²', 'Acc', 'F1');
    fprintf('%s\n', repmat('-',1,47));
    fprintf('%-15s %8.4f %8.4f %7.2f%% %7.3f\n', '含液体晃动', rmse_on, r2_on, 100*acc_on, f1_on);
    fprintf('%-15s %8.4f %8.4f %7.2f%% %7.3f\n', '无液体晃动', rmse_off, r2_off, 100*acc_off, f1_off);

    df1 = f1_on - f1_off;
    dacc = acc_on - acc_off;
    fprintf('\n>>> 液体晃动使预测: F1 %+.3f, Acc %+.1f%%\n', df1, 100*dacc);
    if abs(df1) < 0.02
        fprintf('>>> 结论: 液体晃动对LSTM预测性能影响不大, 模型可自适应学习晃动动力学\n');
    elseif df1 < 0
        fprintf('>>> 结论: 液体晃动略微增加预测难度(F1略降), 需更多训练数据\n');
    else
        fprintf('>>> 结论: 含液体晃动数据训练效果好, 晃动特征被隐式学习\n');
    end

    ablation = struct('with_slosh',struct('rmse',rmse_on,'r2',r2_on,'f1',f1_on,'acc',acc_on),...
        'without_slosh',struct('rmse',rmse_off,'r2',r2_off,'f1',f1_off,'acc',acc_off),...
        'delta_f1',df1,'delta_acc',dacc,'n_samples',n_total);
    save(fullfile(out_dir, 'ablation_results.mat'), 'ablation');
    fprintf('已保存: ablation_results.mat\n');
end

%% ====== 子函数 ======
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
    g_lat = p.g*sin(super);
    ddphi1 = (p.m1*p.g*h1e*sin(phi1) + p.m1*(x(1)+Vx*r1+g_lat)*h1e - p.K1*phi1 - p.C1*dphi1) / p.Ix1;
    ddphi2 = (p.m2*p.g*h2e*sin(phi2) + p.m2*(Vy2+Vx*(r1+Gd)+g_lat)*h2e - p.K2*phi2 - p.C2*dphi2 + Mx_s) / p.Ix2;
    dVy1 = (Fyf*cos(delta)+Fyr-p.m1*Vx*r1 - p.m2*(Vy1-r1*p.c)*(r1+Gd) + Fy_s) / (p.m1+p.m2*0.5);
    dr1  = (p.a1*Fyf*cos(delta)-p.b1*Fyr+p.c*Fyt*cos(Gamma)+Fy_s*(p.c+p.a2)) / p.Iz1;
    dx=zeros(7,1);
    dx(1)=dVy1; dx(2)=dr1; dx(3)=dphi1; dx(4)=ddphi1;
    dx(5)=Gd;    dx(6)=dphi2; dx(7)=ddphi2;
end

function dx = ldp_deriv(x, Ay, ldp)
    dx=zeros(4,1);
    dx(1)=x(2); dx(2)=-ldp.w1^2*x(1)-2*ldp.z1*ldp.w1*x(2)-Ay/ldp.L1;
    dx(3)=x(4); dx(4)=-ldp.w2^2*x(3)-2*ldp.z2*ldp.w2*x(4)-Ay/ldp.L2;
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

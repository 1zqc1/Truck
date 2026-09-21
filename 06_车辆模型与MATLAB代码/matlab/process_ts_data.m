%% process_ts_data.m —— 处理TruckSim CSV → LSTM数据集

function process_ts_data()
    data_dir = fullfile(fileparts(mfilename('fullpath')), '..', 'simulation_data');
    files = dir(fullfile(data_dir, 'ts_*.csv'));

    all_data = {};
    for f = 1:length(files)
        fp = fullfile(files(f).folder, files(f).name);
        T = readtable(fp, 'VariableNamingRule', 'preserve');
        cols = T.Properties.VariableNames;

        % 跳过不含Ay列的旧格式CSV
        if ~any(contains(cols, 'Ay')) || ~any(contains(cols, 'Vx'))
            fprintf('跳过(格式不兼容): %s\n', files(f).name);
            continue;
        end

        g = @(pat) find(contains(cols, pat), 1);
        gv = @(pat) T{:, g(pat)};  % get column values
        gv0 = @(pat) zeros(height(T),1);  % default to zeros
        safe_get = @(pat) conditional_get(T, cols, pat);

        t = gv('Time');
        vx = safe_get('Vx');
        ay = safe_get('Ay');
        avz = safe_get('AVz');
        roll2 = safe_get('Roll_E_2');
        sw = safe_get('Steer_SW');
        fzl = safe_get('Fz_L1') + safe_get('Fz_L2');
        fzr = safe_get('Fz_R1') + safe_get('Fz_R2');
        ltr = (fzl - fzr) ./ (fzl + fzr + 1);

        dt = mean(diff(t));
        droll = [0; diff(roll2)] / dt;
        roll_th = 25;
        ttr = 3 * ones(size(roll2));
        for i = 1:length(roll2)
            if abs(roll2(i)) >= roll_th, ttr(i) = 0;
            elseif abs(droll(i)) > 0.01
                ttr(i) = min(3, (roll_th - abs(roll2(i))) / abs(droll(i)));
            end
        end

        s.t = t; s.Vx = vx; s.Ay = ay; s.AVz = avz; s.Roll2 = roll2;
        s.Steer_SW = sw; s.LTR = ltr; s.TTR = ttr;
        s.name = strrep(files(f).name, '.csv', '');
        all_data{end+1} = s;

        fprintf('%-25s Vx=%5.1f |Ay|max=%5.2fg Roll2max=%5.1fdeg LTRmax=%5.2f\n', ...
            s.name, mean(vx,'omitnan'), max(abs(ay)), max(abs(roll2)), max(abs(ltr)));
    end

    %% LSTM序列构建
    lookback = 50; horizon = 10;
    X_all = {}; Y_all = {};

    for d = 1:length(all_data)
        s = all_data{d};
        F = [s.Ay, s.AVz, s.Roll2, s.Vx, s.Steer_SW];
        L = s.LTR;
        N = size(F,1);
        if N < lookback+horizon, continue; end
        for i = 1:N-lookback-horizon+1
            X_all{end+1} = F(i:i+lookback-1, :);
            Y_all{end+1} = L(i+lookback:i+lookback+horizon-1)';
        end
    end

    N = length(X_all);
    X_arr = zeros(N, lookback, 5);
    Y_arr = zeros(N, horizon);
    for i = 1:N
        X_arr(i,:,:) = X_all{i};
        Y_arr(i,:) = Y_all{i};
    end

    % 归一化
    Xf = reshape(X_arr, [N*lookback, 5]);
    mu = mean(Xf, 1, 'omitnan');
    sg = std(Xf, 0, 1, 'omitnan');
    sg(sg < 1e-8) = 1;
    X_arr = (X_arr - reshape(mu, [1,1,5])) ./ reshape(sg, [1,1,5]);

    ok = ~any(any(isnan(X_arr),3),2) & ~any(isnan(Y_arr),2);
    X_arr = X_arr(ok,:,:); Y_arr = Y_arr(ok,:);
    N = size(X_arr,1);

    danger_pct = 100 * sum(any(abs(Y_arr) >= 0.7, 2)) / N;
    fprintf('\n有效样本:%d 危险占比:%.1f%%\n', N, danger_pct);

    rng(42); perm = randperm(N);
    X_arr = X_arr(perm,:,:); Y_arr = Y_arr(perm,:);
    nt = round(0.6*N); nv = round(0.2*N);

    dataset.train.X = X_arr(1:nt,:,:);      dataset.train.Y = Y_arr(1:nt,:);
    dataset.val.X   = X_arr(nt+1:nt+nv,:,:); dataset.val.Y   = Y_arr(nt+1:nt+nv,:);
    dataset.test.X  = X_arr(nt+nv+1:end,:,:); dataset.test.Y  = Y_arr(nt+nv+1:end,:);
    dataset.mu = mu; dataset.sg = sg; dataset.lookback = lookback; dataset.horizon = horizon;
    dataset.feat_names = {'Ay','AVz','Roll2','Vx','Steer_SW'};

    save(fullfile(data_dir, 'ts_dataset.mat'), 'dataset', '-v7.3');
    save(fullfile(data_dir, 'ts_all_runs.mat'), 'all_data', '-v7.3');
    fprintf('训练:%d 验证:%d 测试:%d\n数据集已保存\n', nt, nv, N-nt-nv);
end

function v = conditional_get(T, cols, pat)
    idx = find(contains(cols, pat), 1);
    if isempty(idx)
        v = zeros(height(T), 1);
    else
        v = T{:, idx};
    end
end

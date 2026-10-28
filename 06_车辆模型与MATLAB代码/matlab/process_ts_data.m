%% process_ts_data.m —— 处理TruckSim CSV → LSTM数据集

function process_ts_data()
    data_dir = fullfile(fileparts(mfilename('fullpath')), '..', 'simulation_data');
    files = dir(fullfile(data_dir, 'ts_*.csv'));

    all_data = {};
    for f = 1:length(files)
        fp = fullfile(files(f).folder, files(f).name);
        T = readtable(fp, 'VariableNamingRule', 'preserve');
        cols = T.Properties.VariableNames;

        required = {'Time','Vx','Ay','AVz','Roll_E_2','Steer_SW', ...
                    'Fz_L4','Fz_L5','Fz_L6','Fz_R4','Fz_R5','Fz_R6'};
        if ~all(ismember(required, cols))
            missing = required(~ismember(required, cols));
            error('ftinspect:MissingChannel', '%s: missing required columns: %s', fp, strjoin(missing, ', '));
        end
        values = T{:, required};
        if ~isnumeric(values) || any(~isfinite(values(:)))
            error('ftinspect:InvalidInput', '%s: required data must be finite numeric values.', fp);
        end
        t = values(:,1); vx = values(:,2); ay = values(:,3); avz = values(:,4);
        roll2 = values(:,5); sw = values(:,6); wheel = values(:,7:12);
        if numel(t) < 2 || any(diff(t) <= 0) || any(wheel(:) < 0)
            error('ftinspect:InvalidInput', '%s: time must increase and wheel loads must be nonnegative.', fp);
        end
        dt = mean(diff(t));
        if any(abs(diff(t) - dt) > max(1e-9, abs(dt)*1e-4))
            error('ftinspect:InvalidInput', '%s: sample spacing must be uniform.', fp);
        end
        fzl = sum(wheel(:,1:3), 2); fzr = sum(wheel(:,4:6), 2);
        if any(fzl + fzr <= 1e-6)
            error('ftinspect:InvalidInput', '%s: total trailer wheel load is zero.', fp);
        end
        ltr = (fzr - fzl) ./ (fzl + fzr);

        droll = [0; diff(roll2)] / dt;
        roll_th = 25;
        ttr = 3 * ones(size(roll2));
        for i = 1:length(roll2)
            if abs(roll2(i)) >= roll_th, ttr(i) = 0;
            elseif sign(roll2(i)) * droll(i) > 0.01
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
    runs = {};

    for d = 1:length(all_data)
        s = all_data{d};
        F = [s.Ay, s.AVz, s.Roll2, s.Vx, s.Steer_SW];
        L = s.LTR;
        N = size(F,1);
        if N < lookback+horizon
            error('ftinspect:InvalidInput', '%s: not enough samples.', s.name);
        end
        runs{end+1} = struct('name', s.name, 'features', F, 'target', L); %#ok<AGROW>
    end

    dataset = build_ts_dataset(runs, lookback, horizon, 42);
    dataset.feat_names = {'Ay','AVz','Roll2','Vx','Steer_SW'};

    save(fullfile(data_dir, 'ts_dataset.mat'), 'dataset', '-v7.3');
    save(fullfile(data_dir, 'ts_all_runs.mat'), 'all_data', '-v7.3');
    fprintf('训练:%d 验证:%d 测试:%d\n数据集已保存\n', ...
        size(dataset.train.X, 1), size(dataset.val.X, 1), size(dataset.test.X, 1));
end

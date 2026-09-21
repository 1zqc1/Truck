%% train_lstm_ts.m —— 用TruckSim真实数据训练LSTM侧翻预测
function train_lstm_ts()
    %% 加载
    df = fullfile(fileparts(mfilename('fullpath')), '..', ...
        'simulation_data', 'ts_dataset.mat');
    load(df, 'dataset');
    fprintf('数据: %d训练/%d验证/%d测试, 特征:%s\n', ...
        size(dataset.train.X,1), size(dataset.val.X,1), size(dataset.test.X,1), ...
        strjoin(dataset.feat_names, ','));

    %% 数据准备 (sequence-to-one)
    function [Xc, Yc] = to_seq(X3d, Y3d)
        N = size(X3d,1); L = size(X3d,2); F = size(X3d,3);
        Xc = cell(N,1);
        for i = 1:N
            Xc{i} = reshape(X3d(i,:,:), L, F)';  % [F x L]
        end
        Yc = Y3d(:, end);  % [N x 1] 列向量
    end

    % 平衡采样：重复危险样本使其占比~30%
    Xt = dataset.train.X; Yt = dataset.train.Y;
    danger = abs(Yt(:,end)) >= 0.7;
    safe = ~danger;
    n_danger = sum(danger); n_safe = sum(safe);
    n_repeat = max(0, round(n_safe * 0.3 / 0.7) - n_danger);
    if n_repeat > 0
        d_idx = find(danger);
        rep_idx = d_idx(randi(n_danger, n_repeat, 1));
        Xt = cat(1, Xt, Xt(rep_idx,:,:));
        Yt = cat(1, Yt, Yt(rep_idx,:));
    end
    [X_train, Y_train] = to_seq(Xt, Yt);
    [X_val,   Y_val]   = to_seq(dataset.val.X,   dataset.val.Y);
    [X_test,  Y_test]  = to_seq(dataset.test.X,  dataset.test.Y);
    danger_pct = 100 * sum(abs(Y_train)>=0.7)/length(Y_train);
    nFeat = length(dataset.feat_names);
    fprintf('序列: 训练%d(危险%.0f%%) 验证%d 测试%d\n', ...
        length(X_train), danger_pct, length(X_val), length(X_test));
    clear dataset

    %% 网络 (5特征 → LSTM64 → FC1)
    layers = [
        sequenceInputLayer(nFeat)
        lstmLayer(64, 'OutputMode', 'last')
        dropoutLayer(0.2)
        fullyConnectedLayer(16)
        reluLayer
        fullyConnectedLayer(1)
        regressionLayer
    ];

    options = trainingOptions('adam', ...
        'MaxEpochs', 80, 'MiniBatchSize', 64, ...
        'ValidationData', {X_val, Y_val}, ...
        'ValidationFrequency', round(length(X_train)/64), ...
        'InitialLearnRate', 0.001, ...
        'LearnRateSchedule', 'piecewise', ...
        'LearnRateDropFactor', 0.5, 'LearnRateDropPeriod', 20, ...
        'Shuffle', 'every-epoch', 'Plots', 'training-progress', ...
        'Verbose', true, 'ExecutionEnvironment', 'auto');

    %% 训练
    fprintf('\n========== 训练 ==========\n'); tic;
    net = trainNetwork(X_train, Y_train, layers, options);
    fprintf('完成, %.1f分\n', toc/60);

    %% 评估
    Yp = predict(net, X_test); Yp = Yp(:)'; Yt = Y_test(:)';
    rmse = sqrt(mean((Yp-Yt).^2));
    r2 = 1 - sum((Yt-Yp).^2)/sum((Yt-mean(Yt)).^2);

    yt = abs(Yt) >= 0.7; yp = abs(Yp) >= 0.7;
    acc = sum(yt==yp)/length(yt);
    pre = sum(yt&yp)/(sum(yp)+1e-6);
    rec = sum(yt&yp)/(sum(yt)+1e-6);
    f1 = 2*pre*rec/(pre+rec+1e-6);

    fprintf('\n测试: RMSE=%.4f R2=%.4f\n', rmse, r2);
    fprintf('预警: Acc=%.1f%% Prec=%.1f%% Rec=%.1f%% F1=%.3f\n', 100*acc, 100*pre, 100*rec, f1);

    %% 保存
    mf = fullfile(fileparts(mfilename('fullpath')), '..', ...
        'simulation_data', 'lstm_ts_model.mat');
    save(mf, 'net', 'rmse', 'r2', 'f1', 'acc');
    fprintf('模型已保存\n');
end

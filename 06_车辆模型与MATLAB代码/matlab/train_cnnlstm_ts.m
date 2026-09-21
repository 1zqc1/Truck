%% train_cnnlstm_ts.m —— CNN-LSTM混合模型训练（用于论文三模型对比）
%  参考: 汪佳铭等《基于CNN-LSTM的重型自卸车侧翻预警模型》表3
%  网络: Conv1D(128) → Pooling → LSTM1(64) → LSTM2(32) → FC(50) → Dropout → Output
%  使用与 train_lstm_ts.m 相同的 ts_dataset.mat 数据集

function train_cnnlstm_ts()
    %% 加载数据
    df = fullfile(fileparts(mfilename('fullpath')), '..', ...
        'simulation_data', 'ts_dataset.mat');
    load(df, 'dataset');
    fprintf('数据: %d训练/%d验证/%d测试, 特征:%s\n', ...
        size(dataset.train.X,1), size(dataset.val.X,1), size(dataset.test.X,1), ...
        strjoin(dataset.feat_names, ','));

    %% 数据准备 (sequence-to-one)
    nFeat = length(dataset.feat_names);

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
    fprintf('序列: 训练%d(危险%.0f%%) 验证%d 测试%d\n', ...
        length(X_train), danger_pct, length(X_val), length(X_test));
    clear dataset

    %% CNN-LSTM 网络
    % 汪佳铭论文表3结构: Conv1D(128,k=3,s=1)+Pool(1,s=1)+LSTM1(64)+LSTM2(32)+FC(50)+Drop(0.2)
    layers = [
        sequenceInputLayer(nFeat, 'Name', 'input')

        % 一维卷积层: 128个卷积核, 核大小3, 步长1, relu, same填充
        convolution1dLayer(3, 128, 'Padding', 'same', 'Stride', 1, 'Name', 'conv1d')
        reluLayer('Name', 'relu_conv')

        % 池化层: 核大小1, 步长1 (论文表3原样, 保持序列长度不变)
        maxPooling1dLayer(1, 'Stride', 1, 'Padding', 'same', 'Name', 'pool')

        % 第一层LSTM: 64神经元, 输出完整序列给下一层
        lstmLayer(64, 'OutputMode', 'sequence', 'Name', 'lstm1')

        % 第二层LSTM: 32神经元, 输出最后时刻
        lstmLayer(32, 'OutputMode', 'last', 'Name', 'lstm2')

        % 全连接层: 50神经元, tanh激活 (论文表3)
        fullyConnectedLayer(50, 'Name', 'fc1')
        tanhLayer('Name', 'tanh_fc')

        % Dropout: 丢失率0.2 (论文表3)
        dropoutLayer(0.2, 'Name', 'dropout')

        % 输出层: 单神经元回归 (预测LTR值)
        fullyConnectedLayer(1, 'Name', 'fc_output')
        regressionLayer('Name', 'output')
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
    fprintf('\n========== 训练 CNN-LSTM ==========\n'); tic;
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

    fprintf('\n========== CNN-LSTM 测试结果 ==========\n');
    fprintf('RMSE=%.4f  R²=%.4f\n', rmse, r2);
    fprintf('Acc=%.1f%%  Prec=%.1f%%  Rec=%.1f%%  F1=%.3f\n', 100*acc, 100*pre, 100*rec, f1);

    %% 保存
    mf = fullfile(fileparts(mfilename('fullpath')), '..', ...
        'simulation_data', 'cnnlstm_ts_model.mat');
    save(mf, 'net', 'rmse', 'r2', 'f1', 'acc');
    fprintf('模型已保存: cnnlstm_ts_model.mat\n');
end

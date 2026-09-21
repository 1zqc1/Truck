%% train_lstm.m —— LSTM 侧翻预测模型训练 v2
%  平衡采样 + 双层LSTM + 列向量Y格式

function train_lstm()
    %% 1. 加载
    df = fullfile(fileparts(mfilename('fullpath')), '..', ...
        'simulation_data', 'training_dataset.mat');
    load(df, 'dataset');
    fprintf('数据: %d训练 + %d验证 + %d测试\n', ...
        size(dataset.train.X,1), size(dataset.val.X,1), size(dataset.test.X,1));

    %% 2. 数据转换函数
    function [Xc, Yc] = to_seq(X3d, Y3d)
        N = size(X3d, 1);
        L = size(X3d, 2);
        F = size(X3d, 3);
        yv = Y3d(:, end);
        ok = ~isnan(yv);
        X3d = X3d(ok,:,:); yv = yv(ok);
        N = size(X3d, 1);
        Xc = cell(N, 1);
        for i = 1:N
            Xc{i} = reshape(X3d(i,:,:), L, F)';
        end
        Yc = yv(:);  % [N×1] 列向量
    end

    %% 3. 平衡采样
    max_smp = 100000;
    y_all = dataset.train.Y_ltr(:, end);
    safe   = find(abs(y_all) < 0.7);
    danger = find(abs(y_all) >= 0.7);
    n_each = min(max_smp/2, min(length(safe), length(danger)));
    fprintf('平衡采样: 安全%d + 危险%d = %d\n', n_each, n_each, 2*n_each);
    idx = [safe(randperm(length(safe), n_each)); ...
           danger(randperm(length(danger), n_each))];
    idx = idx(randperm(length(idx)));

    [X_train, Y_train] = to_seq(dataset.train.X(idx,:,:), dataset.train.Y_ltr(idx,:));
    [X_val,   Y_val]   = to_seq(dataset.val.X,   dataset.val.Y_ltr);
    [X_test,  Y_test]  = to_seq(dataset.test.X,  dataset.test.Y_ltr);
    fprintf('训练:%d 验证:%d 测试:%d\n', ...
        length(X_train), length(X_val), length(X_test));
    clear dataset

    %% 4. 归一化
    Xf = cell2mat(reshape(X_train, 1, []));
    mu = mean(Xf, 2); sg = std(Xf, 0, 2); sg(sg < 1e-8) = 1;
    for i = 1:length(X_train), X_train{i} = (X_train{i} - mu) ./ sg; end
    for i = 1:length(X_val),   X_val{i}   = (X_val{i}   - mu) ./ sg; end
    for i = 1:length(X_test),  X_test{i}  = (X_test{i}  - mu) ./ sg; end
    fprintf('归一化完成\n');

    %% 5. 网络
    layers = [
        sequenceInputLayer(8)
        lstmLayer(128, 'OutputMode', 'last')
        dropoutLayer(0.3)
        lstmLayer(64, 'OutputMode', 'last')
        dropoutLayer(0.3)
        fullyConnectedLayer(32)
        reluLayer
        fullyConnectedLayer(1)
        regressionLayer
    ];

    %% 6. 训练选项
    options = trainingOptions('adam', ...
        'MaxEpochs', 100, 'MiniBatchSize', 128, ...
        'ValidationData', {X_val, Y_val}, ...
        'ValidationFrequency', round(length(X_train)/128), ...
        'InitialLearnRate', 0.0005, 'LearnRateSchedule', 'piecewise', ...
        'LearnRateDropFactor', 0.5, 'LearnRateDropPeriod', 25, ...
        'Shuffle', 'every-epoch', 'Plots', 'training-progress', ...
        'Verbose', true, 'ExecutionEnvironment', 'auto');

    %% 7. 训练
    fprintf('\n========== 训练 ==========\n');
    tic;
    net = trainNetwork(X_train, Y_train, layers, options);
    fprintf('完成, %.1f分\n', toc/60);

    %% 8. 评估
    Yp = predict(net, X_test); Yp = Yp(:)'; Yt = Y_test(:)';
    rmse = sqrt(mean((Yp-Yt).^2));
    mae  = mean(abs(Yp-Yt));
    r2   = 1 - sum((Yt-Yp).^2)/sum((Yt-mean(Yt)).^2);
    fprintf('\n测试: RMSE=%.4f MAE=%.4f R²=%.4f\n', rmse, mae, r2);

    yt = abs(Yt) >= 0.7; yp = abs(Yp) >= 0.7;
    acc = sum(yt==yp)/length(yt);
    pre = sum(yt&yp)/(sum(yp)+1e-6);
    rec = sum(yt&yp)/(sum(yt)+1e-6);
    f1  = 2*pre*rec/(pre+rec+1e-6);
    fprintf('危险预警: Acc=%.1f%% Prec=%.1f%% Rec=%.1f%% F1=%.3f\n', ...
        100*acc, 100*pre, 100*rec, f1);

    %% 9. 绘图
    figure('Position',[100 100 800 300]);
    for i = 1:min(4, length(X_test))
        subplot(1,4,i); bar([Yt(i); Yp(i)]');
        set(gca,'XTickLabel',{'真','预'}); ylabel('LTR');
        title(sprintf('样本%d',i)); ylim([-1 1]); grid on;
    end
    sgtitle('LSTM侧翻预测');

    %% 10. 保存
    mf = fullfile(fileparts(mfilename('fullpath')), '..', ...
        'simulation_data', 'lstm_rollover_model.mat');
    save(mf, 'net', 'rmse', 'r2', 'f1', 'acc', 'mu', 'sg');
    fprintf('模型已保存: %s\n', mf);
end

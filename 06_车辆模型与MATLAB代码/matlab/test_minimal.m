%% 最小LSTM测试 —— 验证MATLAB 2022a的sequence-to-one数据格式

% 造10个虚拟样本
N = 10;
X = cell(N, 1);
for i = 1:N
    X{i} = randn(8, 50);  % 8特征 × 50步
end
Y = randn(1, N);  % 1×N 行向量，10个观测值

fprintf('X: %d cells, each [%d×%d]\n', N, size(X{1}));
fprintf('Y: [%d×%d]\n', size(Y));

layers = [
    sequenceInputLayer(8)
    lstmLayer(64, 'OutputMode', 'last')
    fullyConnectedLayer(1)
    regressionLayer
];

fprintf('\n测试1: X=cell, Y=numeric row vector [1×N]\n');
try
    options = trainingOptions('adam', 'MaxEpochs', 1, 'MiniBatchSize', 5, ...
        'Plots', 'none', 'Verbose', true);
    net = trainNetwork(X, Y, layers, options);
    fprintf('  → 成功!\n');
catch ME
    fprintf('  → 失败: %s\n', ME.message);
end

fprintf('\n测试2: X=cell, Y=numeric column vector [N×1]\n');
Y2 = Y(:);
fprintf('Y2: [%d×%d]\n', size(Y2));
try
    options = trainingOptions('adam', 'MaxEpochs', 1, 'MiniBatchSize', 5, ...
        'Plots', 'none', 'Verbose', true);
    net = trainNetwork(X, Y2, layers, options);
    fprintf('  → 成功!\n');
catch ME
    fprintf('  → 失败: %s\n', ME.message);
end

fprintf('\n测试3: X=cell, Y=cell (每个cell是标量)\n');
Y3 = num2cell(Y);
fprintf('Y3: %d cells\n', N);
try
    options = trainingOptions('adam', 'MaxEpochs', 1, 'MiniBatchSize', 5, ...
        'Plots', 'none', 'Verbose', true);
    net = trainNetwork(X, Y3, layers, options);
    fprintf('  → 成功!\n');
catch ME
    fprintf('  → 失败: %s\n', ME.message);
end

fprintf('\n测试4: Y为 [1×1×N] 3维数组\n');
Y4 = reshape(Y, 1, 1, N);
fprintf('Y4: [%d×%d×%d]\n', size(Y4));
try
    options = trainingOptions('adam', 'MaxEpochs', 1, 'MiniBatchSize', 5, ...
        'Plots', 'none', 'Verbose', true);
    net = trainNetwork(X, Y4, layers, options);
    fprintf('  → 成功!\n');
catch ME
    fprintf('  → 失败: %s\n', ME.message);
end

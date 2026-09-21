%% data_export.m —— 仿真数据导出为 LSTM 训练数据集
%  功能：
%    1. 读取所有已完成仿真工况的数据文件
%    2. 计算 LTR/TTR 标签
%    3. 构建滑动窗口时间序列样本
%    4. 数据归一化、数据集划分
%    5. 导出 .mat 和 .csv 格式
%
%  使用示例:
%    data_export;                              % 导出全部数据
%    data_export('lookback', 50, 'horizon', 10); % 指定窗口大小
%    data_export('split_ratio', [0.7, 0.15, 0.15]);  % 数据集划分比例

function [dataset] = data_export(varargin)
    %% 参数解析
    p = inputParser;
    p.addParameter('lookback', 50, @isnumeric);       % 回看窗口 [步]
    p.addParameter('horizon', 10, @isnumeric);        % 预测视野 [步]
    p.addParameter('split_ratio', [0.70, 0.15, 0.15], @isnumeric);
    p.addParameter('feature_list', {'Ay', 'AVz', 'Roll', 'AVx', 'Vx', 'Steer'}, ...
        @iscell);
    p.addParameter('label_type', 'both', @(x) ismember(x, ...
        {'ltr_regression', 'ltr_classification', 'ttr', 'both'}));
    p.addParameter('normalize', true, @islogical);
    p.addParameter('shuffle', true, @islogical);
    p.addParameter('random_seed', 42, @isnumeric);
    p.addParameter('export_csv', true, @islogical);
    p.parse(varargin{:});
    args = p.Results;

    %% 初始化
    init_params;
    rng(args.random_seed);

    %% ==================== 数据读取 ====================
    fprintf('=============================================================\n');
    fprintf('  LSTM 训练数据导出\n');
    fprintf('=============================================================\n');
    fprintf('  数据目录: %s\n', output.data_dir);

    mat_files = dir(fullfile(output.data_dir, '*.mat'));
    % 排除进度文件和失败列表
    mat_files = mat_files(~ismember({mat_files.name}, ...
        {'batch_progress.mat', 'failed_scenarios.mat', ...
         'training_dataset.mat', 'normalization_params.mat'}));

    if isempty(mat_files)
        error('未找到仿真数据文件。请先运行 run_dangerous_maneuvers。');
    end

    n_files = length(mat_files);
    fprintf('  找到 %d 个仿真数据文件\n', n_files);

    %% ==================== 构建样本序列 ====================
    all_X = {};    % 特征序列
    all_Y_reg = {};  % LTR 回归标签
    all_Y_cls = {};  % LTR 分类标签
    all_Y_ttr = {};  % TTR 标签
    all_meta = {};   % 元数据

    fprintf('\n  处理仿真数据...\n');

    for f = 1:n_files
        filepath = fullfile(mat_files(f).folder, mat_files(f).name);
        data = load(filepath);

        if ~isfield(data, 'results')
            fprintf('    [跳过] %s: 无有效数据\n', mat_files(f).name);
            continue;
        end

        % 计算标签
        labeled = calculate_labels(data.results);

        % 提取特征矩阵 [n_samples × n_features]
        X = extract_features(labeled, args.feature_list);
        n_samples = size(X, 1);

        if n_samples < args.lookback + args.horizon
            fprintf('    [跳过] %s: 样本数不足 (%d < %d)\n', ...
                mat_files(f).name, n_samples, args.lookback + args.horizon);
            continue;
        end

        % 滑动窗口切分
        [X_seq, Y_reg_seq, Y_cls_seq, Y_ttr_seq] = ...
            create_sequences(X, labeled, args.lookback, args.horizon);

        if isempty(X_seq)
            continue;
        end

        all_X{end+1}     = X_seq;
        all_Y_reg{end+1} = Y_reg_seq;
        all_Y_cls{end+1} = Y_cls_seq;
        all_Y_ttr{end+1} = Y_ttr_seq;

        % 元数据
        all_meta{end+1} = struct(...
            'filename', mat_files(f).name, ...
            'maneuver', labeled.meta.maneuver, ...
            'speed', labeled.meta.speed_kmh, ...
            'superelevation', labeled.meta.superelevation, ...
            'n_sequences', size(X_seq, 1));

        if mod(f, 10) == 0
            fprintf('    [%d/%d] 已处理\n', f, n_files);
        end
    end

    fprintf('    [%d/%d] 处理完成\n', n_files, n_files);

    %% ==================== 合并所有数据 ====================
    X_all = cat(1, all_X{:});       % [N_seq × lookback × n_features]
    Y_reg_all = cat(1, all_Y_reg{:}); % [N_seq × horizon]
    Y_cls_all = cat(1, all_Y_cls{:}); % [N_seq × horizon]
    Y_ttr_all = cat(1, all_Y_ttr{:}); % [N_seq × horizon]

    n_total = size(X_all, 1);
    fprintf('\n  总样本数: %d\n', n_total);
    fprintf('  特征维度: [%d × %d × %d]\n', ...
        n_total, args.lookback, length(args.feature_list));

    % 标签分布
    danger_ratio = sum(Y_cls_all == 2, 'all') / numel(Y_cls_all);
    warning_ratio = sum(Y_cls_all >= 1, 'all') / numel(Y_cls_all);
    fprintf('  危险标签占比 (class=2): %.2f%%\n', danger_ratio * 100);
    fprintf('  预警标签占比 (class≥1): %.2f%%\n', warning_ratio * 100);

    %% ==================== 数据归一化 ====================
    norm_params = struct();
    if args.normalize
        fprintf('\n  正在进行 Z-score 归一化...\n');

        % 对每个特征计算均值和标准差（仅用训练集）
        X_2d = reshape(X_all, [n_total * args.lookback, length(args.feature_list)]);
        norm_params.mean = mean(X_2d, 1);
        norm_params.std  = std(X_2d, 0, 1);
        norm_params.std(norm_params.std < 1e-8) = 1;  % 避免除零

        % 归一化
        X_norm = (X_all - reshape(norm_params.mean, [1, 1, length(args.feature_list)])) ...
                 ./ reshape(norm_params.std, [1, 1, length(args.feature_list)]);
        X_all = X_norm;

        % 保存归一化参数
        save(fullfile(output.data_dir, 'normalization_params.mat'), ...
            'norm_params', 'args');
        fprintf('  归一化参数已保存\n');
    end

    %% ==================== 数据集划分 ====================
    fprintf('\n  数据集划分 (训练:验证:测试 = %.0f:%.0f:%.0f)...\n', ...
        args.split_ratio(1)*100, args.split_ratio(2)*100, args.split_ratio(3)*100);

    if args.shuffle
        perm = randperm(n_total);
        X_all     = X_all(perm, :, :);
        Y_reg_all = Y_reg_all(perm, :);
        Y_cls_all = Y_cls_all(perm, :);
        Y_ttr_all = Y_ttr_all(perm, :);
    end

    n_train = round(n_total * args.split_ratio(1));
    n_val   = round(n_total * args.split_ratio(2));

    idx_train = 1:n_train;
    idx_val   = (n_train+1):(n_train+n_val);
    idx_test  = (n_train+n_val+1):n_total;

    dataset = struct();
    dataset.train.X            = X_all(idx_train, :, :);
    dataset.train.Y_ltr        = Y_reg_all(idx_train, :);
    dataset.train.Y_cls        = Y_cls_all(idx_train, :);
    dataset.train.Y_ttr        = Y_ttr_all(idx_train, :);

    dataset.val.X              = X_all(idx_val, :, :);
    dataset.val.Y_ltr          = Y_reg_all(idx_val, :);
    dataset.val.Y_cls          = Y_cls_all(idx_val, :);
    dataset.val.Y_ttr          = Y_ttr_all(idx_val, :);

    dataset.test.X             = X_all(idx_test, :, :);
    dataset.test.Y_ltr         = Y_reg_all(idx_test, :);
    dataset.test.Y_cls         = Y_cls_all(idx_test, :);
    dataset.test.Y_ttr         = Y_ttr_all(idx_test, :);

    dataset.config             = args;
    dataset.feature_names      = args.feature_list;
    dataset.norm_params        = norm_params;
    dataset.class_labels       = {'safe', 'warning', 'danger'};

    fprintf('  训练集: %d 样本\n', length(idx_train));
    fprintf('  验证集: %d 样本\n', length(idx_val));
    fprintf('  测试集: %d 样本\n', length(idx_test));

    %% ==================== 保存 .mat 文件 ====================
    mat_path = output.mat_file;
    save(mat_path, 'dataset', '-v7.3');
    fprintf('\n  ✓ .mat 文件已保存: %s\n', mat_path);

    %% ==================== 导出 CSV ====================
    if args.export_csv
        export_to_csv(dataset, output.csv_dir, args);
        fprintf('  ✓ CSV 文件已导出至: %s\n', output.csv_dir);
    end

    %% ==================== 数据集信息卡片 ====================
    fprintf('\n=============================================================\n');
    fprintf('  数据集导出完成\n');
    fprintf('=============================================================\n');
    fprintf('  特征列表: %s\n', strjoin(args.feature_list, ', '));
    fprintf('  窗口大小: 回看 %d 步, 预测 %d 步\n', args.lookback, args.horizon);
    fprintf('  训练/验证/测试: %d/%d/%d\n', ...
        length(idx_train), length(idx_val), length(idx_test));
    fprintf('  归一化: %s\n', ternary(args.normalize, 'Z-score', '无'));
    fprintf('  标签类型: %s\n', args.label_type);
    fprintf('=============================================================\n');
end


%% ==================== 特征提取 ====================

function X = extract_features(labeled, feature_list)
    n_features = length(feature_list);
    n_samples  = length(labeled.t);

    X = zeros(n_samples, n_features);
    for i = 1:n_features
        feat_name = feature_list{i};
        if isfield(labeled.features, feat_name)
            X(:, i) = labeled.features.(feat_name);
        else
            warning('特征 "%s" 不存在，填充为 0', feat_name);
        end
    end
end


%% ==================== 滑动窗口序列生成 ====================

function [X_seq, Y_reg_seq, Y_cls_seq, Y_ttr_seq] = ...
    create_sequences(X, labeled, lookback, horizon)

    n_samples = size(X, 1);
    n_features = size(X, 2);
    seq_len = lookback + horizon;

    if n_samples < seq_len
        X_seq = []; Y_reg_seq = []; Y_cls_seq = []; Y_ttr_seq = [];
        return;
    end

    n_seq = n_samples - seq_len + 1;

    % 预分配
    X_seq     = zeros(n_seq, lookback, n_features);
    Y_reg_seq = zeros(n_seq, horizon);
    Y_cls_seq = zeros(n_seq, horizon);
    Y_ttr_seq = zeros(n_seq, horizon);

    for i = 1:n_seq
        X_seq(i, :, :)     = X(i:i+lookback-1, :);
        Y_reg_seq(i, :)    = labeled.features.LTR(i+lookback:i+lookback+horizon-1);
        Y_cls_seq(i, :)    = labeled.LTR_class(i+lookback:i+lookback+horizon-1);
        Y_ttr_seq(i, :)    = labeled.TTR(i+lookback:i+lookback+horizon-1);
    end
end


%% ==================== CSV 导出 ====================

function export_to_csv(dataset, csv_dir, args)
    % 将数据集导出为 CSV（展开为 2D 表格）
    % 每个样本一行：lookback×features + horizon×label

    splits = {'train', 'val', 'test'};
    for s = 1:length(splits)
        split_name = splits{s};
        X_data = dataset.(split_name).X;
        Y_data = dataset.(split_name).Y_ltr;

        n_seq     = size(X_data, 1);
        lookback  = size(X_data, 2);
        n_feat    = size(X_data, 3);

        if isempty(X_data) || n_seq == 0
            continue;
        end

        % 构建表头
        col_names = {};
        for t = 1:lookback
            for f = 1:n_feat
                col_names{end+1} = sprintf('%s_t-%d', ...
                    args.feature_list{f}, lookback - t + 1);
            end
        end
        for h = 1:args.horizon
            col_names{end+1} = sprintf('LTR_t+%d', h);
        end

        % 构建数据矩阵
        X_flat = reshape(X_data, [n_seq, lookback * n_feat]);
        data_matrix = [X_flat, Y_data];

        % 写入 CSV
        csv_path = fullfile(csv_dir, sprintf('dataset_%s.csv', split_name));
        T = array2table(data_matrix, 'VariableNames', ...
            matlab.lang.makeValidName(col_names));
        writetable(T, csv_path);
    end

    % 导出元数据
    meta_path = fullfile(csv_dir, 'dataset_info.txt');
    fid = fopen(meta_path, 'w', 'native', 'UTF-8');
    fprintf(fid, 'LSTM 侧翻预测数据集\n');
    fprintf(fid, '生成时间: %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    fprintf(fid, '特征列表: %s\n', strjoin(args.feature_list, ', '));
    fprintf(fid, '窗口: 回看 %d 步 | 预测 %d 步\n', args.lookback, args.horizon);
    fprintf(fid, '标签: LTR (横向载荷转移率), 分类 (0=安全 1=警告 2=危险), TTR (侧翻预测时间)\n');
    fclose(fid);
end


%% ==================== 辅助 ====================

function out = ternary(cond, a, b)
    if cond, out = a; else, out = b; end
end

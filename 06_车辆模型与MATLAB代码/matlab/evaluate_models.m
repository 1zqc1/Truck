%% evaluate_models.m —— 三模型ROC/AUC对比评估
%  加载 LSTM / CNN / CNN-LSTM 三个模型，在测试集上计算ROC曲线和AUC
%  输出: ROC对比图 + AUC值 + 混淆矩阵指标汇总表
%  运行: evaluate_models

function evaluate_models()
    close all;

    data_dir = fullfile(fileparts(mfilename('fullpath')), '..', 'simulation_data');

    %% 加载数据
    load(fullfile(data_dir, 'ts_dataset.mat'), 'dataset');

    function [Xc, Yc] = to_seq(X3d, Y3d)
        N = size(X3d,1); L = size(X3d,2); F = size(X3d,3);
        Xc = cell(N,1);
        for i = 1:N
            Xc{i} = reshape(X3d(i,:,:), L, F)';  % [F x L]
        end
        Yc = Y3d(:, end);
    end
    [X_test, Y_test] = to_seq(dataset.test.X, dataset.test.Y);
    y_true = (abs(Y_test) >= 0.7)';  % 二分类标签：|LTR|≥0.7为危险，转为行向量

    %% 加载模型并预测
    model_files = {'lstm_ts_model.mat', 'cnn_ts_model.mat', 'cnnlstm_ts_model.mat'};
    model_names = {'LSTM', 'CNN', 'CNN-LSTM'};
    colors = {[0.2 0.4 0.8], [0.8 0.3 0.2], [0.2 0.7 0.3]};
    results = struct();

    for m = 1:length(model_files)
        mf = fullfile(data_dir, model_files{m});
        if ~exist(mf, 'file')
            fprintf('⚠ 模型文件不存在: %s，跳过\n', model_files{m});
            continue;
        end
        ld = load(mf, 'net');
        Yp = predict(ld.net, X_test);
        Yp = Yp(:)';
        scores = abs(Yp);  % 用|LTR_pred|作为侧翻风险得分

        Yt = Y_test(:)';
        rmse = sqrt(mean((Yp-Yt).^2));
        r2 = 1 - sum((Yt-Yp).^2)/sum((Yt-mean(Yt)).^2);

        yp_bin = scores >= 0.7;
        acc = sum(y_true==yp_bin)/length(y_true);
        pre = sum(y_true&yp_bin)/(sum(yp_bin)+1e-6);
        rec = sum(y_true&yp_bin)/(sum(y_true)+1e-6);
        f1 = 2*pre*rec/(pre+rec+1e-6);

        % ROC & AUC
        [Xroc, Yroc, T, auc] = perfcurve(double(y_true), scores, true);

        results(m).name  = model_names{m};
        results(m).rmse  = rmse;
        results(m).r2    = r2;
        results(m).acc   = acc;
        results(m).pre   = pre;
        results(m).rec   = rec;
        results(m).f1    = f1;
        results(m).auc   = auc;
        results(m).Xroc  = Xroc;
        results(m).Yroc  = Yroc;

        fprintf('%-12s RMSE=%.4f R²=%.4f Acc=%.1f%% F1=%.3f AUC=%.4f\n', ...
            model_names{m}, rmse, r2, 100*acc, f1, auc);
    end

    %% 绘制 ROC 对比图
    figure('Position', [100 100 600 500]); hold on;
    for m = 1:length(results)
        if isempty(results(m).name), continue; end
        plot(results(m).Xroc, results(m).Yroc, 'LineWidth', 2, ...
            'Color', colors{m}, 'DisplayName', ...
            sprintf('%s (AUC=%.4f)', results(m).name, results(m).auc));
    end
    plot([0 1], [0 1], 'k--', 'LineWidth', 1, 'DisplayName', '随机分类器 (AUC=0.5)');
    xlabel('假正例率 (FPR)'); ylabel('真正例率 (TPR)');
    title('ROC曲线对比 —— TruckSim测试集');
    legend('Location', 'southeast'); grid on; axis equal; xlim([0 1]); ylim([0 1]);

    % 保存图片
    fig_dir = fullfile(data_dir, 'figures');
    if ~exist(fig_dir, 'dir'), mkdir(fig_dir); end
    saveas(gcf, fullfile(fig_dir, 'roc_comparison.png'));
    fprintf('ROC图已保存: figures/roc_comparison.png\n');

    %% 绘制指标对比柱状图
    figure('Position', [750 100 700 500]);
    metrics = {'acc', 'pre', 'rec', 'f1', 'auc'};
    metric_labels = {'准确率', '精确率', '召回率', 'F1', 'AUC'};
    n_models = length(results);
    n_metrics = length(metrics);

    data = zeros(n_models, n_metrics);
    for m = 1:n_models
        for k = 1:n_metrics
            data(m, k) = results(m).(metrics{k});
        end
    end

    b = bar(data);
    set(gca, 'XTickLabel', {results.name});
    ylabel('分数'); title('三模型性能指标对比');
    legend(metric_labels, 'Location', 'northoutside', 'Orientation', 'horizontal');
    ylim([0 1.05]);
    grid on;
    for k = 1:n_metrics
        b(k).FaceColor = [0.2 0.4 0.8] + (k-1)*[0.15 0.1 -0.15];
    end
    saveas(gcf, fullfile(fig_dir, 'metrics_comparison.png'));
    fprintf('指标图已保存: figures/metrics_comparison.png\n');

    %% 汇总表
    fprintf('\n========== 三模型对比汇总 ==========\n');
    fprintf('%-12s %8s %8s %8s %8s %8s %8s\n', '模型', 'RMSE', 'R²', 'Acc', 'Prec', 'Rec', 'F1');
    fprintf('%s\n', repmat('-', 1, 68));
    for m = 1:n_models
        fprintf('%-12s %8.4f %8.4f %7.2f%% %7.2f%% %7.2f%% %7.3f\n', ...
            results(m).name, results(m).rmse, results(m).r2, ...
            100*results(m).acc, 100*results(m).pre, 100*results(m).rec, results(m).f1);
    end
    fprintf('\n');
    fprintf('%-12s %8s %8s %8s %8s %8s %8s\n', '模型', '', '', '', '', '', 'AUC');
    for m = 1:n_models
        fprintf('%-12s %8s %8s %8s %8s %8s %8.4f\n', ...
            results(m).name, '', '', '', '', '', results(m).auc);
    end

    %% 保存
    save(fullfile(data_dir, 'model_comparison.mat'), 'results');
    fprintf('\n评估结果已保存: model_comparison.mat\n');
end

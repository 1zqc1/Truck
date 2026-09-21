%% run_all_experiments.m —— 论文实验一键运行脚本
%  按顺序执行: CNN训练 → CNN-LSTM训练 → 三模型评估 → 消融实验 → 结果汇总
%  运行: run_all_experiments

function run_all_experiments()
    fprintf('=============================================================\n');
    fprintf('  半挂液罐车侧翻预警论文 —— 完整实验流程\n');
    fprintf('=============================================================\n\n');

    t_start = tic;

    %% 步骤1: 训练CNN对比模型
    fprintf('\n#################### 步骤1/4: CNN对比模型 ####################\n');
    try
        train_cnn_ts();
    catch ME
        fprintf('⚠ CNN训练失败: %s\n', ME.message);
    end

    %% 步骤2: 训练CNN-LSTM模型
    fprintf('\n#################### 步骤2/4: CNN-LSTM模型 ####################\n');
    try
        train_cnnlstm_ts();
    catch ME
        fprintf('⚠ CNN-LSTM训练失败: %s\n', ME.message);
    end

    %% 步骤3: ROC/AUC三模型评估
    fprintf('\n#################### 步骤3/4: 三模型ROC/AUC评估 ###############\n');
    try
        evaluate_models();
    catch ME
        fprintf('⚠ 评估失败: %s\n', ME.message);
    end

    %% 步骤4: 消融实验
    fprintf('\n#################### 步骤4/4: 液体晃动消融实验 ################\n');
    try
        run_ablation();
    catch ME
        fprintf('⚠ 消融实验失败: %s\n', ME.message);
    end

    %% 结果汇总
    fprintf('\n#################### 结果汇总 ####################\n');
    summarize_results();

    fprintf('\n=============================================================\n');
    fprintf('  全部实验完成! 总耗时 %.0f 分钟\n', toc(t_start)/60);
    fprintf('  输出文件:\n');
    fprintf('    simulation_data/cnn_ts_model.mat       -- CNN模型\n');
    fprintf('    simulation_data/cnnlstm_ts_model.mat   -- CNN-LSTM模型\n');
    fprintf('    simulation_data/model_comparison.mat    -- 三模型对比结果\n');
    fprintf('    simulation_data/ablation_results.mat    -- 消融实验结果\n');
    fprintf('    simulation_data/paper_summary.txt       -- 论文数据汇总\n');
    fprintf('=============================================================\n');
end

function summarize_results()
    data_dir = fullfile(fileparts(mfilename('fullpath')), '..', 'simulation_data');
    out_file = fullfile(data_dir, 'paper_summary.txt');

    fid = fopen(out_file, 'w', 'native', 'UTF-8');

    header = ['=============================================================\n', ...
              '  论文实验数据汇总\n', ...
              '  ', datestr(now, 'yyyy-mm-dd HH:MM:SS'), '\n', ...
              '=============================================================\n\n'];
    fprintf(fid, header);
    fprintf(header);

    %% 三模型对比
    mf = fullfile(data_dir, 'model_comparison.mat');
    if exist(mf, 'file')
        ld = load(mf, 'results');
        r = ld.results;

        tbl = '\n--- 三模型性能对比 (TruckSim测试集) ---\n';
        fprintf(fid, tbl); fprintf(tbl);

        hdr = sprintf('%-12s %8s %8s %8s %8s %8s %8s\n', ...
            '模型', 'RMSE', 'R²', 'Acc', 'Prec', 'Rec', 'F1');
        fprintf(fid, hdr); fprintf(hdr);
        sep = repmat('-', 1, 68);
        fprintf(fid, '%s\n', sep); fprintf('%s\n', sep);

        for m = 1:length(r)
            if isempty(r(m).name), continue; end
            line = sprintf('%-12s %8.4f %8.4f %7.2f%% %7.2f%% %7.2f%% %7.3f\n', ...
                r(m).name, r(m).rmse, r(m).r2, 100*r(m).acc, 100*r(m).pre, 100*r(m).rec, r(m).f1);
            fprintf(fid, line); fprintf(line);
        end

        auc_hdr = '\n--- AUC 对比 ---\n';
        fprintf(fid, auc_hdr); fprintf(auc_hdr);
        for m = 1:length(r)
            if isempty(r(m).name), continue; end
            line = sprintf('  %s: AUC = %.4f\n', r(m).name, r(m).auc);
            fprintf(fid, line); fprintf(line);
        end
    else
        fprintf('⚠ model_comparison.mat 不存在 (需先运行 evaluate_models)\n');
    end

    %% 消融实验结果
    af = fullfile(data_dir, 'ablation_results.mat');
    if exist(af, 'file')
        ld = load(af, 'ablation');
        a = ld.ablation;

        abl_txt = '\n--- 消融实验: 有/无液体晃动特征 ---\n';
        fprintf(fid, abl_txt); fprintf(abl_txt);

        hdr = sprintf('%-20s %8s %8s %8s %8s\n', '特征组', 'RMSE', 'R²', 'Acc', 'F1');
        fprintf(fid, hdr); fprintf(hdr);
        sep = repmat('-', 1, 52);
        fprintf(fid, '%s\n', sep); fprintf('%s\n', sep);

        lineA = sprintf('%-20s %8.4f %8.4f %7.2f%% %7.3f\n', ...
            'A组(5特征/无晃动)', a.A.rmse, a.A.r2, 100*a.A.acc, a.A.f1);
        fprintf(fid, lineA); fprintf(lineA);

        lineB = sprintf('%-20s %8.4f %8.4f %7.2f%% %7.3f\n', ...
            'B组(8特征/含晃动)', a.B.rmse, a.B.r2, 100*a.B.acc, a.B.f1);
        fprintf(fid, lineB); fprintf(lineB);

        delta_line = sprintf('\n>>> 加入液体晃动特征后: F1提升 %+.3f, Acc提升 %+.1f%%\n', ...
            a.delta_f1, 100*a.delta_acc);
        fprintf(fid, delta_line); fprintf(delta_line);
    else
        fprintf('⚠ ablation_results.mat 不存在 (需先运行 run_ablation)\n');
    end

    %% 论文直接可用的数据段落
    paper_txt = sprintf(['\n=============================================================\n', ...
        '  论文可直接引用的数据\n', ...
        '=============================================================\n\n', ...
        '实验采用TruckSim 2022与MATLAB/Simulink联合仿真平台，搭建了七自由度半挂液罐车\n', ...
        '动力学模型，并引入LDP线性等效双摆模型模拟液体晃动效应。在双移线(DLC)和阶跃转向\n', ...
        '(Step Steer)两种典型侧翻工况下，共采集14组仿真数据作为训练和测试数据集。\n\n', ...
        '以横向载荷转移率(LTR)的绝对值0.7作为侧翻预警阈值，选取侧向加速度(Ay)、横摆角\n', ...
        '速度(AVz)、挂车侧倾角(Roll2)、纵向车速(Vx)和方向盘转角(Steer_SW)共5个特征参\n', ...
        '数作为模型输入，构建了LSTM、CNN和CNN-LSTM三种神经网络模型进行侧翻预测对比。']);
    fprintf(fid, paper_txt);
    fprintf(paper_txt);

    fclose(fid);
    fprintf('\n论文数据汇总已保存: %s\n', out_file);
end

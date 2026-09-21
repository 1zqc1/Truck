%% run_dangerous_maneuvers.m —— 批量危险工况仿真脚本
%  遍历所有工况组合（车速 × 道路横坡 × 转向类型），
%  对每种组合运行 TruckSim-Simulink 联合仿真，
%  提取车身状态数据并保存。
%
%  总工况数（示例）:
%    5种车速 × 7种横坡 × (1鱼钩 + 5阶跃 + 1双移线)
%    = 5 × 7 × 7 = 245 组仿真
%
%  使用示例:
%    run_dangerous_maneuvers;                         % 运行全部
%    run_dangerous_maneuvers('speeds', [60, 80]);     % 仅指定车速
%    run_dangerous_maneuvers('start_idx', 100);       % 从第100组开始（续跑）
%    run_dangerous_maneuvers('dry_run', true);        % 干跑，仅打印不仿真

function run_dangerous_maneuvers(varargin)
    %% 参数解析
    p = inputParser;
    p.addParameter('speeds', [], @isnumeric);
    p.addParameter('superelevations', [], @isnumeric);
    p.addParameter('start_idx', 1, @isnumeric);
    p.addParameter('dry_run', false, @islogical);
    p.addParameter('with_sloshing', true, @islogical);  % 默认带液体晃动
    p.addParameter('sim_model', 'tanker_cosim', @ischar);
    p.addParameter('save_interval', 10, @isnumeric);    % 每隔N组保存一次
    p.parse(varargin{:});
    args = p.Results;

    %% 初始化
    init_params;
    warning('off', 'Simulink:Engine:OutputPortNotConnected');

    % 使用指定参数或默认参数
    if isempty(args.speeds)
        speeds = maneuvers.speeds_kmh;
    else
        speeds = args.speeds;
    end
    if isempty(args.superelevations)
        superelevations = maneuvers.superelevations;
    else
        superelevations = args.superelevations;
    end

    %% ==================== 生成全部工况列表 ====================
    fprintf('=============================================================\n');
    fprintf('  批量危险工况仿真 - 七自由度半挂液罐车联合仿真\n');
    fprintf('=============================================================\n');

    scenario_list = {};

    % --- 鱼钩工况 ---
    for spd = speeds
        for sup = superelevations
            scenario_list{end+1} = struct(...
                'type', 'fishhook', ...
                'speed', spd, ...
                'superelevation', sup, ...
                'steer_amplitude', maneuvers.fishhook.steer_amplitude, ...
                'label', sprintf('FH_%dkmh_SE%+d', spd, sup));
        end
    end

    % --- 阶跃转向工况（多种转角幅值）---
    for steer_amp = maneuvers.step_steer.steer_amplitudes
        for spd = speeds
            for sup = superelevations
                scenario_list{end+1} = struct(...
                    'type', 'step_steer', ...
                    'speed', spd, ...
                    'superelevation', sup, ...
                    'steer_amplitude', steer_amp, ...
                    'label', sprintf('SS%ddeg_%dkmh_SE%+d', steer_amp, spd, sup));
            end
        end
    end

    % --- 双移线工况 ---
    for spd = speeds
        for sup = superelevations
            scenario_list{end+1} = struct(...
                'type', 'dlc', ...
                'speed', spd, ...
                'superelevation', sup, ...
                'steer_amplitude', NaN, ...
                'label', sprintf('DLC_%dkmh_SE%+d', spd, sup));
        end
    end

    n_total   = length(scenario_list);
    n_success = 0;
    n_failed  = 0;

    fprintf('  总工况数: %d\n', n_total);
    fprintf('  车速范围: %s km/h\n', mat2str(speeds));
    fprintf('  道路横坡: %s %%\n', mat2str(superelevations));
    fprintf('  液体晃动: %s\n', ternary(args.with_sloshing, '开启', '关闭'));
    fprintf('  起始序号: %d\n', args.start_idx);
    fprintf('=============================================================\n\n');

    if args.dry_run
        fprintf('=== 干跑模式：仅打印工况列表 ===\n');
        for i = 1:n_total
            s = scenario_list{i};
            fprintf('  [%03d/%03d] %s\n', i, n_total, s.label);
        end
        return;
    end

    %% ==================== 进度文件 ====================
    progress_file = fullfile(output.data_dir, 'batch_progress.mat');
    if exist(progress_file, 'file') && args.start_idx <= 1
        load(progress_file, 'last_completed_idx');
        if exist('last_completed_idx', 'var')
            args.start_idx = last_completed_idx + 1;
            fprintf('[INFO] 从进度文件恢复，起始序号: %d\n', args.start_idx);
        end
    end

    %% ==================== 批量仿真主循环 ====================
    fprintf('\n========== 开始批量仿真 ==========\n');
    batch_start_time = tic;

    for idx = args.start_idx:n_total
        s = scenario_list{idx};

        fprintf('\n--- [%03d/%03d] %s ---\n', idx, n_total, s.label);
        fprintf('    类型: %s, 车速: %d km/h, 横坡: %+d%%, 转角: %s deg\n', ...
            s.type, s.speed, s.superelevation, ...
            ternary(isnan(s.steer_amplitude), 'N/A', num2str(s.steer_amplitude)));

        try
            results = run_cosim(...
                'maneuver', s.type, ...
                'speed', s.speed, ...
                'superelevation', s.superelevation, ...
                'steer_amplitude', s.steer_amplitude, ...
                'with_sloshing', args.with_sloshing, ...
                'sim_model', args.sim_model, ...
                'show_animation', false);

            % 保存单次结果
            save_file = fullfile(output.data_dir, [s.label, '.mat']);
            parsave(save_file, results, s);
            n_success = n_success + 1;
            fprintf('    ✓ 成功，数据已保存: %s\n', save_file);

        catch ME
            n_failed = n_failed + 1;
            fprintf('    ✗ 失败: %s\n', ME.message);

            % 记录失败工况
            failed_file = fullfile(output.data_dir, 'failed_scenarios.mat');
            if exist(failed_file, 'file')
                load(failed_file, 'failed_list');
            else
                failed_list = {};
            end
            failed_list{end+1} = struct('idx', idx, 'label', s.label, ...
                'error', ME.message, 'timestamp', datetime('now'));
            save(failed_file, 'failed_list');
        end

        % 定期保存进度
        if mod(idx, args.save_interval) == 0
            last_completed_idx = idx;
            save(progress_file, 'last_completed_idx');
            elapsed = toc(batch_start_time);
            avg_time = elapsed / (idx - args.start_idx + 1);
            remaining = avg_time * (n_total - idx);
            fprintf('\n  [进度] %d/%d | 成功: %d | 失败: %d |', ...
                idx, n_total, n_success, n_failed);
            fprintf(' 预估剩余: %.0f 分钟\n', remaining/60);
        end
    end

    batch_elapsed = toc(batch_start_time);

    %% ==================== 完成汇总 ====================
    fprintf('\n=============================================================\n');
    fprintf('  批量仿真完成！\n');
    fprintf('=============================================================\n');
    fprintf('  总工况数:   %d\n', n_total);
    fprintf('  成功:      %d\n', n_success);
    fprintf('  失败:      %d\n', n_failed);
    fprintf('  总耗时:    %.1f 分钟 (%.1f 小时)\n', batch_elapsed/60, batch_elapsed/3600);
    fprintf('  数据目录:  %s\n', output.data_dir);
    fprintf('=============================================================\n');

    % 清理进度文件
    if n_success == n_total && exist(progress_file, 'file')
        delete(progress_file);
        fprintf('  所有工况完成，进度文件已清理。\n');
    end

    %% 生成批量仿真报告
    generate_report(scenario_list, n_success, n_failed, batch_elapsed, output.data_dir);
end


%% ==================== 辅助函数 ====================

function parsave(filename, results, scenario)
    save(filename, 'results', 'scenario', '-v7.3');
end

function out = ternary(cond, a, b)
    if cond, out = a; else, out = b; end
end

function generate_report(scenario_list, n_success, n_failed, elapsed, data_dir)
    report_file = fullfile(data_dir, 'batch_report.txt');
    fid = fopen(report_file, 'w', 'native', 'UTF-8');

    fprintf(fid, '=============================================================\n');
    fprintf(fid, '  批量仿真报告\n');
    fprintf(fid, '  生成时间: %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    fprintf(fid, '=============================================================\n');
    fprintf(fid, '  总工况数: %d\n', length(scenario_list));
    fprintf(fid, '  成功:     %d\n', n_success);
    fprintf(fid, '  失败:     %d\n', n_failed);
    fprintf(fid, '  总耗时:   %.1f 分钟\n', elapsed/60);
    fprintf(fid, '  数据目录: %s\n', data_dir);
    fprintf(fid, '=============================================================\n');

    % 按工况类型统计
    types = unique(cellfun(@(x) x.type, scenario_list, 'UniformOutput', false));
    for i = 1:length(types)
        count = sum(cellfun(@(x) strcmp(x.type, types{i}), scenario_list));
        fprintf(fid, '  %s: %d 组\n', types{i}, count);
    end

    fprintf(fid, '=============================================================\n');
    fprintf(fid, '  注：仿真数据文件命名规则:\n');
    fprintf(fid, '    FH_<车速>kmh_SE<横坡>      → 鱼钩工况\n');
    fprintf(fid, '    SS<转角>deg_<车速>kmh_SE<横坡> → 阶跃转向\n');
    fprintf(fid, '    DLC_<车速>kmh_SE<横坡>     → 双移线工况\n');
    fprintf(fid, '=============================================================\n');

    fclose(fid);
    fprintf('[INFO] 报告已保存: %s\n', report_file);
end

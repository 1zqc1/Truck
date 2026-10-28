%% calculate_labels.m —— LTR/TTR 标签计算
%  从联合仿真结果中实时计算横向载荷转移率 (LTR) 和侧翻预测时间 (TTR)
%  作为后续 LSTM 侧翻预测模型的训练标签
%
%  输入: 单次仿真的 results 结构体（来自 run_cosim）
%  输出: 带标签的数据结构体
%
%  使用示例:
%    labeled_data = calculate_labels(results);

function labeled = calculate_labels(results)
    init_params;

    %% ==================== 数据准备 ====================
    t      = results.t;
    n      = length(t);
    if n < 2 || any(~isfinite(t)) || any(diff(t) <= 0)
        error('ftinspect:InvalidTime', 'Time must contain at least two finite, strictly increasing samples.');
    end
    dt     = mean(diff(t));
    if any(abs(diff(t) - dt) > max(1e-9, abs(dt)*1e-4))
        error('ftinspect:InvalidTime', 'Time samples must be uniformly spaced.');
    end

    % 提取关键信号
    Ay     = get_field(results, 'Ay', zeros(n, 1));
    AVz    = get_field(results, 'AVz', zeros(n, 1));
    Roll   = get_field(results, 'Roll', []);
    AVx    = get_field(results, 'AVx', []);
    if numel(Roll) ~= n || numel(AVx) ~= n || any(~isfinite(Roll)) || any(~isfinite(AVx))
        error('ftinspect:MissingFeature', 'Finite Roll and AVx signals are required.');
    end
    Vx     = get_field(results, 'Vx', ones(n, 1) * results.speed_kmh / 3.6);
    Steer  = get_field(results, 'Steer', zeros(n, 1));
    Ax     = get_field(results, 'Ax', zeros(n, 1));

    %% ==================== LTR 实时计算 ====================
    % LTR = (FzL - FzR) / (FzL + FzR)
    % 挂车第 4–6 轴六轮合计；不代表单轴最大 LTR
    % LTR ∈ [-1, 1]，|LTR| → 1 表示载荷完全转移

    [~, LTR] = compute_ltr(results, n);

    % 平滑 LTR 信号（去除高频噪声）
    smooth_window = max(1, round(0.1 / dt));
    LTR_smooth = movmean(LTR, [smooth_window - 1, 0]);  % 因果窗口

    %% ==================== TTR 实时计算 ====================
    % 基于侧倾角线性外推计算到侧翻的时间
    % TTR = (φ_threshold - φ_current) / φ̇
    % 仅当侧倾角速度 > 0（正在向危险方向倾斜）时计算

    roll_threshold = labels.ttr.roll_threshold;  % 侧翻临界侧倾角 [rad]
    ttr_horizon    = labels.ttr.horizon;          % 预测范围 [s]
    TTR            = inf(n, 1);                    % 默认无穷大

    for i = 1:n
        if abs(Roll(i)) < roll_threshold
            if sign(Roll(i)) * AVx(i) > 0.001  % 朝当前侧危险方向倾斜
                % 线性外推剩余时间
                remaining = (roll_threshold - abs(Roll(i))) / abs(AVx(i));
                % 截断到预测范围内
                TTR(i) = min(remaining, ttr_horizon);
            else
                TTR(i) = ttr_horizon;  % 无侧倾趋势
            end
        else
            TTR(i) = 0;  % 已侧翻
        end
    end

    % 平滑 TTR
    TTR_smooth = movmean(TTR, [smooth_window - 1, 0]);
    TTR_smooth = min(TTR_smooth, ttr_horizon);

    %% ==================== LTR 分类标签 ====================
    % 0 = 安全 (|LTR| < 0.70)
    % 1 = 警告 (0.70 ≤ |LTR| < 0.90)
    % 2 = 危险 (|LTR| ≥ 0.90)
    LTR_class = zeros(n, 1);
    abs_ltr   = abs(LTR_smooth);

    LTR_class(abs_ltr >= labels.ltr.threshold_low  & ...
              abs_ltr <  labels.ltr.threshold_high) = 1;
    LTR_class(abs_ltr >= labels.ltr.threshold_high) = 2;

    %% ==================== 侧翻风险标签 ====================
    % 连续值: 0~1 之间的侧翻风险概率（用于回归任务）
    % 1 - TTR/TTR_horizon，映射为风险值
    rollover_risk = max(0, min(1, 1 - TTR_smooth / ttr_horizon));

    %% ==================== 事件检测 ====================
    % 检测侧翻事件（LTR 超过阈值的时间段）
    danger_events = detect_events(abs_ltr, labels.ltr.threshold_high, ...
        dt, 0.2);  % 最小持续 200ms

    warning_events = detect_events(abs_ltr, labels.ltr.threshold_low, ...
        dt, 0.5);  % 最小持续 500ms

    %% ==================== 组装输出 ====================
    labeled = results;  % 保留原始数据

    % 计算得到的标签
    labeled.LTR_raw       = LTR;
    labeled.LTR            = LTR_smooth;
    labeled.LTR_class      = LTR_class;
    labeled.TTR            = TTR_smooth;
    labeled.rollover_risk  = rollover_risk;
    labeled.danger_events  = danger_events;
    labeled.warning_events = warning_events;

    % 特征汇总（LSTM 模型输入候选）
    labeled.features.t        = t;
    labeled.features.Ay       = Ay;
    labeled.features.AVz      = AVz;
    labeled.features.Roll     = Roll;
    labeled.features.AVx      = AVx;
    labeled.features.Vx       = Vx;
    labeled.features.Steer    = Steer;
    labeled.features.Ax       = Ax;
    labeled.features.LTR      = LTR_smooth;
    labeled.features.rollover_risk = rollover_risk;

    % 标签
    labeled.labels.ltr_regression   = LTR_smooth;     % 回归标签
    labeled.labels.ltr_classification = LTR_class;     % 分类标签
    labeled.labels.ttr               = TTR_smooth;      % TTR 标签
    labeled.labels.risk              = rollover_risk;   % 风险标签

    % 元数据
    labeled.meta.maneuver        = results.maneuver;
    labeled.meta.speed_kmh       = results.speed_kmh;
    labeled.meta.superelevation  = results.superelevation;
    labeled.meta.sample_rate     = 1/dt;
    labeled.meta.n_samples       = n;
    labeled.meta.duration        = t(end);

    %% ==================== 输出汇总 ====================
    fprintf('\n========== 标签计算结果 ==========\n');
    fprintf('  工况: %s @ %.0f km/h\n', ...
        results.maneuver, results.speed_kmh);
    fprintf('  数据点数: %d\n', n);
    fprintf('  采样率:   %.0f Hz\n', 1/dt);
    fprintf('  ---------------------------------\n');
    fprintf('  LTR 统计:\n');
    fprintf('    |LTR| 最大值:    %.3f\n', max(abs(LTR_smooth)));
    fprintf('    |LTR| 平均值:    %.3f\n', mean(abs(LTR_smooth)));
    fprintf('    危险占比 (|LTR|≥%.2f): %.1f%%\n', ...
        labels.ltr.threshold_high, ...
        100 * sum(LTR_class == 2) / n);
    fprintf('    警告占比 (|LTR|≥%.2f): %.1f%%\n', ...
        labels.ltr.threshold_low, ...
        100 * sum(LTR_class >= 1) / n);
    fprintf('  ---------------------------------\n');
    fprintf('  TTR 统计:\n');
    fprintf('    TTR 最小值:      %.3f s\n', min(TTR_smooth));
    fprintf('    TTR < 1s 占比:   %.1f%%\n', ...
        100 * sum(TTR_smooth < 1.0) / n);
    fprintf('  ---------------------------------\n');
    fprintf('  危险事件数: %d\n', size(danger_events, 1));
    fprintf('  预警事件数: %d\n', size(warning_events, 1));
    fprintf('===================================\n');
end


%% ==================== LTR 计算函数 ====================

function [LTR_per_axle, LTR_max] = compute_ltr(results, n)
    % 必须使用已核对轴位和符号的挂车六轮竖向力，不以侧倾角替代。

    % 尝试获取垂向力数据
    names = {'Fz_L4','Fz_L5','Fz_L6','Fz_R4','Fz_R5','Fz_R6'};
    wheel = zeros(n, 6);
    for j = 1:numel(names)
        v = get_field(results, names{j}, []);
        if numel(v) ~= n || any(~isfinite(v)) || any(v < 0)
            error('ftinspect:MissingWheelLoad', 'Required finite nonnegative wheel load %s is missing or invalid.', names{j});
        end
        wheel(:,j) = v(:);
    end
    sumL_trailer = sum(wheel(:,1:3), 2);
    sumR_trailer = sum(wheel(:,4:6), 2);
    if any(sumL_trailer + sumR_trailer <= 1e-6)
        error('ftinspect:InvalidWheelLoad', 'Total trailer wheel load must be positive.');
    end
    LTR_trailer = (sumR_trailer - sumL_trailer) ./ (sumR_trailer + sumL_trailer);
    LTR_per_axle = LTR_trailer;
    LTR_max = LTR_trailer;
end


%% ==================== 事件检测函数 ====================

function events = detect_events(signal, threshold, dt, min_duration)
    % 检测信号超过阈值且持续时间达标的事件
    % 输入:
    %   signal       - 信号序列
    %   threshold    - 检测阈值
    %   dt           - 采样间隔 [s]
    %   min_duration - 最小持续时间 [s]
    % 输出:
    %   events       - N×3 矩阵 [起始帧, 结束帧, 持续时间]

    above = signal >= threshold;
    min_frames = round(min_duration / dt);

    events = [];
    i = 1;
    while i <= length(above)
        if above(i)
            start_idx = i;
            while i <= length(above) && above(i)
                i = i + 1;
            end
            end_idx = i - 1;
            duration = (end_idx - start_idx + 1) * dt;

            if duration >= min_duration
                % 记录：起始帧, 结束帧, 持续时间, 峰值
                peak_val = max(signal(start_idx:end_idx));
                events = [events; start_idx, end_idx, duration, peak_val];
            end
        else
            i = i + 1;
        end
    end
end


%% ==================== 辅助函数 ====================

function val = get_field(s, fieldname, default)
    if isfield(s, fieldname) && ~isempty(s.(fieldname))
        val = s.(fieldname);
    else
        val = default;
    end
end

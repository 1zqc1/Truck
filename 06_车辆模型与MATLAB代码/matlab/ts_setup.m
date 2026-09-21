%% ts_setup.m —— 通过 COM 接口配置 TruckSim 联合仿真
%  前提：TruckSim 2022 必须已经打开

function ts_setup()
    fprintf('正在连接 TruckSim...\n');

    try
        % 连接到已运行的 TruckSim
        h = actxserver('TruckSim.Application');
        fprintf('[OK] TruckSim COM 连接成功\n');
    catch
        error('无法连接 TruckSim。请确保 TruckSim 已打开。');
    end

    % 查看可用方法
    fprintf('\n=== 当前 simfile 信息 ===\n');

    % 获取当前 simfile 路径
    cur_sim = h.GetCurrentSimfile();
    fprintf('当前 simfile: %s\n', cur_sim);

    % 查看当前 Export/Import 端口数
    ports_exp = h.GetExportPorts();
    ports_imp = h.GetImportPorts();
    fprintf('Export 端口数: %d\n', ports_exp);
    fprintf('Import 端口数: %d\n', ports_imp);

    % 如果没有端口，设置端口数
    if ports_exp == 0 && ports_imp == 0
        fprintf('\n=== 配置 Simulink I/O 端口 ===\n');

        % 设置端口数量
        h.SetExportPorts(18);
        h.SetImportPorts(3);
        fprintf('[OK] Export 端口设为 18, Import 端口设为 3\n');

        % 配置 Export 通道 (按顺序)
        export_vars = {
            'Vx_SM',        % 1. 纵向车速
            'Ay_SM',        % 2. 侧向加速度
            'AVz_SM',       % 3. 横摆角速度
            'Roll_SM',      % 4. 侧倾角
            'AVx_SM',       % 5. 侧倾角速度
            'Steer_SW',     % 6. 方向盘转角
            'Ax_SM',        % 7. 纵向加速度
            'Fz_L1',        % 8. 左前轮垂向力
            'Fz_R1',        % 9. 右前轮垂向力
            'Fz_L2',        % 10. 左后轮垂向力
            'Fz_R2',        % 11. 右后轮垂向力
            'Fz_L3',        % 12. 挂车左1轴
            'Fz_R3',        % 13. 挂车右1轴
            'Fz_L4',        % 14. 挂车左2轴
            'Fz_R4',        % 15. 挂车右2轴
            'Fz_L5',        % 16. 挂车左3轴
            'Fz_R5',        % 17. 挂车右3轴
            'Ay_T'          % 18. 挂车侧向加速度
        };

        for i = 1:length(export_vars)
            h.SetExportVariable(i, export_vars{i});
            fprintf('  Export[%d] = %s\n', i, export_vars{i});
        end

        % 配置 Import 通道
        import_vars = {
            'IMP_FY_T',     % 1. 罐体横向力
            'IMP_MX_T',     % 2. 罐体侧倾力矩
            'IMP_STEER_SW'  % 3. 方向盘转角
        };

        for i = 1:length(import_vars)
            h.SetImportVariable(i, import_vars{i});
            fprintf('  Import[%d] = %s\n', i, import_vars{i});
        end

        fprintf('[OK] I/O 通道配置完成\n');
    end

    % 设置仿真步长
    fprintf('\n=== 仿真设置 ===\n');
    h.SetStepSize(0.001);  % 1ms
    fprintf('[OK] 仿真步长: 0.001 s\n');

    % 保存 simfile
    h.SaveSimfile();
    fprintf('[OK] simfile 已保存\n');

    % 生成 Simulink 模型
    fprintf('\n=== 生成 Simulink 模型 ===\n');
    sim_model_path = 'C:\Users\LENOVO\tanker_trucksim_cosim\matlab\tanker_ts';
    h.SendToSimulink(sim_model_path);
    fprintf('[OK] Simulink 模型已生成: %s.slx\n', sim_model_path);

    fprintf('\n========== 配置完成 ==========\n');
end

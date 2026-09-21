%% setup_complete.m —— 完整环境配置 + 联合仿真模型
%  运行此脚本完成全流程配置

function setup_complete()
    fprintf('========== TruckSim-Simulink 联合仿真环境配置 ==========\n');

    %% 1. 添加 TruckSim MATLAB 路径
    ts_matlab = 'D:\Program Files (x86)\TruckSim\TruckSim2022.1_Prog\Programs\solvers\Matlab';
    addpath(ts_matlab);
    fprintf('[OK] 添加路径: %s\n', ts_matlab);

    % 验证 MEX 文件存在
    if exist('vs_sf', 'file') == 3
        fprintf('[OK] vs_sf MEX 文件已找到\n');
    else
        warning('vs_sf MEX 文件未找到，请检查 TruckSim 安装');
    end

    %% 2. 参数初始化
    run('init_params.m');

    %% 3. 计算 LDP 参数
    w1 = ldp.primary.freq;   z1 = ldp.primary.damping_ratio;
    m1 = ldp.primary.mass;   L1 = ldp.primary.length;   h1 = ldp.primary.height;
    w2 = ldp.secondary.freq;  z2 = ldp.secondary.damping_ratio;
    m2 = ldp.secondary.mass;  L2 = ldp.secondary.length;  h2 = ldp.secondary.height;
    g  = ldp.g;

    %% 4. 创建联合仿真 Simulink 模型
    model_name = 'tanker_cosim_final';
    if bdIsLoaded(model_name)
        close_system(model_name, 0);
    end
    new_system(model_name);
    open_system(model_name);

    %% 5. TruckSim S-Function（真实的 vs_sf MEX）
    add_block('simulink/User-Defined Functions/S-Function', ...
        [model_name '/TruckSim_Model']);
    % vs_sf 需要3个参数: simfile路径, 状态(2=Run), 停止模式
    sf_params = sprintf('''%s'',2,0', ...
        'D:\Program Files (x86)\TruckSim\data\simfile.sim');
    set_param([model_name '/TruckSim_Model'], ...
        'FunctionName', 'vs_sf', ...
        'Parameters', sf_params);
    set_param([model_name '/TruckSim_Model'], ...
        'position', [150, 150, 300, 250]);
    fprintf('[OK] TruckSim S-Function (vs_sf)\n');

    %% 6. Demux: 分离 5 个 Export
    % Export通道(5): Vx, Ay, AVz, Roll, AVx
    add_block('simulink/Signal Routing/Demux', [model_name '/Demux_5']);
    set_param([model_name '/Demux_5'], 'Outputs', '5');
    set_param([model_name '/Demux_5'], 'position', [400, 140, 425, 200]);
    add_line(model_name, 'TruckSim_Model/1', 'Demux_5/1');

    %% 7. Selector: 提取 Ay（Export 通道2）
    add_block('simulink/Signal Routing/Selector', [model_name '/Sel_Ay']);
    set_param([model_name '/Sel_Ay'], ...
        'NumberOfDimensions', '1', ...
        'IndexOptions', 'Index vector (dialog)', ...
        'Indices', '2', ...
        'InputPortWidth', '5');
    set_param([model_name '/Sel_Ay'], 'position', [500, 260, 540, 295]);
    add_line(model_name, 'Demux_5/1', 'Sel_Ay/1');

    %% 8. LDP 子系统
    build_ldp_subsystem([model_name '/LDP'], ldp);
    set_param([model_name '/LDP'], 'position', [610, 180, 740, 330]);
    add_line(model_name, 'Sel_Ay/1', 'LDP/1');

    %% 9. Mux → 送回 TruckSim Import (2路: Fy, Mx)
    add_block('simulink/Signal Routing/Mux', [model_name '/Mux_Import']);
    set_param([model_name '/Mux_Import'], 'Inputs', '2');
    set_param([model_name '/Mux_Import'], 'position', [830, 200, 860, 260]);

    % 第1路: F_slosh_y → Import通道1 (IMP_FYEXA2)
    add_line(model_name, 'LDP/1', 'Mux_Import/1');
    % 第2路: M_slosh_x → Import通道2 (IMP_MX_EXT)
    add_line(model_name, 'LDP/2', 'Mux_Import/2');

    % 连回 TruckSim
    add_line(model_name, 'Mux_Import/1', 'TruckSim_Model/1', 'autorouting', 'on');

    %% 10. 数据记录
    add_block('simulink/Sinks/To Workspace', [model_name '/simout']);
    set_param([model_name '/simout'], ...
        'VariableName', 'simout', ...
        'SaveFormat', 'Structure With Time');
    set_param([model_name '/simout'], 'position', [400, 450, 480, 490]);
    add_line(model_name, 'Demux_5/1', 'simout/1');

    %% 11. 仿真设置
    set_param(model_name, 'Solver', 'ode4');
    set_param(model_name, 'FixedStep', '0.001');
    set_param(model_name, 'StopTime', '30');
    set_param(model_name, 'SaveOutput', 'on');

    %% 12. 保存
    save_system(model_name);

    fprintf('========================================\n');
    fprintf('  ✓ 模型: %s.slx\n', model_name);
    fprintf('========================================\n');
    fprintf('\n下一步:\n');
    fprintf('  1. 在 TruckSim 中配置 Simulink I/O 端口\n');
    fprintf('  2. 确认 simfile 中 PORTS_EXP=18, PORTS_IMP=3\n');
    fprintf('  3. 运行: sim(''%s'')\n', model_name);
    fprintf('========================================\n');
end

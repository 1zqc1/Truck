%% build_cosim_model.m —— 一键构建联合仿真模型
%  用基本 Integrator/Gain 模块搭建 LDP，无兼容性问题

function build_cosim_model()
    run('init_params.m');

    model_name = 'tanker_cosim';
    if bdIsLoaded(model_name)
        close_system(model_name, 0);
    end

    new_system(model_name);
    open_system(model_name);

    %% 1. TruckSim S-Function
    add_block('simulink/User-Defined Functions/S-Function', ...
        [model_name '/TruckSim_Vehicle']);
    set_param([model_name '/TruckSim_Vehicle'], ...
        'FunctionName', 'vs_sfcn', 'Parameters', '');
    set_param([model_name '/TruckSim_Vehicle'], ...
        'position', [100, 150, 280, 250]);
    fprintf('[OK] TruckSim S-Function\n');

    %% 2. Demux: 分离 18 个 Export 通道
    add_block('simulink/Signal Routing/Demux', ...
        [model_name '/Demux_18ch']);
    set_param([model_name '/Demux_18ch'], 'Outputs', '18');
    set_param([model_name '/Demux_18ch'], ...
        'position', [370, 130, 400, 300]);
    add_line(model_name, 'TruckSim_Vehicle/1', 'Demux_18ch/1');
    fprintf('[OK] Export Demux (18通道)\n');

    %% 3. Selector: 提取 Ay (第2通道)
    add_block('simulink/Signal Routing/Selector', ...
        [model_name '/Sel_Ay']);
    set_param([model_name '/Sel_Ay'], ...
        'NumberOfDimensions', '1', ...
        'IndexOptions', 'Index vector (dialog)', ...
        'Indices', '2', ...
        'InputPortWidth', '18');
    set_param([model_name '/Sel_Ay'], ...
        'position', [480, 240, 520, 275]);
    add_line(model_name, 'Demux_18ch/1', 'Sel_Ay/1');
    fprintf('[OK] Ay 提取 (Export通道2)\n');

    %% 4. LDP 子系统（Integrator + Gain 实现双摆）
    build_ldp_subsystem([model_name '/LDP'], ldp);
    set_param([model_name '/LDP'], 'position', [600, 140, 730, 290]);
    add_line(model_name, 'Sel_Ay/1', 'LDP/1');
    fprintf('[OK] LDP 双摆子系统\n');

    %% 5. Mux: 合并 Fy, Mx → 送回 TruckSim
    add_block('simulink/Signal Routing/Mux', ...
        [model_name '/Mux_Import']);
    set_param([model_name '/Mux_Import'], 'Inputs', '2');
    set_param([model_name '/Mux_Import'], ...
        'position', [820, 180, 850, 250]);
    add_line(model_name, 'LDP/1', 'Mux_Import/1');
    add_line(model_name, 'LDP/2', 'Mux_Import/2');
    add_line(model_name, 'Mux_Import/1', 'TruckSim_Vehicle/1', ...
        'autorouting', 'on');
    fprintf('[OK] 闭环反馈 [Fy, Mx] → TruckSim Import\n');

    %% 6. 数据记录
    add_block('simulink/Sinks/To Workspace', [model_name '/simout']);
    set_param([model_name '/simout'], ...
        'VariableName', 'simout', ...
        'SaveFormat', 'Structure With Time');
    set_param([model_name '/simout'], ...
        'position', [370, 450, 450, 490]);
    add_line(model_name, 'Demux_18ch/1', 'simout/1');

    %% 7. 仿真设置
    set_param(model_name, 'Solver', 'ode4');
    set_param(model_name, 'FixedStep', num2str(sim.dt));
    set_param(model_name, 'StopTime', num2str(sim.t_end));
    set_param(model_name, 'SaveOutput', 'on');

    %% 8. 保存
    save_system(model_name);
    fprintf('========================================\n');
    fprintf('  ✓ 模型已生成: %s.slx\n', model_name);
    fprintf('========================================\n');
    fprintf('  闭环回路:\n');
    fprintf('    TruckSim → Ay → LDP → [Fy,Mx] → TruckSim\n');
    fprintf('========================================\n');
end

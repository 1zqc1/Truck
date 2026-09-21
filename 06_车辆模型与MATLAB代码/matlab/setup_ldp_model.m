%% setup_ldp_model.m —— 创建 LDP 液体晃动 Simulink 模型
%  生成封装好的 LDP 子系统，用于接入 TruckSim 联合仿真
%  模型输入: Ay (罐体处侧向加速度)
%  模型输出: F_slosh_y (晃动横向力), M_slosh_x (晃动侧倾力矩)

function setup_ldp_model()
    %% 初始化参数
    init_params;

    model_name = 'ldp_slosh_model';

    % 关闭已存在的模型
    if bdIsLoaded(model_name)
        close_system(model_name, 0);
    end

    %% 创建新模型
    new_system(model_name);
    open_system(model_name);

    %% ==================== 构建 LDP 子系统 ====================
    sub_name = [model_name '/LDP_Sloshing_Dynamics'];
    add_block('simulink/Ports & Subsystems/Subsystem', sub_name);

    % 删除子系统中默认内容
    Simulink.BlockDiagram.deleteContents(sub_name);

    % --- 子系统输入端口 ---
    add_block('simulink/Sources/In1', [sub_name '/Ay']);
    set_param([sub_name '/Ay'], 'Port', '1');

    % --- 状态空间（输出4个状态：θ₁, θ̇₁, θ₂, θ̇₂）---
    C_full = eye(4);
    D_full = zeros(4, 1);

    add_block('simulink/Continuous/State-Space', [sub_name '/LDP_StateSpace']);
    set_param([sub_name '/LDP_StateSpace'], ...
        'A', mat2str(ldp.A), ...
        'B', mat2str(ldp.B), ...
        'C', mat2str(C_full), ...
        'D', mat2str(D_full), ...
        'InitialConditions', mat2str(ldp.x0), ...
        'AbsoluteTolerance', '1e-6');

    % --- 分离四个状态 ---
    add_block('simulink/Signal Routing/Demux', [sub_name '/Demux']);
    set_param([sub_name '/Demux'], 'Outputs', '4');

    % --- 主摆角度限幅 ---
    add_block('simulink/Discontinuities/Saturation', [sub_name '/Saturation_theta1']);
    set_param([sub_name '/Saturation_theta1'], ...
        'UpperLimit', num2str(ldp.theta_max), ...
        'LowerLimit', num2str(-ldp.theta_max));

    % --- 次摆角度限幅 ---
    add_block('simulink/Discontinuities/Saturation', [sub_name '/Saturation_theta2']);
    set_param([sub_name '/Saturation_theta2'], ...
        'UpperLimit', num2str(ldp.theta_max), ...
        'LowerLimit', num2str(-ldp.theta_max));

    % --- 主摆晃动横向力计算 ---
    % F1 = -m1 * (g * θ₁ + 2ζ₁ω₁L₁ * θ̇₁)
    add_block('simulink/Math Operations/Gain', [sub_name '/Gain_theta1']);
    set_param([sub_name '/Gain_theta1'], 'Gain', num2str(-ldp.primary.mass * ldp.g));

    add_block('simulink/Math Operations/Gain', [sub_name '/Gain_dtheta1']);
    set_param([sub_name '/Gain_dtheta1'], ...
        'Gain', num2str(-ldp.primary.mass * 2 * ldp.primary.damping_ratio ...
                        * ldp.primary.freq * ldp.primary.length));

    % --- 次摆晃动横向力计算 ---
    % F2 = -m2 * (g * θ₂ + 2ζ₂ω₂L₂ * θ̇₂)
    add_block('simulink/Math Operations/Gain', [sub_name '/Gain_theta2']);
    set_param([sub_name '/Gain_theta2'], 'Gain', num2str(-ldp.secondary.mass * ldp.g));

    add_block('simulink/Math Operations/Gain', [sub_name '/Gain_dtheta2']);
    set_param([sub_name '/Gain_dtheta2'], ...
        'Gain', num2str(-ldp.secondary.mass * 2 * ldp.secondary.damping_ratio ...
                        * ldp.secondary.freq * ldp.secondary.length));

    % --- 主摆贡献求和 ---
    add_block('simulink/Math Operations/Add', [sub_name '/Add_F1']);
    set_param([sub_name '/Add_F1'], 'Inputs', '++');

    % --- 次摆贡献求和 ---
    add_block('simulink/Math Operations/Add', [sub_name '/Add_F2']);
    set_param([sub_name '/Add_F2'], 'Inputs', '++');

    % --- 横向合力 ---
    add_block('simulink/Math Operations/Add', [sub_name '/Add_F_total']);
    set_param([sub_name '/Add_F_total'], 'Inputs', '++', 'IconShape', 'round');

    % --- 侧倾力矩计算 ---
    % M_slosh_x = m1 * g * h1 * θ₁ + m2 * g * h2 * θ₂
    add_block('simulink/Math Operations/Gain', [sub_name '/Gain_M1']);
    set_param([sub_name '/Gain_M1'], ...
        'Gain', num2str(ldp.primary.mass * ldp.g * ldp.primary.height));

    add_block('simulink/Math Operations/Gain', [sub_name '/Gain_M2']);
    set_param([sub_name '/Gain_M2'], ...
        'Gain', num2str(ldp.secondary.mass * ldp.g * ldp.secondary.height));

    add_block('simulink/Math Operations/Add', [sub_name '/Add_M_total']);
    set_param([sub_name '/Add_M_total'], 'Inputs', '++', 'IconShape', 'round');

    % --- 子系统输出端口 ---
    add_block('simulink/Sinks/Out1', [sub_name '/F_slosh_y']);
    set_param([sub_name '/F_slosh_y'], 'Port', '1');

    add_block('simulink/Sinks/Out1', [sub_name '/M_slosh_x']);
    set_param([sub_name '/M_slosh_x'], 'Port', '2');

    %% ==================== 子系统内部连线 ====================
    % Ay → State-Space
    add_line(sub_name, 'Ay/1', 'LDP_StateSpace/1');

    % State-Space → Demux
    add_line(sub_name, 'LDP_StateSpace/1', 'Demux/1');

    % Demux 输出: [θ₁, θ̇₁, θ₂, θ̇₂]

    % θ₁ 分支：限幅 → Gain_theta1 → Add_F1
    add_line(sub_name, 'Demux/1', 'Saturation_theta1/1');
    add_line(sub_name, 'Saturation_theta1/1', 'Gain_theta1/1');
    add_line(sub_name, 'Gain_theta1/1', 'Add_F1/1');

    % θ₁ 分支：限幅 → Gain_M1 → Add_M_total
    add_line(sub_name, 'Saturation_theta1/1', 'Gain_M1/1');
    add_line(sub_name, 'Gain_M1/1', 'Add_M_total/1');

    % θ̇₁ 分支 → Gain_dtheta1 → Add_F1
    add_line(sub_name, 'Demux/2', 'Gain_dtheta1/1');
    add_line(sub_name, 'Gain_dtheta1/1', 'Add_F1/2');

    % θ₂ 分支：限幅 → Gain_theta2 → Add_F2
    add_line(sub_name, 'Demux/3', 'Saturation_theta2/1');
    add_line(sub_name, 'Saturation_theta2/1', 'Gain_theta2/1');
    add_line(sub_name, 'Gain_theta2/1', 'Add_F2/1');

    % θ₂ 分支：限幅 → Gain_M2 → Add_M_total
    add_line(sub_name, 'Saturation_theta2/1', 'Gain_M2/1');
    add_line(sub_name, 'Gain_M2/1', 'Add_M_total/2');

    % θ̇₂ 分支 → Gain_dtheta2 → Add_F2
    add_line(sub_name, 'Demux/4', 'Gain_dtheta2/1');
    add_line(sub_name, 'Gain_dtheta2/1', 'Add_F2/2');

    % F1 + F2 → F_total
    add_line(sub_name, 'Add_F1/1', 'Add_F_total/1');
    add_line(sub_name, 'Add_F2/1', 'Add_F_total/2');

    % 连接输出
    add_line(sub_name, 'Add_F_total/1', 'F_slosh_y/1');
    add_line(sub_name, 'Add_M_total/1', 'M_slosh_x/1');

    %% ==================== 创建顶层联合仿真模型 ====================
    cosim_name = [model_name '/TruckSim_CoSimulation'];
    add_block('simulink/Ports & Subsystems/Subsystem', cosim_name);
    Simulink.BlockDiagram.deleteContents(cosim_name);

    % --- TruckSim S-Function 占位块 ---
    % 此处放置 TruckSim 生成的 S-Function 块
    % 方法：在 TruckSim 中完成车辆模型配置后，点击 "Send to Simulink"
    % 然后将生成的 S-Function 块复制到此位置
    add_block('simulink/User-Defined Functions/S-Function', ...
        [cosim_name '/TruckSim_Vehicle']);
    set_param([cosim_name '/TruckSim_Vehicle'], ...
        'FunctionName', 'trucksim_sfunction_name', ...
        'Parameters', 'trucksim_sfunction_params');

    add_block('simulink/Sinks/Terminator', [cosim_name '/Term']);
    add_block('simulink/Sources/Constant', [cosim_name '/Steer_Input']);
    set_param([cosim_name '/Steer_Input'], 'Value', '0');

    % --- 添加 LDP 子系统引用 ---
    add_block('simulink/Ports & Subsystems/Model', ...
        [cosim_name '/LDP_Model_Ref']);
    set_param([cosim_name '/LDP_Model_Ref'], 'ModelFile', [model_name '.slx']);

    %% ==================== 顶层模型输入输出 ====================
    % LDP 子系统输出端口 → Mux → 回到 TruckSim
    add_block('simulink/Signal Routing/Mux', [model_name '/Mux_Import']);
    set_param([model_name '/Mux_Import'], 'Inputs', '2');

    add_block('simulink/Sinks/Out1', [model_name '/TruckSim_Import']);
    set_param([model_name '/TruckSim_Import'], 'Port', '1');

    add_block('simulink/Sources/In1', [model_name '/TruckSim_Export']);
    set_param([model_name '/TruckSim_Export'], 'Port', '1');

    % 从 TruckSim Export 中提取 Ay
    % TruckSim 输出通常包含多个信号，需要用 Selector 提取 Ay 通道
    add_block('simulink/Signal Routing/Demux', [model_name '/Demux_Export']);
    set_param([model_name '/Demux_Export'], 'Outputs', '10');

    add_block('simulink/Sinks/To Workspace', [model_name '/SimData']);
    set_param([model_name '/SimData'], ...
        'VariableName', 'sim_data', ...
        'SaveFormat', 'Structure With Time');

    %% ==================== 模型外观调整 ====================
    % LDP 子系统背景色
    set_param(sub_name, 'BackgroundColor', 'lightBlue');
    set_param(cosim_name, 'BackgroundColor', 'lightGreen');

    %% ==================== 模型保存与验证 ====================
    save_system(model_name);

    fprintf('=============================================================\n');
    fprintf('  LDP 液体晃动 Simulink 模型已生成: %s.slx\n', model_name);
    fprintf('=============================================================\n');
    fprintf('  子系统: LDP_Sloshing_Dynamics\n');
    fprintf('    输入:  Ay [m/s²] - 罐体处侧向加速度\n');
    fprintf('    输出1: F_slosh_y [N] - 晃动横向力\n');
    fprintf('    输出2: M_slosh_x [N·m] - 晃动侧倾力矩\n');
    fprintf('\n');
    fprintf('  状态空间: 4阶系统\n');
    fprintf('    状态1: θ₁ [rad] - 主摆角度\n');
    fprintf('    状态2: θ̇₁ [rad/s] - 主摆角速度\n');
    fprintf('    状态3: θ₂ [rad] - 次摆角度\n');
    fprintf('    状态4: θ̇₂ [rad/s] - 次摆角速度\n');
    fprintf('\n');
    fprintf('  *** 后续步骤说明 ***\n');
    fprintf('  1. 在 TruckSim 中完成车辆模型配置\n');
    fprintf('  2. 点击 TruckSim 菜单: Models → Simulink\n');
    fprintf('  3. 设置 I/O 通道后点击 "Send to Simulink"\n');
    fprintf('  4. 将生成的 S-Function 块复制到本模型的 TruckSim_Vehicle 位置\n');
    fprintf('  5. 连接 I/O 信号线后即可运行联合仿真\n');
    fprintf('=============================================================\n');

    %% ==================== 创建 LDP 模型验证 Simulink 模型 ====================
    validate_name = 'ldp_validation';
    if bdIsLoaded(validate_name)
        close_system(validate_name, 0);
    end

    new_system(validate_name);
    open_system(validate_name);

    % 正弦激励源
    add_block('simulink/Sources/Sine Wave', [validate_name '/Sine_Ay']);
    set_param([validate_name '/Sine_Ay'], ...
        'Amplitude', '3', ...       % 3 m/s² 侧向加速度
        'Frequency', num2str(w1/(2*pi)), ...  % 主摆固有频率
        'SampleTime', num2str(sim.dt));

    % LDP 子系统引用
    add_block('simulink/Ports & Subsystems/Model', ...
        [validate_name '/LDP_Model']);
    set_param([validate_name '/LDP_Model'], 'ModelFile', [model_name '.slx']);

    % 示波器
    add_block('simulink/Sinks/Scope', [validate_name '/Scope_Slosh']);
    set_param([validate_name '/Scope_Slosh'], 'NumInputPorts', '3');

    add_block('simulink/Sinks/To Workspace', [validate_name '/ValidateData']);
    set_param([validate_name '/ValidateData'], ...
        'VariableName', 'validate_data', ...
        'SaveFormat', 'Structure With Time');

    % 分路显示
    add_block('simulink/Signal Routing/Demux', [validate_name '/Demux']);
    set_param([validate_name '/Demux'], 'Outputs', '2');

    % 连线
    add_line(validate_name, 'Sine_Ay/1', 'LDP_Model/1');
    add_line(validate_name, 'LDP_Model/1', 'Demux/1');
    add_line(validate_name, 'Demux/1', 'Scope_Slosh/1');
    add_line(validate_name, 'Demux/2', 'Scope_Slosh/2');
    add_line(validate_name, 'Sine_Ay/1', 'Scope_Slosh/3');
    add_line(validate_name, 'LDP_Model/1', 'ValidateData/1');

    save_system(validate_name);
    close_system(validate_name);

    fprintf('  验证模型已生成: %s.slx\n', validate_name);
    fprintf('  运行验证: sim(''%s'')\n', validate_name);
end

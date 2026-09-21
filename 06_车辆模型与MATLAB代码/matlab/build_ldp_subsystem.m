%% build_ldp_subsystem.m —— 用基本模块搭建 LDP 双摆模型
%  输入: Ay (罐体侧向加速度)
%  输出: F_slosh_y, M_slosh_x

function build_ldp_subsystem(sys_path, ldp)
    % sys_path: 子系统完整路径
    % ldp: LDP 参数结构体
    w1 = ldp.primary.freq;
    z1 = ldp.primary.damping_ratio;
    m1 = ldp.primary.mass;
    L1 = ldp.primary.length;
    h1 = ldp.primary.height;
    w2 = ldp.secondary.freq;
    z2 = ldp.secondary.damping_ratio;
    m2 = ldp.secondary.mass;
    L2 = ldp.secondary.length;
    h2 = ldp.secondary.height;
    g  = ldp.g;

    % 增益系数
    k_w1sq   = w1^2;        % θ₁ → θ̈₁
    k_damp1  = 2*z1*w1;     % θ̇₁ → θ̈₁
    k_invL1  = 1/L1;        % Ay → θ̈₁

    k_w2sq   = w2^2;
    k_damp2  = 2*z2*w2;
    k_invL2  = 1/L2;

    k_Fy_th1 = m1 * g;      % θ₁ → Fy 贡献
    k_Fy_dth1 = m1 * 2*z1*w1*L1;  % θ̇₁ → Fy 贡献
    k_Fy_th2 = m2 * g;
    k_Fy_dth2 = m2 * 2*z2*w2*L2;

    k_Mx_th1 = m1 * g * h1;
    k_Mx_th2 = m2 * g * h2;

    % ====== 创建子系统 ======
    add_block('simulink/Ports & Subsystems/Subsystem', sys_path);

    % 清空子系统默认内容（删除默认的 In1/Out1）
    contents = find_system(sys_path, 'SearchDepth', 1);
    contents = setdiff(contents, sys_path);  % 排除子系统自身
    for c = 1:length(contents)
        delete_block(contents{c});
    end

    % ====== 输入端口 ======
    add_block('simulink/Sources/In1', [sys_path '/Ay']);
    set_param([sys_path '/Ay'], 'Port', '1');

    % ====== 摆1: θ̈₁ = -w₁²θ₁ - 2ζ₁w₁θ̇₁ - Ay/L₁ ======

    % Ay → -Ay/L1
    add_block('simulink/Math Operations/Gain', [sys_path '/Gain_Ay_L1']);
    set_param([sys_path '/Gain_Ay_L1'], 'Gain', num2str(-k_invL1));

    % θ₁ → -w₁²θ₁
    add_block('simulink/Math Operations/Gain', [sys_path '/Gain_w1sq']);
    set_param([sys_path '/Gain_w1sq'], 'Gain', num2str(-k_w1sq));

    % θ̇₁ → -2ζ₁w₁θ̇₁
    add_block('simulink/Math Operations/Gain', [sys_path '/Gain_damp1']);
    set_param([sys_path '/Gain_damp1'], 'Gain', num2str(-k_damp1));

    % 三项求和 → θ̈₁
    add_block('simulink/Math Operations/Add', [sys_path '/Sum_ddth1']);
    set_param([sys_path '/Sum_ddth1'], 'Inputs', '+++');

    % θ̈₁ → θ̇₁ (积分)
    add_block('simulink/Continuous/Integrator', [sys_path '/Int_dth1']);
    set_param([sys_path '/Int_dth1'], 'InitialCondition', '0');

    % θ̇₁ → θ₁ (积分)
    add_block('simulink/Continuous/Integrator', [sys_path '/Int_th1']);
    set_param([sys_path '/Int_th1'], 'InitialCondition', '0');

    % ====== 摆2: θ̈₂ = -w₂²θ₂ - 2ζ₂w₂θ̇₂ - Ay/L₂ ======

    add_block('simulink/Math Operations/Gain', [sys_path '/Gain_Ay_L2']);
    set_param([sys_path '/Gain_Ay_L2'], 'Gain', num2str(-k_invL2));

    add_block('simulink/Math Operations/Gain', [sys_path '/Gain_w2sq']);
    set_param([sys_path '/Gain_w2sq'], 'Gain', num2str(-k_w2sq));

    add_block('simulink/Math Operations/Gain', [sys_path '/Gain_damp2']);
    set_param([sys_path '/Gain_damp2'], 'Gain', num2str(-k_damp2));

    add_block('simulink/Math Operations/Add', [sys_path '/Sum_ddth2']);
    set_param([sys_path '/Sum_ddth2'], 'Inputs', '+++');

    add_block('simulink/Continuous/Integrator', [sys_path '/Int_dth2']);
    set_param([sys_path '/Int_dth2'], 'InitialCondition', '0');

    add_block('simulink/Continuous/Integrator', [sys_path '/Int_th2']);
    set_param([sys_path '/Int_th2'], 'InitialCondition', '0');

    % ====== 输出计算 ======

    % F_y = -m₁(gθ₁ + 2ζ₁w₁L₁θ̇₁) - m₂(gθ₂ + 2ζ₂w₂L₂θ̇₂)
    add_block('simulink/Math Operations/Gain', [sys_path '/Gain_Fy_th1']);
    set_param([sys_path '/Gain_Fy_th1'], 'Gain', num2str(-k_Fy_th1));

    add_block('simulink/Math Operations/Gain', [sys_path '/Gain_Fy_dth1']);
    set_param([sys_path '/Gain_Fy_dth1'], 'Gain', num2str(-k_Fy_dth1));

    add_block('simulink/Math Operations/Gain', [sys_path '/Gain_Fy_th2']);
    set_param([sys_path '/Gain_Fy_th2'], 'Gain', num2str(-k_Fy_th2));

    add_block('simulink/Math Operations/Gain', [sys_path '/Gain_Fy_dth2']);
    set_param([sys_path '/Gain_Fy_dth2'], 'Gain', num2str(-k_Fy_dth2));

    add_block('simulink/Math Operations/Add', [sys_path '/Sum_Fy']);
    set_param([sys_path '/Sum_Fy'], 'Inputs', '++++');

    % M_x = m₁gh₁θ₁ + m₂gh₂θ₂
    add_block('simulink/Math Operations/Gain', [sys_path '/Gain_Mx_th1']);
    set_param([sys_path '/Gain_Mx_th1'], 'Gain', num2str(k_Mx_th1));

    add_block('simulink/Math Operations/Gain', [sys_path '/Gain_Mx_th2']);
    set_param([sys_path '/Gain_Mx_th2'], 'Gain', num2str(k_Mx_th2));

    add_block('simulink/Math Operations/Add', [sys_path '/Sum_Mx']);
    set_param([sys_path '/Sum_Mx'], 'Inputs', '++');

    % ====== 输出端口 ======
    add_block('simulink/Sinks/Out1', [sys_path '/Fy']);
    set_param([sys_path '/Fy'], 'Port', '1');

    add_block('simulink/Sinks/Out1', [sys_path '/Mx']);
    set_param([sys_path '/Mx'], 'Port', '2');

    % ====== 连线 ======
    % 摆1 连线
    add_line(sys_path, 'Ay/1', 'Gain_Ay_L1/1');
    add_line(sys_path, 'Int_th1/1', 'Gain_w1sq/1');
    add_line(sys_path, 'Int_dth1/1', 'Gain_damp1/1');

    add_line(sys_path, 'Gain_Ay_L1/1', 'Sum_ddth1/1');
    add_line(sys_path, 'Gain_w1sq/1', 'Sum_ddth1/2');
    add_line(sys_path, 'Gain_damp1/1', 'Sum_ddth1/3');
    add_line(sys_path, 'Sum_ddth1/1', 'Int_dth1/1');
    add_line(sys_path, 'Int_dth1/1', 'Int_th1/1');

    % 摆2 连线
    add_line(sys_path, 'Ay/1', 'Gain_Ay_L2/1');
    add_line(sys_path, 'Int_th2/1', 'Gain_w2sq/1');
    add_line(sys_path, 'Int_dth2/1', 'Gain_damp2/1');

    add_line(sys_path, 'Gain_Ay_L2/1', 'Sum_ddth2/1');
    add_line(sys_path, 'Gain_w2sq/1', 'Sum_ddth2/2');
    add_line(sys_path, 'Gain_damp2/1', 'Sum_ddth2/3');
    add_line(sys_path, 'Sum_ddth2/1', 'Int_dth2/1');
    add_line(sys_path, 'Int_dth2/1', 'Int_th2/1');

    % Fy 连线
    add_line(sys_path, 'Int_th1/1', 'Gain_Fy_th1/1');
    add_line(sys_path, 'Int_dth1/1', 'Gain_Fy_dth1/1');
    add_line(sys_path, 'Int_th2/1', 'Gain_Fy_th2/1');
    add_line(sys_path, 'Int_dth2/1', 'Gain_Fy_dth2/1');

    add_line(sys_path, 'Gain_Fy_th1/1', 'Sum_Fy/1');
    add_line(sys_path, 'Gain_Fy_dth1/1', 'Sum_Fy/2');
    add_line(sys_path, 'Gain_Fy_th2/1', 'Sum_Fy/3');
    add_line(sys_path, 'Gain_Fy_dth2/1', 'Sum_Fy/4');
    add_line(sys_path, 'Sum_Fy/1', 'Fy/1');

    % Mx 连线
    add_line(sys_path, 'Int_th1/1', 'Gain_Mx_th1/1');
    add_line(sys_path, 'Int_th2/1', 'Gain_Mx_th2/1');
    add_line(sys_path, 'Gain_Mx_th1/1', 'Sum_Mx/1');
    add_line(sys_path, 'Gain_Mx_th2/1', 'Sum_Mx/2');
    add_line(sys_path, 'Sum_Mx/1', 'Mx/1');

    fprintf('[OK] LDP 子系统已用基本模块搭建完成\n');
end

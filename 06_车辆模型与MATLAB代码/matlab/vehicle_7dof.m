%% vehicle_7dof.m —— 七自由度半挂液罐车动力学模型
%  状态变量 (7 DOF):
%    x(1) = Vy1    牵引车侧向速度 [m/s]
%    x(2) = r1     牵引车横摆角速度 [rad/s]
%    x(3) = phi1   牵引车侧倾角 [rad]
%    x(4) = dphi1  牵引车侧倾角速度 [rad/s]
%    x(5) = Gamma  挂车铰接角 [rad]
%    x(6) = phi2   挂车侧倾角 [rad]
%    x(7) = dphi2  挂车侧倾角速度 [rad/s]
%
%  输入:
%    u(1) = Vx     纵向车速 [m/s]
%    u(2) = delta  前轮转角 [rad]
%    u(3) = Fy_slosh  液体晃动横向力 [N] (作用在挂车质心)
%    u(4) = Mx_slosh  液体晃动侧倾力矩 [N·m] (作用在挂车质心)

function dx = vehicle_7dof(t, x, u, p)
    % 解包状态
    Vy1   = x(1);
    r1    = x(2);
    phi1  = x(3);
    dphi1 = x(4);
    Gamma = x(5);
    phi2  = x(6);
    dphi2 = x(7);

    % 解包输入
    Vx       = u(1);
    delta    = u(2);
    Fy_slosh = u(3);
    Mx_slosh = u(4);

    % 参数简写
    m1  = p.m1;   m2  = p.m2;
    Iz1 = p.Iz1;  Iz2 = p.Iz2;
    Ix1 = p.Ix1;  Ix2 = p.Ix2;
    a1  = p.a1;   b1  = p.b1;
    a2  = p.a2;   b2  = p.b2;
    c   = p.c;    d   = p.d;
    h1  = p.h1;   h2  = p.h2;
    hc  = p.hc;
    Cf  = p.Cf;   Cr  = p.Cr;   Ct = p.Ct;
    K1  = p.K_roll1;  K2  = p.K_roll2;
    C1  = p.C_roll1;  C2  = p.C_roll2;
    g   = p.g;
    tw1 = p.tw1;  tw2 = p.tw2;

    %% 运动学关系
    % 挂车质心处侧向速度
    Vy2 = Vy1 - r1*(c + a2) - a2*(r1 + Gamma);

    % 简化：假设小铰接角
    if abs(Gamma) < 0.01
        Gamma_dot = 0;
    else
        Gamma_dot = r1 - (Vy1 - r1*c) / (a2 + b2);
    end

    %% 轮胎侧偏角
    alpha_f = (Vy1 + a1*r1) / (Vx + 1e-3) - delta;
    alpha_r = (Vy1 - b1*r1) / (Vx + 1e-3);
    alpha_t = (Vy2 - b2*(r1 + Gamma_dot)) / (Vx + 1e-3);

    %% 轮胎侧向力（线性模型）
    Fyf = Cf * alpha_f;
    Fyr = Cr * alpha_r;
    Fyt = Ct * alpha_t;

    %% 侧倾动力学 - 牵引车
    % 侧倾力矩平衡
    Mx_roll1 = m1*g*h1*sin(phi1) + m1*(Vy1 + Vx*r1)*h1*cos(phi1) ...
               - K1*phi1 - C1*dphi1;

    ddphi1 = Mx_roll1 / Ix1;

    %% 侧倾动力学 - 挂车
    Mx_roll2 = m2*g*h2*sin(phi2) + m2*(Vy2 + Vx*(r1+Gamma_dot))*h2*cos(phi2) ...
               - K2*phi2 - C2*dphi2 + Mx_slosh;

    ddphi2 = Mx_roll2 / Ix2;

    %% 横向动力学 - 牵引车
    dVy1 = (Fyf*cos(delta) + Fyr - m1*Vx*r1 ...
            + m1*h1*ddphi1*cos(phi1) ...
            - (m2*(Vy1 - r1*c) * (r1+Gamma_dot))) / (m1 + m2*0.5);

    %% 横摆动力学 - 牵引车
    dr1 = (a1*Fyf*cos(delta) - b1*Fyr + c*Fyt*cos(Gamma) ...
           + Fy_slosh*(c + a2)) / Iz1;

    %% 组装状态导数
    dx = zeros(7, 1);
    dx(1) = dVy1;
    dx(2) = dr1;
    dx(3) = dphi1;
    dx(4) = ddphi1;
    dx(5) = Gamma_dot;
    dx(6) = dphi2;
    dx(7) = ddphi2;
end

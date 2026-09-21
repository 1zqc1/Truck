/* udf_sideways.c
 * 侧向加速度激励 UDF —— 用于罐内液体晃动 VOF 仿真
 * 通过给 x 方向动量方程添加等效惯性力源项，模拟罐体侧向加速
 * 源项 = -rho * a_x(t)，其中 a_x(t) = A * sin(2*pi*f*t)
 *
 * 使用方法：
 *   1. 在 Fluent 中编译/解释此 UDF
 *   2. 在 Cell Zone Conditions 中为流体域添加源项，
 *      选择 x 方向动量，挂钩此 UDF
 */
#include "udf.h"

#define AMP  2.94    /* 侧向加速度幅值 [m/s^2]，0.3g */
#define FREQ 0.5     /* 激励频率 [Hz]，周期 2s */

/* 侧向激励源项（x 方向动量） */
DEFINE_SOURCE(x_momentum_source, cell, thread, dS, eqn)
{
    real t;        /* 当前仿真时间 */
    real a_x;      /* 瞬时侧向加速度 */
    real rho;      /* 当地密度 */
    real source;   /* 源项值 */

    t = CURRENT_TIME;
    a_x = AMP * sin(2.0 * M_PI * FREQ * t);
    rho = C_R(cell, thread);       /* 当地混合密度，对空气和水都有效 */
    source = -rho * a_x;           /* 等效惯性力，方向与加速度相反 */

    dS[eqn] = 0.0;                 /* 源项对速度的导数（显式处理） */

    return source;
}

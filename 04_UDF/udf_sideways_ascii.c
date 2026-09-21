/*
 * Lateral acceleration source for a tank-sloshing VOF simulation.
 * Source = -rho * a_x(t), where a_x(t) = A * sin(2*pi*f*t).
 */
#include "udf.h"

#define AMP  2.94    /* Lateral acceleration amplitude [m/s^2], 0.3g */
#define FREQ 0.5     /* Excitation frequency [Hz], period 2 s */

DEFINE_SOURCE(x_momentum_source, cell, thread, dS, eqn)
{
    real t;
    real a_x;
    real rho;
    real source;

    t = CURRENT_TIME;
    a_x = AMP * sin(2.0 * M_PI * FREQ * t);
    rho = C_R(cell, thread);
    source = -rho * a_x;

    dS[eqn] = 0.0;

    return source;
}

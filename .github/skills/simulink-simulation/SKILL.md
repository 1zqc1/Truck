---
name: simulink-simulation
description: Use this skill whenever simulating a Simulink model, running the sim command, setting up SimulationInput objects, passing input signals via timeseries or datasets, configuring model or block parameters programmatically, or accessing logged output data from SimulationOutput. Trigger for any request involving sim(), Simulink.SimulationInput, Simulink.SimulationOutput, logsout, setExternalInput, or setModelParameter.
metadata:
  source: summer521521/MATLAB_Simulink_plugin
  source-commit: 536af4dbde3c7bd0765cd3d7cd5160679c94f3e4
  reviewed-for: Truck project, MATLAB/Simulink R2022a
  local-review-date: 2026-10-12
---

# Simulating Simulink Models with the sim Command

## Truck Project Safety and Compatibility Gate

- This project uses MATLAB/Simulink R2022a. Verify every API against R2022a before using it; do not copy commands that require a newer release.
- Do not start MATLAB, create a new MATLAB session, run a simulation, open or save a model, or occupy a Parallel Computing Toolbox worker without the user's explicit confirmation for that action.
- Prefer the configured MathWorks MATLAB MCP server. If it is unavailable, report the limitation; do not silently fall back to `matlab -batch`, Python Engine, COM automation, or another MCP server.
- Before a simulation, state the model, input source and units, stop time, solver/sample-time assumptions, expected outputs, and output path. Wait for confirmation.
- Read current model and logging settings before proposing overrides. Use `SimulationInput` for non-persistent overrides. Never save changes to `.slx`, data dictionaries, or project files unless the user explicitly authorizes the named files.
- Treat `parsim` as optional. First verify that Parallel Computing Toolbox is installed and licensed, report the intended worker count, and obtain confirmation before opening a pool.
- After execution, distinguish tool success from scientific validation. Check errors, units, sample times, signal mapping, numerical plausibility, and provenance.

## Minimal working pattern

Always simulate using `Simulink.SimulationInput` and `Simulink.SimulationOutput`:

```matlab
in = Simulink.SimulationInput('MyModel');
in = in.setModelParameter('StopTime', '10');
out = sim(in);
```

Never use persistent `set_param` changes merely to configure a run. Use `SimulationInput` overrides where R2022a supports them. Model loading or inspection is a separate read-only step and still requires the project safety gate above.

## Setting parameters

Use `SimulationInput` methods to configure the simulation:

```matlab
% Model-level parameters (StopTime, SolverType, SimulationMode, etc.)
in = in.setModelParameter('StopTime', '10', 'SolverType', 'Fixed-step');

% Block parameters
in = in.setBlockParameter('MyModel/Gain', 'Gain', '5');

% MATLAB workspace variables used by the model
in = in.setVariable('Kp', 1.2);
```

## Input signals

Pass input signals through Inport blocks using a `Simulink.SimulationData.Dataset`. Each timeseries `Name` must match the corresponding Inport block's signal name, otherwise the signal won't be routed correctly.

```matlab
dt = 0.01; % sample time
N = 1000; % Number of points
t = dt*(0:N)';
u = sin(2*pi*t);

ts = timeseries(u, t);
ts.Name = 'mySignal';   % must match the Inport signal name in the model

ds = Simulink.SimulationData.Dataset;
ds{1} = ts;

in = in.setExternalInput(ds);
out = sim(in);
```

## Discovering logged signals

After the user has approved a simulation, discover what signals the completed run actually logged by inspecting `logsout`:

```matlab
in = Simulink.SimulationInput('MyModel');
out = sim(in);
disp('List of logged signals:');
disp(out.logsout.getElementNames);
```

This is especially useful when working with an unfamiliar model — the names returned here are exactly the names to use when calling `out.logsout.get(...)`.

## Accessing logged data

Logged signals are available through `out.logsout`. Access them directly by name — no intermediate variables needed:

```matlab
% Plot a logged signal
plot(out.logsout.get('signalName').Values)

% Get time and data separately
sig = out.logsout.get('signalName').Values;
plot(sig.Time, sig.Data)
```

Do not validate `out` with try-catch or `isfield` — `sim` either returns a valid `SimulationOutput` or throws an error. `Simulink.SimulationOutput` has no `isfield` method.

## Accessing To Workspace Outputs

If the model uses `To Workspace` blocks and `ReturnWorkspaceOutputs` is on, retrieve those outputs directly from the `SimulationOutput` object:

```matlab
in = Simulink.SimulationInput('MyModel');
in = in.setModelParameter('ReturnWorkspaceOutputs', 'on');
out = sim(in);

T = out.simout_T;
Q = out.simout_Qbase;
```

Normalize the exported value before post-processing because `To Workspace` may return a `timeseries`, a `Simulink.SimulationData.Signal`, or a numeric matrix depending on block settings:

```matlab
if isa(T, 'timeseries')
    t = T.Time(:);
    y = T.Data(:);
elseif isa(T, 'Simulink.SimulationData.Signal')
    t = T.Values.Time(:);
    y = T.Values.Data(:);
else
    t = T(:,1);
    y = T(:,2);
end
```

## Multiple simulations

When running many simulations, create an array of `Simulink.SimulationInput` objects using the `repmat` function instead of looping over `sim`:

```matlab
in = repmat(Simulink.SimulationInput('MyModel'),N,1);
for k = 1:N
    in(k) = Simulink.SimulationInput('MyModel');
    in(k) = in(k).setVariable('gain', gains(k));
end
out = sim(in);
```

When collecting results from multiple cases into a struct array, preallocate a homogeneous struct shape before the loop. MATLAB will throw "subscripted assignment between dissimilar structures" if later cases add fields or nested layouts that the first element did not have.

## Parallel simulation (parsim)

When Parallel Computing Toolbox availability and worker use have been confirmed, use `parsim` instead of looping over `sim`:

```matlab
for k = 1:N
    in(k) = Simulink.SimulationInput('MyModel');
    in(k) = in(k).setVariable('gain', gains(k));
end
out = parsim(in);
```

## Rebuild-and-Simulate Pitfalls

If a script repeatedly rebuilds and reruns a model:

- Save or clear the dirty flag before `close_system`, otherwise MATLAB can warn that the changed model cannot be closed.
- Avoid model names that shadow scripts or functions on the MATLAB path; model/script name collisions can produce confusing warnings during `sim` and `run`.
- When a generated model relies on MATLAB Function blocks with workspace parameters, make sure those symbols are declared as block parameters during model construction; otherwise simulation can fail before `sim` starts with output-size/type inference errors.

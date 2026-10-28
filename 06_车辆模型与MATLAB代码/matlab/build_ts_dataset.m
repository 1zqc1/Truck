function dataset = build_ts_dataset(runs, lookback, horizon, seed)
% Split complete independent runs before forming windows or fitting scaling.
% Runs must already have validated features, target and a stable name.
if numel(runs) < 3
    error('ftinspect:InsufficientRuns', 'At least three independent runs are required.');
end
if lookback < 1 || horizon < 1 || fix(lookback) ~= lookback || fix(horizon) ~= horizon
    error('ftinspect:InvalidWindow', 'Window lengths must be positive integers.');
end
names = cellfun(@(r) r.name, runs, 'UniformOutput', false);
if numel(unique(names)) ~= numel(names)
    error('ftinspect:DuplicateRun', 'Run names must be unique.');
end
n_features = size(runs{1}.features, 2);
for k = 1:numel(runs)
    X = runs{k}.features;
    y = runs{k}.target;
    if size(X, 2) ~= n_features || size(y, 2) ~= 1 || size(X, 1) ~= numel(y) ...
            || size(X, 1) < lookback + horizon || any(~isfinite(X(:))) || any(~isfinite(y(:)))
        error('ftinspect:InvalidRun', 'Invalid or insufficient data in run %s.', names{k});
    end
end
rng(seed, 'twister');
order = randperm(numel(runs));
n_train = max(1, floor(0.6 * numel(runs)));
n_val = max(1, floor(0.2 * numel(runs)));
if n_train + n_val >= numel(runs)
    n_train = numel(runs) - n_val - 1;
end
groups = {order(1:n_train), order(n_train+1:n_train+n_val), order(n_train+n_val+1:end)};
split_names = {'train', 'val', 'test'};
for s = 1:3
    Xcells = {}; Ycells = {};
    for k = groups{s}
        run = runs{k};
        for i = 1:size(run.features, 1)-lookback-horizon+1
            Xcells{end+1} = run.features(i:i+lookback-1, :); %#ok<AGROW>
            Ycells{end+1} = run.target(i+lookback:i+lookback+horizon-1)'; %#ok<AGROW>
        end
    end
    n = numel(Xcells);
    X = zeros(n, lookback, n_features); Y = zeros(n, horizon);
    for i = 1:n
        X(i, :, :) = reshape(Xcells{i}, [1, lookback, n_features]);
        Y(i, :) = Ycells{i};
    end
    dataset.(split_names{s}).X = X;
    dataset.(split_names{s}).Y = Y;
    dataset.(split_names{s}).run_ids = names(groups{s});
end
train = dataset.train.X;
flat = reshape(train, [], n_features);
dataset.mu = mean(flat, 1);
dataset.sg = std(flat, 0, 1);
dataset.sg(dataset.sg < 1e-8) = 1;
for s = 1:3
    X = dataset.(split_names{s}).X;
    dataset.(split_names{s}).X = (X - reshape(dataset.mu, [1, 1, n_features])) ...
        ./ reshape(dataset.sg, [1, 1, n_features]);
end
dataset.lookback = lookback;
dataset.horizon = horizon;
end

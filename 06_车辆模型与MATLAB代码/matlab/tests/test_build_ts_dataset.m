function test_build_ts_dataset()
% Synthetic runs verify group isolation and training-only normalization.
runs = cell(1, 5);
for k = 1:5
    runs{k}.name = sprintf('run_%d', k);
    runs{k}.features = ones(12, 2) * k;
    runs{k}.target = ones(12, 1) * k / 10;
end
d = build_ts_dataset(runs, 4, 2, 42);
assert(isempty(intersect(d.train.run_ids, d.val.run_ids)));
assert(isempty(intersect(d.train.run_ids, d.test.run_ids)));
assert(isempty(intersect(d.val.run_ids, d.test.run_ids)));
train_values = cellfun(@(n) sscanf(n, 'run_%d'), d.train.run_ids);
assert(all(abs(d.mu - mean(train_values)) < 1e-12));
assert(size(d.test.X, 1) > 0);
assert(all(isfinite(d.train.X(:))));
ids = [1;1;2;2;3;3;4;4;5;5];
[a,b,c] = split_run_indices(ids, [0.6 0.2 0.2], true);
assert(isempty(intersect(ids(a), ids(b))));
assert(isempty(intersect(ids(a), ids(c))));
assert(isempty(intersect(ids(b), ids(c))));
try
    build_ts_dataset(runs(1:2), 4, 2, 42);
    error('Expected insufficient-runs rejection');
catch err
    assert(strcmp(err.identifier, 'ftinspect:InsufficientRuns'));
end
fprintf('PASS grouped dataset checks\n');
end

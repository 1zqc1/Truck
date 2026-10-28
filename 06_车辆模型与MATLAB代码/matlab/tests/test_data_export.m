function test_data_export()
global FT_TEST_DATA_DIR
root = 'D:/Phytium/audit-fixes/test-fixtures';
if ~exist(root, 'dir'), mkdir(root); end
FT_TEST_DATA_DIR = tempname(root); mkdir(FT_TEST_DATA_DIR);
for k = 1:5
    n = 70; results.t = (0:n-1)'*0.025;
    results.Roll = 0.1*ones(n,1); results.AVx = 0.01*ones(n,1);
    results.Ay = k*ones(n,1); results.AVz = k*ones(n,1);
    results.Vx = k*ones(n,1); results.Steer = k*ones(n,1);
    results.speed_kmh = 70; results.maneuver = 'fixture'; results.superelevation = 0;
    for j = 4:6
        results.(sprintf('Fz_L%d',j)) = 2*ones(n,1);
        results.(sprintf('Fz_R%d',j)) = 4*ones(n,1);
    end
    save(fullfile(FT_TEST_DATA_DIR, sprintf('fixture_%d.mat', k)), 'results');
end
d = data_export('export_csv', true, 'lookback', 4, 'horizon', 2, 'split_ratio', [0.6,0.2,0.2]);
assert(isempty(intersect(d.train.run_ids, d.val.run_ids)));
assert(isempty(intersect(d.train.run_ids, d.test.run_ids)));
assert(isempty(intersect(d.val.run_ids, d.test.run_ids)));
training_names = arrayfun(@(x) sprintf('fixture_%d.mat', x), d.train.run_ids, 'UniformOutput', false);
training_values = cellfun(@(x) sscanf(x, 'fixture_%d.mat'), training_names);
assert(abs(d.norm_params.mean(1) - mean(training_values)) < 1e-12);
assert(abs(d.train.Y_ltr(1,1) - 1/3) < 1e-12);
csv_data = readtable(fullfile(FT_TEST_DATA_DIR, 'csv_export', 'dataset_train.csv'));
for t = 1:4
    for f = 1:6
        assert(abs(csv_data{1,(t-1)*6+f} - d.train.X(1,t,f)) < 1e-10);
    end
end
try
    data_export('export_csv', false, 'lookback', 4, 'horizon', 2);
    error('Expected overwrite rejection');
catch err
    assert(strcmp(err.identifier, 'ftinspect:OutputExists'));
end
FT_TEST_DATA_DIR = [];
fprintf('PASS grouped data_export checks\n');
end

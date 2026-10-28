function test_process_ts_data()
% All generated data stay inside the task's disposable workspace.
root = 'D:/Phytium/audit-fixes/test-fixtures';
if ~exist(root, 'dir'), mkdir(root); end
folder = tempname(root); mkdir(folder);
n = 70;
names = {'Time','Vx','Ay','AVz','Roll_E_2','Steer_SW', ...
         'Fz_L4','Fz_L5','Fz_L6','Fz_R4','Fz_R5','Fz_R6'};
for k = 1:5
    values = [(0:n-1)'*0.025, k*ones(n,5), 2*ones(n,3), 4*ones(n,3)];
    T = array2table(values, 'VariableNames', names);
    writetable(T, fullfile(folder, sprintf('ts_fixture_%d.csv', k)));
end
d = process_ts_data(folder);
assert(isempty(intersect(d.train.run_ids, d.test.run_ids)));
assert(isempty(intersect(d.val.run_ids, d.test.run_ids)));
assert(all(abs(d.test.Y(:) - 1/3) < 1e-12));
try
    process_ts_data(folder);
    error('Expected overwrite rejection');
catch err
    assert(strcmp(err.identifier, 'ftinspect:OutputExists'));
end
bad = tempname(root); mkdir(bad);
T.Fz_L4 = [];
writetable(T, fullfile(bad, 'ts_bad.csv'));
try
    process_ts_data(bad);
    error('Expected missing wheel rejection');
catch err
    assert(strcmp(err.identifier, 'ftinspect:MissingChannel'));
end
fprintf('PASS CSV processing and missing channel checks\n');
end

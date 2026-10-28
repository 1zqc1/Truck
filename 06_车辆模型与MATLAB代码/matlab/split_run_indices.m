function [train_idx, val_idx, test_idx] = split_run_indices(run_id, ratios, shuffle)
% Assign every window from the same run to one split.
if numel(ratios) ~= 3 || any(~isfinite(ratios)) || any(ratios <= 0) || abs(sum(ratios)-1) > 1e-9
    error('ftinspect:InvalidSplit', 'Split ratios must be three positive values summing to one.');
end
groups = unique(run_id(:))';
if numel(groups) < 3
    error('ftinspect:InsufficientRuns', 'At least three independent runs are required.');
end
if shuffle, groups = groups(randperm(numel(groups))); end
n_train = max(1, floor(ratios(1)*numel(groups)));
n_val = max(1, floor(ratios(2)*numel(groups)));
if n_train+n_val >= numel(groups), n_train = numel(groups)-n_val-1; end
if n_train < 1, error('ftinspect:InvalidSplit', 'Not enough runs for the requested split.'); end
train_idx = find(ismember(run_id, groups(1:n_train)));
val_idx = find(ismember(run_id, groups(n_train+1:n_train+n_val)));
test_idx = find(ismember(run_id, groups(n_train+n_val+1:end)));
end

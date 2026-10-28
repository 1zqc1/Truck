function test_calculate_labels_safety()
r.t = (0:0.1:0.4)'; n = numel(r.t);
r.Roll = 0.2 * ones(n,1);
r.AVx = [-0.1; 0.1; 0.1; 0.1; 0.1];
r.speed_kmh = 70; r.maneuver = 'fixture'; r.superelevation = 0;
for k = 4:6
    r.(sprintf('Fz_L%d',k)) = 2*ones(n,1);
    r.(sprintf('Fz_R%d',k)) = 4*ones(n,1);
end
out = calculate_labels(r);
assert(abs(out.LTR_raw(1) - 1/3) < 1e-12);
assert(out.TTR(1) == 3);
assert(out.TTR(2) < 3);
r.Fz_R6(end) = 100;
out2 = calculate_labels(r);
assert(out2.LTR(1) == out.LTR(1));
r = rmfield(r, 'Fz_L4');
try
    calculate_labels(r);
    error('Expected missing wheel rejection');
catch err
    assert(strcmp(err.identifier, 'ftinspect:MissingWheelLoad'));
end
fprintf('PASS causal labels and wheel checks\n');
end

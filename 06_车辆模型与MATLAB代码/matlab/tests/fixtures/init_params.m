% Restricted synthetic test configuration; never add this folder to production paths.
labels.ltr.threshold_low = 0.70;
labels.ltr.threshold_high = 0.90;
labels.ttr.roll_threshold = 25*pi/180;
labels.ttr.horizon = 3.0;
global FT_TEST_DATA_DIR
if ~isempty(FT_TEST_DATA_DIR)
    output.data_dir = FT_TEST_DATA_DIR;
    output.mat_file = fullfile(FT_TEST_DATA_DIR, 'training_dataset.mat');
    output.csv_dir = fullfile(FT_TEST_DATA_DIR, 'csv_export');
    if ~exist(output.csv_dir, 'dir'), mkdir(output.csv_dir); end
end

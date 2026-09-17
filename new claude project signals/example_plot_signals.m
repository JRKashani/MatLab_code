% EXAMPLE_PLOT_SIGNALS Minimal example: generate data, then plot it.
%
% Run from a folder containing DEFINE.m, parseSignalConfig.m,
% generateSyntheticAccelSignal.m, generateColoredNoise.m,
% plotAccelerationSignals.m and example_config.txt.

generateSyntheticAccelSignal('example_config.txt', 'example_output.mat');

% Reload from the saved .mat file to demonstrate that plotting works
% directly from what generateSyntheticAccelSignal saved to disk.
D = DEFINE();
loadedData = load('example_output.mat');
signalData = loadedData.(D.MAT_ROOT_VARNAME);

[timeSeriesFigure, histogramFigure] = plotAccelerationSignals(signalData, 'figures');

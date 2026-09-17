% EXAMPLE_GENERATE_SIGNAL Minimal example: generate and inspect a signal.
%
% Run this script from a folder that also contains DEFINE.m,
% parseSignalConfig.m, generateSyntheticAccelSignal.m,
% generateColoredNoise.m and example_config.txt (i.e. this folder).

[signals, cfg] = generateSyntheticAccelSignal('example_config.txt', 'example_output.mat');

fprintf('Generated %d samples at Fs = %g Hz (%.6f s)\n', ...
    cfg.SampleCount, cfg.Fs, cfg.Duration);

time = (0:cfg.SampleCount - 1) / cfg.Fs; % reconstructed only here, for plotting

figure;
subplot(3,1,1); plot(time, signals.combinedSignal);
    title('combinedSignal'); ylabel('accel');
subplot(3,1,2); plot(time, signals.pureSineSignal);
    title('pureSineSignal'); ylabel('accel');
subplot(3,1,3); plot(time, signals.pureNoiseSignal);
    title('pureNoiseSignal'); xlabel('time [s]'); ylabel('accel');

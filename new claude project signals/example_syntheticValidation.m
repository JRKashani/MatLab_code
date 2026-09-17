%EXAMPLE_SYNTHETICVALIDATION Validate estimateTonalSNR against a known answer.
%
% Builds a synthetic signal from a KNOWN tonal component and a KNOWN
% (colored) noise realization, keeps the noise realization separately as
% `pureNoiseSignal`, and compares the estimator's overall SNR against the
% true SNR computed directly from the known components.

clear; clc; close all;

Fs = 5000;               % Hz
duration = 4;             % seconds
t = (0:1/Fs:duration - 1/Fs)';
N = numel(t);

trueFreqsHz = [75, 300, 301]; % last two intentionally close together
trueAmps = [0.5, 0.25, 0.2];

toneComponent = zeros(N, 1);
for k = 1:numel(trueFreqsHz)
    toneComponent = toneComponent + trueAmps(k) * sin(2*pi*trueFreqsHz(k)*t);
end

% Colored (not perfectly white) broadband noise, built with a simple
% first-order low-pass filter (base MATLAB `filter`, no toolbox needed),
% to mimic real accelerometer noise whose floor is not flat with frequency.
whiteNoiseForColoring = 0.08 * randn(N, 1);
noiseComponent = filter(1, [1, -0.6], whiteNoiseForColoring);

gravityOffset = -9.81;
signal = gravityOffset + toneComponent + noiseComponent;
pureNoiseSignal = noiseComponent; % the EXACT noise realization added above

sampleRange = [1, N];

result = estimateTonalSNR(signal, sampleRange, Fs, ...
    'SignalName', 'synthetic_validation', ...
    'PureNoiseSignal', pureNoiseSignal, ...
    'MakePlot', true);

fprintf('Detected %d tone(s):\n', numel(result.peakFrequenciesHz));
for k = 1:numel(result.peakFrequenciesHz)
    fprintf('  f = %7.2f Hz   band SNR = %6.1f dB\n', ...
        result.peakFrequenciesHz(k), result.peakSNRdB(k));
end

fprintf('\nEstimated overall SNR : %.2f dB\n', result.overallSNRdB);
fprintf('Ground-truth SNR      : %.2f dB\n', result.groundTruth.SNRdB);
fprintf('Estimation error      : %.2f dB\n', result.groundTruth.estimatedErrorDb);

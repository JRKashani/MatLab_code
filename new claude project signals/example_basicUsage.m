%EXAMPLE_BASICUSAGE Minimal example call to estimateTonalSNR, no ground truth.
%
% Builds a small synthetic acceleration-like signal (two tones + a
% constant "gravity" offset + white broadband noise) and runs the
% estimator on it, the way you would on real experimental data.

clear; clc; close all;

Fs = 5000;              % Hz
duration = 2;            % seconds
t = (0:1/Fs:duration - 1/Fs)';
N = numel(t);

trueFreqsHz = [120, 450];
trueAmps = [0.8, 0.3];   % m/s^2, zero-to-peak

toneComponent = trueAmps(1) * sin(2*pi*trueFreqsHz(1)*t) + ...
                trueAmps(2) * sin(2*pi*trueFreqsHz(2)*t);

noiseComponent = 0.05 * randn(N, 1);          % white broadband noise, m/s^2
gravityOffset = 9.81;                          % constant DC bias (e.g. tilted axis)

signal = gravityOffset + toneComponent + noiseComponent;

sampleRange = [1, N];

result = estimateTonalSNR(signal, sampleRange, Fs, ...
    'SignalName', 'demo_axis', ...
    'MakePlot', true);

fprintf('Removed mean (DC) acceleration: %.4f\n', result.meanAcceleration);
fprintf('Detected %d tone(s):\n', numel(result.peakFrequenciesHz));
for k = 1:numel(result.peakFrequenciesHz)
    fprintf('  f = %7.2f Hz   band SNR = %6.1f dB\n', ...
        result.peakFrequenciesHz(k), result.peakSNRdB(k));
end
fprintf('Overall SNR = %.2f dB (converged = %d, iterations = %d)\n', ...
    result.overallSNRdB, result.converged, result.iterationCount);

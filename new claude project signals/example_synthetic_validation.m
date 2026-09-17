%EXAMPLE_SYNTHETIC_VALIDATION Validate the estimator against known ground truth.
%
%   Builds a synthetic acceleration signal from KNOWN sine components
%   plus a KNOWN noise realization (kept in a separate variable,
%   pureNoise), then passes that noise realization to estimateTonalSNR
%   via 'PureNoiseSignal' so it can compare its spectral estimate
%   against the exact ground-truth SNR.
%
%   This is the primary validation check described in the estimator's
%   design brief: for a stationary recording with known full-duration
%   sine waves plus known broadband noise, the estimated dominant
%   frequencies should match the sine frequencies, and the estimated
%   SNR should approach the known ground-truth value.

Fs = 4000;                                 % Hz
durationSec = 5;
t = (0:round(Fs*durationSec) - 1)' / Fs;

trueTones = [ ...     % [Hz, amplitude]
    200,  0.6;
    733,  0.25];

pureNoise = 0.10 * randn(size(t));         % KNOWN noise-only realization

tonalPart = zeros(size(t));
for k = 1:size(trueTones, 1)
    tonalPart = tonalPart + trueTones(k,2) * sin(2*pi*trueTones(k,1)*t);
end

accel = tonalPart + pureNoise;             % measured signal (no DC here)

sampleRange = [1, numel(accel)];

result = estimateTonalSNR(accel, sampleRange, Fs, ...
    'SignalName', 'synthetic_validation', ...
    'PureNoiseSignal', pureNoise, ...
    'MakePlot', true);

fprintf('True tone frequencies (Hz):        %s\n', mat2str(trueTones(:,1)'));
fprintf('Detected tone frequencies (Hz):    %s\n', mat2str(result.peakFrequenciesHz', 4));
fprintf('Estimated overall SNR:  %.2f dB\n', result.overallSNRdB);
fprintf('Ground-truth overall SNR: %.2f dB\n', result.groundTruth.SNRdB);
fprintf('Estimation error: %.2f dB\n', result.groundTruth.estimatedErrorDb);

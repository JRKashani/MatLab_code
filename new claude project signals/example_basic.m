%EXAMPLE_BASIC Minimal call to estimateTonalSNR, no ground truth.
%
%   Builds a short synthetic acceleration snippet (gravity offset + one
%   tone + broadband noise) purely to have something to run the
%   estimator on, then calls estimateTonalSNR the way you would on real
%   data: no pureNoiseSignal, defaults for every detection parameter.

Fs = 5000;                                % Hz
t = (0:Fs*2 - 1)' / Fs;                   % 2 seconds

gravityOffset = 9.81 * 0.02;              % small DC from axis tilt
accel = gravityOffset ...
      + 0.8 * sin(2*pi*120*t) ...         % one tonal component, 120 Hz
      + 0.15 * randn(size(t));            % broadband noise

sampleRange = [1, numel(accel)];

result = estimateTonalSNR(accel, sampleRange, Fs, ...
    'SignalName', 'demo_axis', ...
    'MakePlot', true);

fprintf('Removed mean (DC): %.4f\n', result.meanAcceleration);
fprintf('Detected tones: %d\n', numel(result.peakFrequenciesHz));
for k = 1:numel(result.peakFrequenciesHz)
    fprintf('  #%d: %.2f Hz, local SNR = %.2f dB\n', ...
        k, result.peakFrequenciesHz(k), result.peakSNRdB(k));
end
fprintf('Overall SNR: %.2f dB (%d iteration(s), converged = %d)\n', ...
    result.overallSNRdB, result.iterationCount, result.converged);

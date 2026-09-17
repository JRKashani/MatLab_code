function groundTruth = computeGroundTruthComparison(pureNoiseSignal, totalSamples, ...
    startSample, endSample, measuredDetrended, overallSNRdB)
%COMPUTEGROUNDTRUTHCOMPARISON Compare the iterative SNR estimate against
% a known ground truth, for synthetic-data validation only.
%
% groundTruth = computeGroundTruthComparison(pureNoiseSignal, totalSamples, ...
%     startSample, endSample, measuredDetrended, overallSNRdB)
%
% Inputs:
%   pureNoiseSignal   - the exact noise realization that was added to
%                        produce the analyzed `signal` (same length as
%                        the full original signal), or [] if unavailable
%   totalSamples      - numel of the full original `signal` vector, used
%                        only to check that pureNoiseSignal is compatible
%   startSample, endSample - the same sample range analyzed for `signal`
%   measuredDetrended - the analyzed signal snippet with its own mean
%                        already removed (signal(range) - mean(signal(range)))
%   overallSNRdB      - the estimator's overall SNR result, in dB, used
%                        only to report the estimation error
%
% Output: a struct with fields
%   groundTruth.available         - true if pureNoiseSignal was supplied
%   groundTruth.trueSignalPower   - true mean-square tonal power
%   groundTruth.trueNoisePower    - true mean-square noise power
%   groundTruth.SNRdB             - true SNR, in dB
%   groundTruth.estimatedErrorDb  - (estimated overallSNRdB) - (true SNRdB)
%
% ---------------------------------------------------------------------
% ASSUMPTIONS (synthetic validation only)
% ---------------------------------------------------------------------
% This assumes the analyzed signal was built as
%     signal = knownTonalComponent + pureNoiseSignal
% (i.e. pureNoiseSignal is the exact noise time series added while
% generating the synthetic test signal, not merely "noise of the same
% statistics"). Under that assumption:
%     knownSignal = measuredSignal - knownNoise
% recovers the exact tonal component in the time domain, so its power
% can be computed directly (mean of its square) without needing any
% spectral estimation at all - this is the ground truth the iterative,
% spectral estimate is compared against.
%
% DC HANDLING: both the measured snippet and the noise snippet have
% their own mean removed independently before computing power. This
% mirrors how the main estimator treats DC (a constant offset, such as a
% gravity projection, is neither a tone nor noise) and is consistent as
% long as the pure-noise reference itself is not deliberately carrying a
% meaningful nonzero mean of its own.
%
% This validation path is never used by, or required for, ordinary
% real-data analysis - it exists purely to let users test the estimator
% against a known answer.
% ---------------------------------------------------------------------

if isempty(pureNoiseSignal)
    groundTruth = struct( ...
        'available', false, ...
        'trueSignalPower', NaN, ...
        'trueNoisePower', NaN, ...
        'SNRdB', NaN, ...
        'estimatedErrorDb', NaN);
    return;
end

if numel(pureNoiseSignal) ~= totalSamples
    error('estimateTonalSNR:PureNoiseSizeMismatch', ...
        ['pureNoiseSignal must have the same number of samples as signal ' ...
         '(signal has %d, pureNoiseSignal has %d).'], totalSamples, numel(pureNoiseSignal));
end

% This is the one permitted temporary copy of pureNoiseSignal: only the
% analyzed sample range, exactly mirroring how `signal` itself is sliced.
noiseSnippet = double(pureNoiseSignal(startSample:endSample));
noiseSnippet = noiseSnippet(:);

if any(~isfinite(noiseSnippet))
    error('estimateTonalSNR:NonFinitePureNoise', ...
        'pureNoiseSignal contains NaN or Inf values within the selected sample range.');
end

noiseSnippet = noiseSnippet - mean(noiseSnippet);

knownSignal = measuredDetrended(:) - noiseSnippet;

trueSignalPower = mean(knownSignal.^2);
trueNoisePower  = mean(noiseSnippet.^2);

if trueNoisePower > 0
    trueSNRdB = 10 * log10(trueSignalPower / trueNoisePower);
else
    trueSNRdB = Inf;
end

groundTruth.available = true;
groundTruth.trueSignalPower = trueSignalPower;
groundTruth.trueNoisePower = trueNoisePower;
groundTruth.SNRdB = trueSNRdB;
groundTruth.estimatedErrorDb = overallSNRdB - trueSNRdB;
end

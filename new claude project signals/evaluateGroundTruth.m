function groundTruth = evaluateGroundTruth(signal, pureNoiseSignal, sampleRange, meanAcceleration, estimatedOverallSNRdB)
%EVALUATEGROUNDTRUTH Compare the iterative estimator against known synthetic ground truth.
%
%   groundTruth = EVALUATEGROUNDTRUTH(signal, pureNoiseSignal, ...
%       sampleRange, meanAcceleration, estimatedOverallSNRdB)
%
%   This function exists ONLY to validate the estimator against
%   synthetic data for which the true noise-only realization is known.
%   It plays no role in normal analysis of real experimental data --
%   estimateTonalSNR never requires pureNoiseSignal, and this function is
%   only called when the caller explicitly supplies it.
%
%   Using the SAME sampleRange as the main estimate:
%     1) validates that pureNoiseSignal is a compatible, finite vector
%        over that range,
%     2) extracts the matching pureNoiseSignal snippet and removes ITS
%        OWN mean -- the noise reference's own DC offset should not be
%        counted as noise power any more than the measured signal's DC
%        should be counted as a tone ("treating DC consistently"),
%     3) reconstructs the known tonal-only component as
%           knownSignal = (measuredSignal - meanAcceleration) ...
%                         - (pureNoise - mean(pureNoise))
%        i.e. the measured, detrended signal minus the detrended known
%        noise realization,
%     4) computes true powers directly as mean-square values (this is
%        exact ground truth from the known synthetic components, not a
%        spectral estimate), and the true SNR,
%     5) compares the true SNR to the iterative estimator's overall SNR.
%
%   Inputs:
%       signal                - full original acceleration vector
%       pureNoiseSignal       - full noise-only reference vector, same
%                               length as signal (synthetic data only)
%       sampleRange            - [startSample, endSample], identical to
%                               the range used for the main estimate
%       meanAcceleration       - mean of signal(sampleRange), as computed
%                               by estimateTonalSNR, used so both the
%                               main estimate and this comparison remove
%                               exactly the same DC value from the
%                               measured signal
%       estimatedOverallSNRdB  - the iterative estimator's overall SNR
%                               in dB (result.overallSNRdB)
%   Output:
%       groundTruth - struct with fields:
%           .available        (true)
%           .trueSignalPower  - mean-square power of the known tonal-only
%                               component
%           .trueNoisePower   - mean-square power of the detrended known
%                               noise realization
%           .SNRdB            - true SNR in dB
%           .estimatedErrorDb - result.overallSNRdB - groundTruth.SNRdB

    if numel(pureNoiseSignal) ~= numel(signal)
        error('evaluateGroundTruth:sizeMismatch', ...
            'pureNoiseSignal must have the same number of samples as signal (got %d, expected %d).', ...
            numel(pureNoiseSignal), numel(signal));
    end

    noiseSnippet = pureNoiseSignal(sampleRange(1):sampleRange(2));
    noiseSnippet = noiseSnippet(:);

    if any(~isfinite(noiseSnippet))
        error('evaluateGroundTruth:nonfiniteData', ...
            'pureNoiseSignal contains NaN/Inf values within the requested sample range.');
    end

    measuredSnippet = signal(sampleRange(1):sampleRange(2));
    measuredSnippet = measuredSnippet(:);

    noiseMean = mean(noiseSnippet);

    measuredDetrended = measuredSnippet - meanAcceleration;
    noiseDetrended = noiseSnippet - noiseMean;

    knownSignal = measuredDetrended - noiseDetrended;

    trueNoisePower = mean(noiseDetrended.^2);
    trueSignalPower = mean(knownSignal.^2);

    if trueNoisePower > 0
        trueSNRdB = 10 * log10(trueSignalPower / trueNoisePower);
    else
        trueSNRdB = Inf;
    end

    groundTruth.available = true;
    groundTruth.trueSignalPower = trueSignalPower;
    groundTruth.trueNoisePower = trueNoisePower;
    groundTruth.SNRdB = trueSNRdB;
    groundTruth.estimatedErrorDb = estimatedOverallSNRdB - trueSNRdB;
end

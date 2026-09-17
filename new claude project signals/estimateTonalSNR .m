function result = estimateTonalSNR(signal, sampleRange, Fs, options)
%ESTIMATETONALSNR Iterative estimate of tonal (sinusoidal) SNR in
% acceleration data containing tonal/sinusoidal components mixed with
% broadband noise.
%
% result = estimateTonalSNR(signal, sampleRange, Fs)
% result = estimateTonalSNR(signal, sampleRange, Fs, 'Name', Value, ...)
%
% ---------------------------------------------------------------------
% SCOPE AND LIMITATIONS (read this first)
% ---------------------------------------------------------------------
% This function estimates SNR under one specific, explicit model:
%
%       measured signal  =  narrowband tonal peaks  +  broadband noise
%
% It is NOT a universal vibration/noise separator. In particular:
%   - Broadband physical vibration (not narrowband) will be counted as
%     "noise", not as signal, because this method has no way to
%     distinguish it from instrument/electrical noise spectrally.
%   - Very closely spaced tones may be merged into a single detection.
%   - Weak tones below the detection threshold will not be reported.
%   - Colored (frequency-dependent) noise is handled via a LOCAL noise
%     floor estimate, but if that floor is mis-tuned (see the parameter
%     descriptions below) results can be biased.
%   - The estimate depends on the chosen detection/noise-floor
%     parameters. ALWAYS inspect the diagnostic plot before trusting an
%     SNR number from unfamiliar real data.
%
% ---------------------------------------------------------------------
% REQUIRED INPUTS
% ---------------------------------------------------------------------
%   signal      - original acceleration data vector (only the requested
%                 sampleRange is ever copied/analyzed; the full vector is
%                 read but never duplicated or modified)
%   sampleRange - [startSample, endSample], 1-based, inclusive
%   Fs          - sampling frequency, Hz
%
% ---------------------------------------------------------------------
% OPTIONAL NAME-VALUE INPUTS (all have sensible defaults)
% ---------------------------------------------------------------------
%   SignalName              (char)    default 'signal'
%       Descriptive name used in plot titles and saved filenames.
%
%   OutputFolder            (char)    default pwd
%       Folder that saved figures are written into (created if it does
%       not exist). MATLAB's current working directory is never changed.
%
%   PureNoiseSignal         (vector)  default []
%       Optional, same length as `signal`. Supplying this activates the
%       synthetic ground-truth validation path (see below). Ordinary
%       real-data analysis does not need, and must not depend on, this
%       input - it exists purely to test the estimator.
%
%   MakePlot                (logical) default true
%       Whether to create the diagnostic figure at all.
%   SaveFig                 (logical) default false
%   SavePng                 (logical) default false
%       Independent flags to also save the figure as .fig and/or .png.
%
%   NoiseFloorWindowHz      (double)  default 50
%       Width, in Hz, of the local moving-median window used to estimate
%       the (possibly colored) noise floor. Must be wide enough that one
%       narrow tone cannot dominate its own local window (otherwise the
%       floor would be pulled up right under every tone, hiding it), but
%       narrow enough to still track real, slower changes in a colored
%       noise floor. As a rule of thumb, pick this several times wider
%       than the expected width of a single tone's leakage skirt, but
%       narrow compared to the frequency scale over which the noise
%       character actually changes.
%
%   DetectionThresholdDb    (double)  default 6
%       How far (in dB) the measured PSD must rise above the local noise
%       floor to be flagged as a candidate tone (6 dB ~= 4x the local
%       noise power). Because this is a SINGLE, unaveraged periodogram,
%       individual noise-only bins already fluctuate substantially
%       around the true floor (roughly exponentially distributed, with
%       standard deviation comparable to the mean) - a low threshold
%       will flag many ordinary noise fluctuations as "tones". Raise
%       this if you see obvious false detections; lower it (cautiously)
%       if a known weak tone is being missed.
%
%   MinTonalBandwidthHz     (double)  default 0
%       Minimum width, in Hz, enforced for every detected tonal region
%       (0 = no artificial minimum beyond natural detection/expansion).
%
%   ToneExpansionBins       (integer) default 2
%   MergeGapBins            (integer) default 2
%       A Hann window's main lobe is about 4 bins wide in total (about 2
%       bins on either side of the peak), independent of FFT length,
%       because bin spacing (df = Fs/N) shrinks with N at exactly the
%       rate the main lobe does. ToneExpansionBins grows each detected
%       region by this many bins on each side to capture that leakage
%       skirt; MergeGapBins merges above-threshold runs separated by
%       this many bins or fewer into one region, so one broadened peak
%       is not reported as several tones. Increase both for longer FFTs
%       relative to expected tone spacing, or if you see one physical
%       tone reported as multiple close peaks.
%
%   MaxIterations           (integer) default 10
%       Hard cap on refinement iterations; guarantees termination even
%       if detected regions were to oscillate rather than settle.
%
%   ConvergenceTol          (double)  default 0
%       Maximum fraction of frequency bins allowed to change tonal /
%       non-tonal classification between iterations for convergence to
%       be declared. 0 requires an exact match between iterations.
%
%   MinFrequencyHz          (double)  default 0
%       Bins below this frequency are never classified as tonal and are
%       excluded from the total noise/tonal power sums used for the
%       overall SNR (they are still shown in the returned spectrum).
%       Useful if DC-removal leakage or very-low-frequency rig motion
%       would otherwise be misread as a tone near 0 Hz.
%
%   UseParabolicInterpolation (logical) default true
%       Refine each peak's reported frequency with a simple quadratic
%       (log-PSD) interpolation across its 3 center bins, rather than
%       reporting only the (coarser) integer FFT bin frequency.
%
% ---------------------------------------------------------------------
% SPECTRAL POWER / SNR DEFINITIONS USED HERE
% ---------------------------------------------------------------------
% All powers below are mean-square quantities (physical units squared),
% obtained by integrating (summing * df) an appropriately normalized
% one-sided PSD - see computeOneSidedPSD.m for the full normalization
% derivation, and computeBandPowers.m for the exact per-band sums.
%
% For each detected tonal region ("band"):
%   P_tone(band)  = sum_over_band( max(PSD - PSD_noise, 0) ) * df   (excess/tonal power)
%   P_noise(band) = sum_over_band( PSD_noise )                * df   (local noise power)
%   SNR_tone_dB   = 10*log10( P_tone(band) / P_noise(band) )
% This is explicitly a LOCAL/BAND SNR for that one tone, not a global
% quantity.
%
% Overall:
%   P_all_tones   = sum over all detected bands of P_tone(band)
%   P_total_noise = sum of PSD_noise * df over the entire analyzed
%                   frequency range (including underneath every detected
%                   tone, and excluding only bins below MinFrequencyHz)
%   SNR_overall_dB = 10*log10( P_all_tones / P_total_noise )
%
% ---------------------------------------------------------------------
% ITERATIVE ALGORITHM (summary; see estimateLocalNoiseFloor.m and
% detectTonalRegions.m for the full reasoning behind each step)
% ---------------------------------------------------------------------
%   1. Compute the one-sided PSD once (this does NOT change across
%      iterations - only the "which bins are noise vs. tone" masking
%      does).
%   2. With no bins excluded yet, estimate an initial local noise floor
%      (robust local median, bias-corrected - never a plain global mean).
%   3-5. Flag bins that rise far enough above that local floor, group
%      adjacent/nearby flagged bins into tonal regions.
%   6. Re-estimate the local noise floor, this time excluding the
%      currently-detected tonal regions, so tones no longer pull their
%      own local floor upward.
%   7. Repeat steps 3-6 until the set of detected tonal bins stops
%      changing (within ConvergenceTol) or MaxIterations is reached.
%
% ---------------------------------------------------------------------
% OUTPUTS (result struct fields)
% ---------------------------------------------------------------------
% See the accompanying README for a full description of every field.
% Briefly: result.meanAcceleration, .frequencyHz, .measuredPSD,
% .estimatedNoisePSD, .peakFrequenciesHz, .peakBandsHz,
% .peakSignalPower, .peakNoisePower, .peakSNRdB, .totalTonalPower,
% .totalEstimatedNoisePower, .overallSNRdB, .overallSNRLinear,
% .tonesDetected, .frequencyResolutionHz, .sampleRange, .sampleCount,
% .iterationCount, .converged, .groundTruth, .signalName, .parameters.
%
% ---------------------------------------------------------------------
% COMPUTATIONAL COMPLEXITY
% ---------------------------------------------------------------------
% The FFT (computed once, not per iteration) costs O(N log N), N =
% numel of the analyzed range. Each refinement iteration works on the
% one-sided spectrum (M ~= N/2 bins): the moving median costs
% approximately O(M log w) for window width w, and detection/grouping is
% O(M). With MaxIterations capped (default 10), total cost is dominated
% by the single initial FFT for all but extremely short analysis ranges.

arguments
    signal double
    sampleRange double
    Fs (1,1) double
    options.SignalName (1,:) char = 'signal'
    options.OutputFolder (1,:) char = pwd
    options.PureNoiseSignal double = []
    options.MakePlot (1,1) logical = true
    options.SaveFig (1,1) logical = false
    options.SavePng (1,1) logical = false
    options.NoiseFloorWindowHz (1,1) double {mustBePositive} = 50
    options.DetectionThresholdDb (1,1) double = 6
    options.MinTonalBandwidthHz (1,1) double {mustBeNonnegative} = 0
    options.ToneExpansionBins (1,1) double {mustBeNonnegative, mustBeInteger} = 2
    options.MergeGapBins (1,1) double {mustBeNonnegative, mustBeInteger} = 2
    options.MaxIterations (1,1) double {mustBePositive, mustBeInteger} = 10
    options.ConvergenceTol (1,1) double {mustBeNonnegative} = 0
    options.MinFrequencyHz (1,1) double {mustBeNonnegative} = 0
    options.UseParabolicInterpolation (1,1) logical = true
end

% ======================================================================
% INPUT VALIDATION (fail loudly and clearly on genuinely invalid input;
% "no tones found" / "zero noise power" / "did not converge" are NOT
% treated as errors - they are valid outcomes returned in the result)
% ======================================================================

if ~isvector(signal) || isempty(signal)
    error('estimateTonalSNR:InvalidSignal', 'signal must be a non-empty vector.');
end
totalSamples = numel(signal);

if ~isfinite(Fs) || Fs <= 0
    error('estimateTonalSNR:InvalidFs', 'Fs must be a finite, positive scalar (Hz).');
end

if numel(sampleRange) ~= 2 || any(~isfinite(sampleRange))
    error('estimateTonalSNR:InvalidSampleRange', ...
        'sampleRange must be a 2-element vector [startSample, endSample].');
end

startSample = round(sampleRange(1));
endSample = round(sampleRange(2));

if startSample < 1 || endSample > totalSamples || startSample >= endSample
    error('estimateTonalSNR:InvalidSampleRange', ...
        ['sampleRange [%d, %d] is invalid for a signal with %d samples. ' ...
         'Require 1 <= startSample < endSample <= numel(signal).'], ...
        startSample, endSample, totalSamples);
end

sampleCount = endSample - startSample + 1;
MIN_SAMPLES_REQUIRED = 8; % need enough points for a meaningful windowed FFT
if sampleCount < MIN_SAMPLES_REQUIRED
    error('estimateTonalSNR:RangeTooShort', ...
        'Selected sample range has only %d samples; at least %d are required.', ...
        sampleCount, MIN_SAMPLES_REQUIRED);
end

% This is the ONE permitted temporary copy of (part of) the signal.
snippet = double(signal(startSample:endSample));
snippet = snippet(:);

if any(~isfinite(snippet))
    error('estimateTonalSNR:NonFiniteData', ...
        'Selected sample range contains NaN or Inf values.');
end

meanAcceleration = mean(snippet);
detrended = snippet - meanAcceleration;

ZERO_SIGNAL_TOL = 10 * eps(class(detrended)) * max(1, max(abs(snippet)));
if max(abs(detrended)) < ZERO_SIGNAL_TOL
    error('estimateTonalSNR:ZeroSignal', ...
        'Signal in the selected range is (numerically) constant/zero after removing the mean; nothing to analyze.');
end

% ======================================================================
% SPECTRAL SETUP
% ======================================================================

[freqHz, psd, df] = computeOneSidedPSD(detrended, Fs);
M = numel(freqHz);

excludedFromAnalysis = freqHz < options.MinFrequencyHz; % never "tonal"; excluded from power totals

MIN_NOISE_WINDOW_BINS = 9; % need enough independent bins for a median to be a meaningful robust statistic
windowBins = max(round(options.NoiseFloorWindowHz / df), MIN_NOISE_WINDOW_BINS);
windowBins = min(windowBins, M);

minBandwidthBins = ceil(options.MinTonalBandwidthHz / df);

% ======================================================================
% ITERATIVE NOISE-FLOOR / TONE-DETECTION LOOP
% ======================================================================

tonalMask = false(M, 1); % start with nothing excluded from the noise estimate
converged = false;
finalRegions = zeros(0, 2);

for iter = 1:options.MaxIterations
    noiseFloor = estimateLocalNoiseFloor(psd, tonalMask, windowBins);

    [newTonalMask, regions] = detectTonalRegions(psd, noiseFloor, ...
        options.DetectionThresholdDb, options.MergeGapBins, options.ToneExpansionBins, ...
        minBandwidthBins, excludedFromAnalysis);

    changedFraction = sum(newTonalMask ~= tonalMask) / M;

    tonalMask = newTonalMask;
    finalRegions = regions;

    if changedFraction <= options.ConvergenceTol
        converged = true;
        break;
    end
end
iterationCount = iter;

% Re-estimate the noise floor once more so the RETURNED noise PSD is
% consistent with the final detected tonal mask (inside the loop above,
% noiseFloor was computed from the PREVIOUS iteration's mask).
noiseFloor = estimateLocalNoiseFloor(psd, tonalMask, windowBins);

if ~converged
    warning('estimateTonalSNR:DidNotConverge', ...
        'Tonal-region detection did not converge within %d iterations; returning the last computed estimate.', ...
        options.MaxIterations);
end

% ======================================================================
% PER-TONE POWER / SNR
% ======================================================================

numPeaks = size(finalRegions, 1);
peakFrequenciesHz = zeros(numPeaks, 1);
peakBandsHz = zeros(numPeaks, 2);
peakSignalPower = zeros(numPeaks, 1);
peakNoisePower = zeros(numPeaks, 1);
peakSNRdB = zeros(numPeaks, 1);

for p = 1:numPeaks
    region = finalRegions(p, :);

    peakFrequenciesHz(p) = computeRegionPeakFrequency(psd, freqHz, region, options.UseParabolicInterpolation);
    peakBandsHz(p, :) = freqHz(region)';

    [sp, np] = computeBandPowers(psd, noiseFloor, region, df);
    peakSignalPower(p) = sp;
    peakNoisePower(p) = np;

    if np > 0
        peakSNRdB(p) = 10*log10(sp / np);
    else
        peakSNRdB(p) = Inf; % essentially zero estimated noise within this narrow band
    end

    if region(1) == 1 || region(2) == M
        warning('estimateTonalSNR:EdgeTone', ...
            ['Detected tone %d touches the analyzed frequency edge (near 0 Hz or Nyquist); ' ...
             'its band power/SNR may be less reliable because the leakage skirt is truncated on one side.'], p);
    end
end

% ======================================================================
% OVERALL SNR
% ======================================================================

totalTonalPower = sum(peakSignalPower);
totalEstimatedNoisePower = sum(noiseFloor(~excludedFromAnalysis)) * df;

tonesDetected = numPeaks > 0;

if totalEstimatedNoisePower <= 0 || ~isfinite(totalEstimatedNoisePower)
    overallSNRdB = NaN;
    overallSNRLinear = NaN;
    warning('estimateTonalSNR:ZeroNoisePower', ...
        'Estimated total noise power is zero or invalid; overall SNR cannot be computed.');
elseif ~tonesDetected
    overallSNRLinear = 0;
    overallSNRdB = -Inf; % no tonal power detected: report cleanly rather than manufacture a value
else
    overallSNRLinear = totalTonalPower / totalEstimatedNoisePower;
    overallSNRdB = 10*log10(overallSNRLinear);
end

% ======================================================================
% OPTIONAL SYNTHETIC GROUND-TRUTH VALIDATION
% ======================================================================

groundTruth = computeGroundTruthComparison(options.PureNoiseSignal, totalSamples, ...
    startSample, endSample, detrended, overallSNRdB);

% ======================================================================
% ASSEMBLE RESULT
% ======================================================================

result = struct();
result.meanAcceleration = meanAcceleration;
result.frequencyHz = freqHz;
result.measuredPSD = psd;
result.estimatedNoisePSD = noiseFloor;

result.peakFrequenciesHz = peakFrequenciesHz;
result.peakBandsHz = peakBandsHz;
result.peakSignalPower = peakSignalPower;
result.peakNoisePower = peakNoisePower;
result.peakSNRdB = peakSNRdB;

result.totalTonalPower = totalTonalPower;
result.totalEstimatedNoisePower = totalEstimatedNoisePower;
result.overallSNRdB = overallSNRdB;
result.overallSNRLinear = overallSNRLinear;
result.tonesDetected = tonesDetected;

result.frequencyResolutionHz = df;
result.sampleRange = [startSample, endSample];
result.sampleCount = sampleCount;

result.iterationCount = iterationCount;
result.converged = converged;

result.groundTruth = groundTruth;

result.signalName = options.SignalName;
result.parameters = rmfield(options, {'PureNoiseSignal'}); % record settings used, excluding bulky data

% ======================================================================
% DIAGNOSTIC PLOT
% ======================================================================
% Pass the already-stripped parameters struct (not the raw `options`)
% so the plotting helper never receives a reference to the (possibly
% large) PureNoiseSignal vector at all.

if options.MakePlot
    plotSNRDiagnostic(result, result.parameters);
end

end

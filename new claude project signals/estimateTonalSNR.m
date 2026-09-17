function result = estimateTonalSNR(signal, sampleRange, Fs, options)
%ESTIMATETONALSNR Iteratively estimate tonal (sinusoidal) SNR in acceleration data.
%
%   result = ESTIMATETONALSNR(signal, sampleRange, Fs)
%   result = ESTIMATETONALSNR(signal, sampleRange, Fs, Name, Value, ...)
%
%   -------------------------------------------------------------------
%   SCOPE AND LIMITATION -- READ THIS FIRST
%   -------------------------------------------------------------------
%   This function estimates TONAL SNR: it separates NARROWBAND
%   SINUSOIDAL/TONAL components from BROADBAND NOISE in the frequency
%   domain. It is NOT a general-purpose method for separating arbitrary
%   "vibration" from arbitrary "noise" -- a physical vibration signal
%   that is itself broadband (e.g. impacts, random structural
%   vibration, turbulence) will be classified as part of the noise
%   floor, not as a detected "tone", however physically real it is.
%   Only use the numeric SNR output for components that are genuinely
%   narrowband relative to the analyzed bandwidth.
%
%   -------------------------------------------------------------------
%   WHAT THIS FUNCTION DOES, IN ONE PARAGRAPH
%   -------------------------------------------------------------------
%   1) Take the requested sample range, record and remove its mean
%      (DC / gravity-projection offset).
%   2) Compute a properly normalized, Hann-windowed, one-sided power
%      spectral density (PSD) of the detrended snippet.
%   3) Iteratively: estimate a robust, frequency-varying (colored-noise
%      aware) broadband noise floor -> find bins that rise far enough
%      above it -> validate and group those bins into tonal regions ->
%      exclude them and re-estimate the floor -> repeat until the
%      detected regions stop changing (or a max iteration count is hit).
%   4) For each final tonal region, compute its excess power above the
%      floor and a local/band SNR. Sum all tonal excess power and
%      compare it to the total estimated noise power over the whole
%      analyzed range to get one overall tonal SNR.
%   5) Optionally compare against a known, synthetic noise-only
%      reference signal, and draw one diagnostic plot.
%
%   -------------------------------------------------------------------
%   POWER / SNR DEFINITIONS (be precise about these -- see also the
%   header comments in computeOneSidedPSD.m, estimateLocalNoiseFloor.m,
%   detectTonalRegions.m and computeBandPowers.m for the reasoning
%   behind each step)
%   -------------------------------------------------------------------
%   PSD, not amplitude spectrum: Pxx(f) has units (signal units)^2/Hz.
%   SNR is always a ratio of POWERS (integrals of PSD over a frequency
%   band), never a ratio of raw amplitude-spectrum values.
%
%   For one detected tonal region ("band"):
%       P_tone(band)  = sum_{f in band} max(Pxx(f) - Pxx_noise(f), 0) * df
%       P_noise(band) = sum_{f in band} Pxx_noise(f) * df
%       SNR_tone_dB   = 10*log10( P_tone(band) / P_noise(band) )
%   This is a LOCAL/BAND SNR for that one tone -- see result.peakSNRdB.
%
%   Overall SNR, across the whole analyzed frequency range:
%       P_tones_total = sum over all detected bands of P_tone(band)
%       P_noise_total = sum_{f in analyzed range} Pxx_noise(f) * df
%                       (this INCLUDES the estimated noise power
%                       underneath every detected tone, from the smooth
%                       noise-floor curve, not from the raw PSD there)
%       overallSNR_dB = 10*log10( P_tones_total / P_noise_total )
%   See result.overallSNRdB. This is the definition used throughout;
%   do not assume it matches some other convention (e.g. it is not a
%   ratio of RMS values, and it is not a per-Hz quantity).
%
%   -------------------------------------------------------------------
%   REQUIRED INPUTS
%   -------------------------------------------------------------------
%       signal      - full original acceleration vector. Only the
%                     requested sampleRange is ever copied/analyzed; the
%                     full vector itself is not duplicated or modified.
%       sampleRange - [startSample, endSample], 1-based, inclusive,
%                     integers, startSample <= endSample <= numel(signal)
%       Fs          - sampling frequency in Hz (positive, finite scalar)
%
%   -------------------------------------------------------------------
%   OPTIONAL NAME-VALUE INPUTS (defaults shown; see "PARAMETER
%   SENSITIVITY" below for how each one affects the result)
%   -------------------------------------------------------------------
%       SignalName          (string,  default "signal")
%           Descriptive name used in the plot title and saved filenames.
%       OutputFolder        (string,  default ".")
%           Folder for saved plot files. Created if it does not exist.
%           MATLAB's current working directory is never changed.
%       PureNoiseSignal     (double,  default [])
%           Optional full-length noise-only reference vector for
%           synthetic-data validation (see "GROUND-TRUTH VALIDATION"
%           below). Leave empty for normal use on real data.
%       SaveFIG             (logical, default false)
%       SavePNG             (logical, default false)
%           Independently save the diagnostic figure as .fig and/or .png.
%       MakePlot            (logical, default true)
%           Set false to skip creating the diagnostic figure entirely.
%       NoiseFloorWindowHz  (double,  default 50)
%           Width, in Hz, of the moving-median window used to estimate
%           the local noise floor.
%       ThresholdDB         (double,  default 9)
%           How far (in dB) a bin must rise above the local noise floor
%           to be flagged as a raw tonal-region candidate.
%       MinBandWidthBins    (double,  default 3)
%           Minimum number of CONSECUTIVE raw-threshold bins required
%           before a candidate region is accepted (false-alarm control;
%           see detectTonalRegions.m).
%       ExpandBins          (double,  default 2)
%           Number of bins each validated tonal region is expanded by,
%           on each side, to capture leakage skirt.
%       MaxIterations       (double,  default 20)
%           Hard cap on noise-floor/detection iterations.
%       MinFrequencyHz      (double,  default 0)
%           Exclude bins below this frequency from the ENTIRE analysis
%           (noise floor estimation, detection, and power totals). Use
%           this if you want to explicitly ignore a DC-adjacent region
%           (e.g. very low-frequency drift) rather than relying solely
%           on mean removal.
%
%   -------------------------------------------------------------------
%   PARAMETER SENSITIVITY (how each setting changes the result)
%   -------------------------------------------------------------------
%   NoiseFloorWindowHz: narrower -> floor tracks colored noise more
%       closely, but a wide/strong tone can bias its own local floor
%       upward (making it look weaker) if the window is comparable to
%       or narrower than the tone's leakage skirt. Wider -> floor is
%       more statistically stable but blind to real narrowband changes
%       in noise color.
%   ThresholdDB: higher -> fewer false-positive "tones" from noise
%       fluctuations, but weak real tones can be missed. Lower -> more
%       sensitive to weak tones, but more prone to false detections.
%       Because a single-segment periodogram bin is noisy (see
%       estimateLocalNoiseFloor.m), thresholds much below ~6-9 dB
%       combined with a spectrum of many bins tend to produce spurious
%       detections purely from noise statistics; this was verified
%       empirically during development of the default values below.
%   MinBandWidthBins: higher -> stronger false-alarm rejection (fewer
%       spurious single/double-bin noise spikes reported as tones), but
%       can reject a genuinely very narrow, weakly-leaking tone if set
%       too high relative to the true mainlobe width of the window for
%       your chosen segment length.
%   ExpandBins: higher -> more of a tone's leakage skirt is folded into
%       its reported power (more complete P_tone), but closely spaced
%       tones are more likely to merge into one reported region, and the
%       region can encroach on true local noise bins.
%   MaxIterations: a safety cap only; the loop stops earlier as soon as
%       detected regions stop changing between iterations (that
%       equality check is the convergence criterion -- see
%       result.converged / result.iterationCount). Raising this rarely
%       changes results in practice; it mainly protects against
%       oscillation in pathological parameter combinations.
%   MinFrequencyHz: raising this deliberately shrinks the analyzed
%       band; total noise power, overall SNR, and any tone below this
%       frequency are all excluded from the result.
%
%   -------------------------------------------------------------------
%   ITERATIVE ALGORITHM (implemented across this file and the small
%   helper files it calls; each step below names the function that does
%   the work)
%   -------------------------------------------------------------------
%     excludedMask = all false                      (no tones known yet)
%     for iter = 1 : MaxIterations
%         noiseFloor = estimateLocalNoiseFloor(Pxx, windowBins, excludedMask)
%         [newMask, regions] = detectTonalRegions(Pxx, noiseFloor, ...
%                                                  thresholdRatio, ...
%                                                  MinBandWidthBins, ExpandBins)
%         if newMask == excludedMask      % nothing changed -> converged
%             break
%         end
%         excludedMask = newMask
%     end
%   Because the loop only stops (or exits by hitting MaxIterations) once
%   the mask used to COMPUTE the current noise floor is identical to the
%   mask that floor then PRODUCES, the final noiseFloor and regions
%   returned are always mutually self-consistent -- no extra
%   "closing" re-estimation step is needed.
%
%   -------------------------------------------------------------------
%   GROUND-TRUTH VALIDATION (synthetic data only)
%   -------------------------------------------------------------------
%   If PureNoiseSignal is supplied (a full-length vector containing only
%   the noise realization that was added to your synthetic tones), this
%   function also computes an EXACT ground-truth SNR directly from the
%   known components (see evaluateGroundTruth.m) and compares it to the
%   spectral estimate. This mode exists purely to validate the
%   estimator; it is never required, and the normal estimateTonalSNR
%   result does not depend on PureNoiseSignal in any way.
%
%   -------------------------------------------------------------------
%   FAILURE / EDGE CASES
%   -------------------------------------------------------------------
%   Hard errors (invalid call): invalid sampleRange (non-increasing, out
%   of bounds), invalid Fs, NaN/Inf inside the selected sample range,
%   too few samples to analyze (< 8), a supplied PureNoiseSignal of the
%   wrong length or containing NaN/Inf.
%   Warnings, with graceful (non-crashing) results: very short ranges
%   (coarse frequency resolution), a noise-floor window wider than the
%   analyzed spectrum (clipped), failure to converge within
%   MaxIterations (last iteration's result is returned anyway), and a
%   signal that is constant (or numerically indistinguishable from
%   constant) after mean removal -- this still runs through the normal
%   pipeline and correctly reports zero detected tones / NaN overall SNR
%   rather than erroring.
%   No tones detected: peakFrequenciesHz etc. are returned empty,
%   totalTonalPower = 0, and overallSNRdB = NaN (never a manufactured
%   number) -- check result.overallSNRdB with isnan/isfinite, or check
%   isempty(result.peakFrequenciesHz), before using it.
%   Tones near 0 Hz or near Nyquist, and closely spaced tones, are
%   handled by the region logic (boundaries clip automatically; close
%   tones may merge -- see detectTonalRegions.m) but should always be
%   sanity-checked against the diagnostic plot.
%
%   -------------------------------------------------------------------
%   SCIENTIFIC LIMITATIONS (read before trusting an unfamiliar result)
%   -------------------------------------------------------------------
%     - This estimator assumes tonal components are relatively
%       narrowband; broadband physical vibration is indistinguishable
%       from noise here and will be absorbed into the noise floor.
%     - Real accelerometer/structural noise is often colored, which is
%       why a LOCAL (frequency-varying) noise floor is used -- but the
%       local-window width is still a user choice with real tradeoffs.
%     - Hann-window spectral leakage sets the effective bandwidth of a
%       detected region; ExpandBins/MinBandWidthBins interact with this.
%     - Very closely spaced tones may be reported as a single merged
%       region rather than two separate ones.
%     - Low-SNR tones may simply not cross the detection threshold and
%       will not appear in the result at all (they are absorbed into
%       "noise", not flagged as low-confidence detections).
%     - The numeric SNR result depends partly on the detection/noise-
%       floor parameters chosen, not on the data alone.
%     - Therefore: ALWAYS inspect the diagnostic plot when analyzing
%       unfamiliar real data; do not consume overallSNRdB as a bare
%       number without a visual sanity check.
%
%   -------------------------------------------------------------------
%   OUTPUT FIELDS (result struct)
%   -------------------------------------------------------------------
%       result.meanAcceleration       - removed mean of the selected
%                                        range (e.g. gravity projection)
%       result.frequencyHz            - analyzed one-sided frequency
%                                        vector, Hz (column)
%       result.measuredPSD            - measured one-sided PSD over
%                                        frequencyHz, (signal unit)^2/Hz
%       result.estimatedNoisePSD      - final estimated noise-floor PSD
%                                        over frequencyHz (defined even
%                                        beneath detected tones)
%       result.peakFrequenciesHz      - Nx1 representative frequency of
%                                        each detected tonal region
%       result.peakBandsHz            - Nx2 [startFreqHz, endFreqHz] of
%                                        each detected region
%       result.peakSignalPower        - Nx1 excess tonal power per region
%       result.peakNoisePower         - Nx1 estimated noise power in the
%                                        same band as each region
%       result.peakSNRdB              - Nx1 local/band SNR per region, dB
%       result.totalTonalPower        - sum of all peakSignalPower
%       result.totalEstimatedNoisePower - total estimated noise power
%                                        over the whole analyzed range
%       result.overallSNRdB           - overall tonal SNR, dB (NaN if no
%                                        tones were detected)
%       result.tonesDetected          - logical, true iff any tonal
%                                        region was detected
%       result.frequencyResolutionHz  - df = Fs / sampleCount
%       result.sampleRange            - the input sampleRange, echoed back
%       result.sampleCount            - number of analyzed samples
%       result.iterationCount         - number of iterations actually run
%       result.converged              - true if detected regions
%                                        stabilized before MaxIterations
%       result.groundTruth            - struct: .available (logical),
%                                        and, when available:
%                                        .trueSignalPower, .trueNoisePower,
%                                        .SNRdB, .estimatedErrorDb
%
%   -------------------------------------------------------------------
%   COMPUTATIONAL COMPLEXITY
%   -------------------------------------------------------------------
%   The one-sided PSD (a single FFT of length N = sampleCount) is
%   computed ONCE, in O(N log N), before the iterative loop -- it is not
%   recomputed per iteration. Each iteration is O(N): a moving median
%   (movmedian uses an efficient sliding algorithm, not a naive
%   O(N*window) recomputation), a threshold comparison, and a small
%   convolution for region expansion, plus a loop over the (typically
%   very small, single-digit to low tens) number of detected regions.
%   With the default parameters, convergence typically occurs within a
%   handful of iterations (2-5 in the synthetic tests used during
%   development), so overall cost is dominated by the single FFT for any
%   realistic sample count, i.e. effectively O(N log N).
%
%   -------------------------------------------------------------------
%   EXAMPLES
%   -------------------------------------------------------------------
%   Minimal call, no ground truth:
%       result = estimateTonalSNR(accel, [1, numel(accel)], Fs);
%   See example_basic.m and example_synthetic_validation.m for complete,
%   runnable examples.

    arguments
        signal double
        sampleRange (1,2) double {mustBeInteger, mustBePositive}
        Fs (1,1) double {mustBePositive, mustBeFinite}
        options.SignalName (1,1) string = "signal"
        options.OutputFolder (1,1) string = "."
        options.PureNoiseSignal double = []
        options.SaveFIG (1,1) logical = false
        options.SavePNG (1,1) logical = false
        options.MakePlot (1,1) logical = true
        options.NoiseFloorWindowHz (1,1) double {mustBePositive} = 50
        options.ThresholdDB (1,1) double = 9
        options.MinBandWidthBins (1,1) double {mustBeInteger, mustBePositive} = 3
        options.ExpandBins (1,1) double {mustBeInteger, mustBeNonnegative} = 2
        options.MaxIterations (1,1) double {mustBeInteger, mustBePositive} = 20
        options.MinFrequencyHz (1,1) double {mustBeNonnegative} = 0
    end

    % ---- basic input validation -------------------------------------
    if ~isvector(signal)
        error('estimateTonalSNR:invalidSignal', 'signal must be a vector.');
    end
    nSignal = numel(signal);

    if sampleRange(1) > sampleRange(2)
        error('estimateTonalSNR:invalidSampleRange', ...
            'sampleRange(1) (%d) must be <= sampleRange(2) (%d).', ...
            sampleRange(1), sampleRange(2));
    end
    if sampleRange(2) > nSignal
        error('estimateTonalSNR:invalidSampleRange', ...
            'sampleRange(2) = %d exceeds the length of signal (%d samples).', ...
            sampleRange(2), nSignal);
    end

    % ---- extract only the requested snippet (never copy/modify the
    % full signal) --------------------------------------------------
    snippet = signal(sampleRange(1):sampleRange(2));
    snippet = snippet(:);
    sampleCount = numel(snippet);

    if any(~isfinite(snippet))
        error('estimateTonalSNR:nonfiniteData', ...
            'signal contains NaN/Inf values within the requested sample range; clean the data before calling estimateTonalSNR.');
    end

    minSamples = 8;
    if sampleCount < minSamples
        error('estimateTonalSNR:tooShort', ...
            'sampleRange selects only %d samples; at least %d are required for a meaningful spectral estimate.', ...
            sampleCount, minSamples);
    end
    if sampleCount < 64
        warning('estimateTonalSNR:shortRange', ...
            ['Only %d samples selected; frequency resolution will be coarse ' ...
             '(%.4g Hz) and the noise-floor estimate less reliable.'], ...
            sampleCount, Fs/sampleCount);
    end

    % ---- DC handling: remove and record the mean ---------------------
    meanAcceleration = mean(snippet);
    detrended = snippet - meanAcceleration;

    signalScale = max(abs(snippet));
    nearZeroTolerance = 1e4 * eps(max(signalScale, 1));
    if max(abs(detrended)) < nearZeroTolerance
        warning('estimateTonalSNR:nearConstantSignal', ...
            'Signal is constant (or numerically indistinguishable from constant) after mean removal; there is no AC content to analyze. Proceeding -- expect zero detected tones.');
    end

    % ---- one-sided PSD (computed once) --------------------------------
    [fFull, PxxFull] = computeOneSidedPSD(detrended, Fs);
    df = fFull(2) - fFull(1);

    analysisMask = fFull >= options.MinFrequencyHz;
    if ~any(analysisMask)
        error('estimateTonalSNR:minFrequencyTooHigh', ...
            'MinFrequencyHz (%.4g Hz) excludes the entire analyzed spectrum (Nyquist = %.4g Hz).', ...
            options.MinFrequencyHz, fFull(end));
    end
    fA = fFull(analysisMask);
    PxxA = PxxFull(analysisMask);
    nBins = numel(PxxA);

    % ---- moving-median window width, in bins --------------------------
    windowBins = max(3, round(options.NoiseFloorWindowHz / df));
    if mod(windowBins, 2) == 0
        windowBins = windowBins + 1;
    end
    if windowBins > nBins
        windowBins = nBins - (1 - mod(nBins, 2));
        windowBins = max(windowBins, 1);
        warning('estimateTonalSNR:noiseWindowClipped', ...
            'NoiseFloorWindowHz corresponds to a window wider than the analyzed spectrum; clipping to %d bins.', ...
            windowBins);
    end

    % ---- iterative noise-floor / tonal-region detection ----------------
    thresholdRatio = 10^(options.ThresholdDB / 10);
    excludedMask = false(nBins, 1);
    noiseFloorA = [];
    regions = zeros(0, 2);
    converged = false;

    for iter = 1:options.MaxIterations
        noiseFloorA = estimateLocalNoiseFloor(PxxA, windowBins, excludedMask);
        [newMask, newRegions] = detectTonalRegions(PxxA, noiseFloorA, ...
            thresholdRatio, options.MinBandWidthBins, options.ExpandBins);

        regions = newRegions;

        if isequal(newMask, excludedMask)
            converged = true;
            break;
        end
        excludedMask = newMask;
    end
    iterationCount = iter;

    if ~converged
        warning('estimateTonalSNR:noConvergence', ...
            ['Detected tonal regions did not stabilize within MaxIterations (%d); ' ...
             'returning the last iteration''s result. Consider increasing MaxIterations ' ...
             'or adjusting ThresholdDB / MinBandWidthBins.'], options.MaxIterations);
    end

    % ---- per-tone and overall power / SNR -------------------------------
    bandInfo = computeBandPowers(fA, PxxA, noiseFloorA, regions, df);
    nPeaks = numel(bandInfo);

    if nPeaks > 0
        peakFrequenciesHz = reshape([bandInfo.peakFrequencyHz], [], 1);
        peakBandsHz = reshape([bandInfo.bandHz], 2, [])';
        peakSignalPower = reshape([bandInfo.signalPower], [], 1);
        peakNoisePower = reshape([bandInfo.noisePower], [], 1);
        peakSNRdB = reshape([bandInfo.snrDB], [], 1);
    else
        peakFrequenciesHz = zeros(0, 1);
        peakBandsHz = zeros(0, 2);
        peakSignalPower = zeros(0, 1);
        peakNoisePower = zeros(0, 1);
        peakSNRdB = zeros(0, 1);
    end

    totalTonalPower = sum(peakSignalPower);
    totalEstimatedNoisePower = sum(noiseFloorA) * df;

    if nPeaks == 0
        overallSNRdB = NaN;   % no tones detected -- do not manufacture a value
    elseif totalEstimatedNoisePower > 0
        overallSNRdB = 10 * log10(totalTonalPower / totalEstimatedNoisePower);
    else
        overallSNRdB = Inf;  % degenerate: estimator believes there is no noise at all
    end

    % ---- optional ground-truth validation --------------------------------
    if ~isempty(options.PureNoiseSignal)
        groundTruth = evaluateGroundTruth(signal, options.PureNoiseSignal, ...
            sampleRange, meanAcceleration, overallSNRdB);
    else
        groundTruth = struct('available', false, 'trueSignalPower', NaN, ...
            'trueNoisePower', NaN, 'SNRdB', NaN, 'estimatedErrorDb', NaN);
    end

    % ---- assemble result --------------------------------------------------
    result = struct();
    result.meanAcceleration = meanAcceleration;

    result.frequencyHz = fA;
    result.measuredPSD = PxxA;
    result.estimatedNoisePSD = noiseFloorA;

    result.peakFrequenciesHz = peakFrequenciesHz;
    result.peakBandsHz = peakBandsHz;
    result.peakSignalPower = peakSignalPower;
    result.peakNoisePower = peakNoisePower;
    result.peakSNRdB = peakSNRdB;

    result.totalTonalPower = totalTonalPower;
    result.totalEstimatedNoisePower = totalEstimatedNoisePower;
    result.overallSNRdB = overallSNRdB;
    result.tonesDetected = nPeaks > 0;

    result.frequencyResolutionHz = df;
    result.sampleRange = sampleRange;
    result.sampleCount = sampleCount;

    result.iterationCount = iterationCount;
    result.converged = converged;

    result.groundTruth = groundTruth;

    % ---- diagnostic plot ----------------------------------------------
    if options.MakePlot
        plotTonalSNR(result, options);
    end
end

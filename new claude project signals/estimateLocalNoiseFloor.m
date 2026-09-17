function noiseFloor = estimateLocalNoiseFloor(Pxx, windowBins, excludedMask)
%ESTIMATELOCALNOISEFLOOR Robust, frequency-varying broadband noise-floor estimate.
%
%   noiseFloor = ESTIMATELOCALNOISEFLOOR(Pxx, windowBins, excludedMask)
%
%   -------------------------------------------------------------------
%   WHY THE MEDIAN, NOT THE MEAN
%   -------------------------------------------------------------------
%   A single-segment (non-averaged) periodogram bin is a noisy estimate
%   of the true local power: for a purely broadband/random signal, the
%   real and imaginary parts of the FFT at each bin are approximately
%   Gaussian, which makes |X(k)|^2 -- and hence Pxx(k) -- approximately
%   EXPONENTIALLY distributed around the true noise power at that
%   frequency (100% relative standard deviation, bin to bin). A strong
%   tone raises a handful of bins far above the surrounding floor. The
%   ARITHMETIC MEAN over a frequency neighborhood is dragged upward by
%   those few large values -- exactly what the user's design brief warns
%   against ("do not use the ordinary arithmetic mean ... because strong
%   tones can bias it badly"). The MEDIAN is far more robust to this
%   kind of minority contamination.
%
%   -------------------------------------------------------------------
%   WHY DIVIDE BY log(2)
%   -------------------------------------------------------------------
%   For a bin containing only broadband noise, Pxx(bin) is approximately
%   Exponential(mean = true noise PSD). The MEDIAN of an Exponential
%   distribution is ln(2) ~= 0.6931 times its MEAN. A raw local median
%   therefore systematically UNDERESTIMATES the true mean noise PSD by a
%   factor of ln(2). Dividing the local median by log(2) corrects this
%   known statistical bias, giving an approximately unbiased estimate of
%   the mean noise power (this was verified numerically against a known
%   white-noise-plus-tone synthetic signal during development).
%
%   -------------------------------------------------------------------
%   WHY A MOVING (LOCAL) MEDIAN, NOT ONE GLOBAL VALUE
%   -------------------------------------------------------------------
%   Real accelerometer noise is often colored (its level depends on
%   frequency: e.g. higher near resonances, rolling off at high
%   frequency), so a single constant noise floor for the whole spectrum
%   would either overestimate the floor in quiet regions or
%   underestimate it in noisier regions. Computing the median inside a
%   sliding window of windowBins bins lets the floor track slow changes
%   in noise color while still averaging over enough bins to be
%   statistically stable.
%
%   windowBins controls a real tradeoff (exposed as NoiseFloorWindowHz
%   in estimateTonalSNR):
%     - too NARROW: a tone can occupy a large fraction of its own local
%       window and bias its own "local noise floor" upward, making the
%       tone look weaker than it is (or hiding it entirely).
%     - too WIDE: genuine changes in colored noise level get smoothed
%       away, and the floor becomes effectively a single global value.
%
%   Inputs:
%       Pxx          - one-sided PSD vector (column)
%       windowBins   - odd positive integer, moving-median window width
%                      in bins
%       excludedMask - logical vector, same size as Pxx; true where a
%                      bin currently belongs to a detected tonal region
%                      and must be excluded from the floor estimate
%                      (pass all-false before any tones are known, i.e.
%                      on the first iteration)
%   Output:
%       noiseFloor   - estimated noise-floor PSD, defined at every bin,
%                      including bins beneath detected tones (this is
%                      required so tonal-band noise power can later be
%                      estimated from the floor curve rather than from
%                      the tone-contaminated raw PSD)

    Pxx = Pxx(:);
    excludedMask = excludedMask(:);

    masked = Pxx;
    masked(excludedMask) = NaN;

    correction = 1 / log(2);
    noiseFloor = movmedian(masked, windowBins, 'omitnan') * correction;

    % Fallback for local windows that end up entirely excluded (e.g. a
    % very wide detected tonal region combined with a narrow
    % NoiseFloorWindowHz): fill remaining NaNs with the median of all
    % currently non-excluded bins. In the pathological case where every
    % bin is excluded, fall back further to the median of the raw PSD so
    % this function always returns a finite result.
    if any(isnan(noiseFloor))
        globalFallback = median(masked, 'omitnan') * correction;
        if isnan(globalFallback)
            globalFallback = median(Pxx) * correction;
        end
        noiseFloor(isnan(noiseFloor)) = globalFallback;
    end
end

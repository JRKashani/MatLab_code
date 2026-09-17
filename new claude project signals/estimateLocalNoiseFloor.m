function noiseFloor = estimateLocalNoiseFloor(psd, excludedMask, windowBins)
%ESTIMATELOCALNOISEFLOOR Robust, frequency-varying broadband noise floor.
%
% noiseFloor = estimateLocalNoiseFloor(psd, excludedMask, windowBins)
%
% Inputs:
%   psd          - one-sided PSD, column vector
%   excludedMask - logical column vector, same length as psd; true where
%                  a bin currently belongs to a candidate tonal region
%                  and should be ignored while estimating the noise floor
%   windowBins   - width, in bins, of the local moving-median window
%
% Output:
%   noiseFloor   - estimated noise PSD at every bin (same length as psd),
%                  including underneath excluded/tonal bins (filled by
%                  interpolation from the surrounding noise-only bins)
%
% ---------------------------------------------------------------------
% WHY A MEDIAN, NOT A MEAN
% ---------------------------------------------------------------------
% This is a single, unaveraged periodogram (one Hann-windowed FFT of the
% analyzed block, not an average of many shorter blocks as in Welch's
% method). For a stationary broadband random process, each periodogram
% bin fluctuates around the true noise PSD roughly like a chi-square
% distribution with 2 degrees of freedom (equivalently, an exponential
% distribution) - the bin-to-bin scatter is large, and its standard
% deviation is comparable to its mean. An ordinary arithmetic mean over a
% neighborhood is not robust: a single strong tone sitting among mostly
% noise bins can pull the mean up enormously. The median is far less
% sensitive to a small number of unusually large values, so it gives a
% much more reliable estimate of "typical" noise power nearby.
%
% ---------------------------------------------------------------------
% WHY THE CORRECTION FACTOR (1/ln(2))
% ---------------------------------------------------------------------
% The median of an exponential distribution is ln(2) (~0.6931) times its
% MEAN, not equal to it. So a raw local median of noise-only periodogram
% bins systematically UNDERESTIMATES the true mean noise power by that
% same factor. Since the power integrals used later (Parseval-consistent
% sums of PSD * df) are mean-based quantities, the local median is
% corrected by dividing by ln(2) (i.e. multiplying by 1/ln(2) ~= 1.4427)
% so that the returned noiseFloor represents an estimate of the mean
% noise PSD, consistent with the rest of the power/SNR calculations.
%
% ---------------------------------------------------------------------
% WHY LOCAL (MOVING) RATHER THAN ONE GLOBAL VALUE
% ---------------------------------------------------------------------
% Real accelerometer noise is often colored (its floor rises or falls
% smoothly with frequency), not perfectly white. A single constant noise
% value for the whole spectrum would systematically over-flag tones in
% quiet regions and under-flag them in noisier regions. A moving median
% lets the estimated floor track slow, real changes in the noise level
% while medians computed over a properly-chosen local width still reject
% narrow tonal peaks (see the NoiseFloorWindowHz parameter discussion in
% estimateTonalSNR.m for how that width is chosen).
% ---------------------------------------------------------------------

MEDIAN_TO_MEAN_CORRECTION = 1 / log(2);

psdForMedian = psd(:);
excludedMask = logical(excludedMask(:));
psdForMedian(excludedMask) = NaN;

localMedian = movmedian(psdForMedian, windowBins, 'omitnan');

% If an entire local window fell on excluded (candidate-tonal) bins,
% movmedian has no data to work with there and returns NaN. Fill those
% gaps by interpolating from the nearest valid neighboring estimates
% rather than leaving holes in the noise floor (the noise floor must be
% defined everywhere, including underneath detected tones, so that later
% power integrals over a tonal band can subtract it out).
validIdx = ~isnan(localMedian);
if ~all(validIdx)
    if any(validIdx)
        allIdx = (1:numel(localMedian))';
        localMedian(~validIdx) = interp1(allIdx(validIdx), localMedian(validIdx), ...
            allIdx(~validIdx), 'linear', 'extrap');
    else
        % Degenerate case: every bin is currently excluded. Fall back to
        % the (biased-low, but still finite and usable) median of the
        % raw PSD so the algorithm does not stall on NaNs.
        localMedian(:) = median(psd);
    end
end

noiseFloor = localMedian * MEDIAN_TO_MEAN_CORRECTION;
end

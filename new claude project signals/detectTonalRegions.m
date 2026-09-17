function [detectedMask, regions] = detectTonalRegions(Pxx, noiseFloor, thresholdRatio, minBandWidthBins, expandBins)
%DETECTTONALREGIONS Identify and group tonal (narrowband) regions above a noise floor.
%
%   [detectedMask, regions] = DETECTTONALREGIONS(Pxx, noiseFloor, ...
%       thresholdRatio, minBandWidthBins, expandBins)
%
%   Detection happens in three steps, and THE ORDER IS DELIBERATE:
%
%   1) RAW THRESHOLD -- flag every bin where
%           Pxx(bin) > noiseFloor(bin) * thresholdRatio
%      thresholdRatio is a LINEAR power ratio (e.g. a 6 dB threshold is
%      thresholdRatio = 10^(6/10) ~= 3.98).
%
%   2) MINIMUM-WIDTH VALIDATION, applied to the RAW (not-yet-expanded)
%      flagged bins: group them into contiguous runs and keep only runs
%      that are at least minBandWidthBins bins long. This is the main
%      defense against false detections, not just a cosmetic "minimum
%      tone width": a single periodogram bin is a noisy estimate (see
%      estimateLocalNoiseFloor), so with thousands of bins in a
%      spectrum, isolated bins will exceed even a fairly strict
%      threshold by chance reasonably often. A genuine tone, broadened
%      by Hann-window leakage, reliably produces several *consecutive*
%      bins above threshold; an isolated noise spike usually does not.
%      This validation MUST happen before expansion -- if bins were
%      expanded first, a single noise spike would trivially satisfy any
%      minimum-width requirement once dilated, defeating the purpose.
%      (This was confirmed empirically during development: applying the
%      width filter after expansion let dozens of spurious sub-bin noise
%      fluctuations through as "detected tones".)
%
%   3) EXPANSION -- each validated region is widened by expandBins bins
%      on each side, to capture the leakage skirt around the tone (so
%      the region used for power integration includes the tone's spread
%      energy, not just its single tallest bin). Expansion can cause
%      adjacent validated regions to merge; when that happens two very
%      closely spaced tones are reported as a single combined region
%      (see the "closely spaced tones" limitation in estimateTonalSNR.m).
%
%   Inputs:
%       Pxx               - one-sided PSD vector (column)
%       noiseFloor        - local noise-floor PSD, same size as Pxx
%       thresholdRatio    - linear power ratio threshold (> 1)
%       minBandWidthBins  - minimum number of consecutive raw-threshold
%                           bins required to accept a detection
%                           (positive integer)
%       expandBins        - number of bins to expand each validated
%                           region by, on each side (nonnegative integer)
%   Outputs:
%       detectedMask - logical vector, same size as Pxx; true for every
%                      bin belonging to a final (validated + expanded)
%                      tonal region
%       regions      - M-by-2 matrix of [startIdx, endIdx], one row per
%                      final tonal region (already merged where
%                      expansion caused two regions to overlap)

    nBins = numel(Pxx);

    rawMask = Pxx > (noiseFloor * thresholdRatio);

    rawRegions = groupContiguousBins(rawMask);
    if ~isempty(rawRegions)
        widths = rawRegions(:,2) - rawRegions(:,1) + 1;
        rawRegions = rawRegions(widths >= minBandWidthBins, :);
    end

    validatedMask = false(nBins, 1);
    for r = 1:size(rawRegions, 1)
        validatedMask(rawRegions(r,1):rawRegions(r,2)) = true;
    end

    if expandBins > 0 && any(validatedMask)
        kernel = ones(2*expandBins + 1, 1);
        detectedMask = conv(double(validatedMask), kernel, 'same') > 0;
    else
        detectedMask = validatedMask;
    end

    regions = groupContiguousBins(detectedMask);
end

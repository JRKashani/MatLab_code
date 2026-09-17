function [tonalMask, regions] = detectTonalRegions(psd, noiseFloor, thresholdDb, ...
    mergeGapBins, expansionBins, minBandwidthBins, excludedBins)
%DETECTTONALREGIONS Identify and group frequency bins that rise
% sufficiently above the local noise floor into tonal "regions".
%
% [tonalMask, regions] = detectTonalRegions(psd, noiseFloor, thresholdDb, ...
%     mergeGapBins, expansionBins, minBandwidthBins, excludedBins)
%
% Inputs:
%   psd              - one-sided PSD, column vector
%   noiseFloor       - local noise-floor PSD estimate, same length as psd
%   thresholdDb      - detection threshold, in dB above the local noise
%                       floor (e.g. 6 dB corresponds to a factor of
%                       10^(6/10) ~= 4x the local noise power)
%   mergeGapBins     - candidate bins separated by this many bins or
%                       fewer are grouped into ONE region rather than
%                       reported as separate tones (keeps a single peak,
%                       broadened by Hann-window leakage, from being
%                       split into multiple detections)
%   expansionBins    - extra bins added on each side of a detected region
%                       to capture the leakage skirt around the peak
%   minBandwidthBins - minimum width, in bins, enforced for every region
%   excludedBins     - logical mask, same length as psd; true bins can
%                       never be classified as tonal (e.g. bins below a
%                       configured minimum analysis frequency, used to
%                       avoid false positives from residual DC leakage)
%
% Outputs:
%   tonalMask - logical column vector, true where a bin belongs to a
%               detected tonal region
%   regions   - [numRegions x 2] matrix of [startBin, endBin] indices,
%               one row per detected tonal region
%
% ---------------------------------------------------------------------
% WHY GROUP BINS INTO REGIONS AT ALL
% ---------------------------------------------------------------------
% A single true sinusoid does not appear as one isolated bin: the Hann
% window's main lobe spreads it over several neighboring bins. If every
% bin above threshold were reported as its own "tone", one real
% sinusoid would be miscounted as several. Grouping adjacent (and
% closely-spaced) above-threshold bins into a single region, then taking
% one representative frequency/power per region, avoids this.
% ---------------------------------------------------------------------

thresholdRatio = 10^(thresholdDb / 10);

psd = psd(:);
noiseFloor = noiseFloor(:);
excludedBins = logical(excludedBins(:));

candidate = (psd > noiseFloor * thresholdRatio) & ~excludedBins;

M = numel(psd);
tonalMask = false(M, 1);
regions = zeros(0, 2);

if ~any(candidate)
    return;
end

% --- find contiguous runs of candidate bins -------------------------
paddedCandidate = double([false; candidate; false]);
edges = diff(paddedCandidate);
runStarts = find(edges == 1);
runEnds   = find(edges == -1) - 1;

% --- merge runs separated by a small gap (leakage skirt of one tone) -
mergedStarts = runStarts(1);
mergedEnds   = runEnds(1);
for k = 2:numel(runStarts)
    gap = runStarts(k) - mergedEnds(end) - 1;
    if gap <= mergeGapBins
        mergedEnds(end) = runEnds(k);
    else
        mergedStarts(end+1) = runStarts(k); %#ok<AGROW>
        mergedEnds(end+1)   = runEnds(k);   %#ok<AGROW>
    end
end

% --- expand each region and enforce the minimum bandwidth ------------
numRegions = numel(mergedStarts);
rawRegions = zeros(numRegions, 2);
for r = 1:numRegions
    s = mergedStarts(r) - expansionBins;
    e = mergedEnds(r)   + expansionBins;

    width = e - s + 1;
    if width < minBandwidthBins
        deficit = minBandwidthBins - width;
        s = s - ceil(deficit / 2);
        e = e + floor(deficit / 2);
    end

    rawRegions(r, :) = [max(1, s), min(M, e)];
end

% --- expansion/min-width can make neighboring regions overlap; re-merge
regions = mergeOverlappingRegions(rawRegions);

for r = 1:size(regions, 1)
    tonalMask(regions(r, 1):regions(r, 2)) = true;
end
end

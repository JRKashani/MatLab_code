function merged = mergeOverlappingRegions(regions)
%MERGEOVERLAPPINGREGIONS Combine [start,end] bin ranges that touch or
% overlap, so no two returned regions share (or sit immediately next to)
% a bin.
%
% merged = mergeOverlappingRegions(regions)
%
% Input:
%   regions - [N x 2] matrix of [startBin, endBin] pairs, any row order
%
% Output:
%   merged  - [M x 2] matrix (M <= N), sorted by start bin, with every
%             pair of overlapping or touching ranges combined into one
%
% This is used after tonal regions have been expanded (to capture Hann
% window leakage skirts) and/or widened to a minimum bandwidth, either of
% which can cause two originally-separate regions to overlap or become
% adjacent. Re-merging avoids reporting the same physical tone twice.

if isempty(regions)
    merged = regions;
    return;
end

sortedRegions = sortrows(regions, 1);
merged = sortedRegions(1, :);

for r = 2:size(sortedRegions, 1)
    s = sortedRegions(r, 1);
    e = sortedRegions(r, 2);

    if s <= merged(end, 2) + 1
        % Overlapping or immediately adjacent: extend the current region.
        merged(end, 2) = max(merged(end, 2), e);
    else
        merged(end+1, :) = [s, e]; %#ok<AGROW>
    end
end
end

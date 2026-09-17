function regions = groupContiguousBins(mask)
%GROUPCONTIGUOUSBINS Group a logical vector into contiguous true-runs.
%
%   regions = GROUPCONTIGUOUSBINS(mask) returns an M-by-2 matrix where
%   each row [startIdx, endIdx] gives the inclusive index range of one
%   contiguous run of true values in the logical vector mask. Returns a
%   0-by-2 matrix if mask has no true values.
%
%   This exists because Hann-window spectral leakage spreads one
%   physical tone over several adjacent bins; those bins must be
%   reported as a single detected tonal region, not as several separate
%   "tones".
%
%   Input:
%       mask - logical vector
%   Output:
%       regions - M-by-2 double matrix of [startIdx, endIdx] pairs, in
%                 increasing order

    mask = mask(:)';
    if ~any(mask)
        regions = zeros(0, 2);
        return;
    end

    edges = diff(double([false, mask, false]));
    startIdx = find(edges == 1);
    endIdx = find(edges == -1) - 1;

    regions = [startIdx(:), endIdx(:)];
end

function [segment, sampleRange] = selectSignalSegment(signal, sampleRange, Fs, minimumSamples)
%SELECTSIGNALSEGMENT Validate an inclusive sample range and return a column.
%   The endpoints are MATLAB sample indices (one-based, integers). Rejecting
%   invalid endpoints prevents different analysis methods silently using
%   different portions of a recording. Only selected samples must be finite.
    if nargin < 4
        minimumSamples = 2;
    end
    validateattributes(signal, {'numeric'}, {'vector', 'real', 'nonempty'}, mfilename, 'signal');
    validateattributes(Fs, {'numeric'}, {'scalar', 'real', 'finite', 'positive'}, mfilename, 'Fs');
    if isempty(sampleRange)
        sampleRange = [1, numel(signal)];
    end
    validateattributes(sampleRange, {'numeric'}, ...
        {'vector', 'numel', 2, 'real', 'finite', 'integer', 'positive'}, mfilename, 'sampleRange');
    sampleRange = double(sampleRange(:).');
    if sampleRange(2) > numel(signal) || sampleRange(2) < sampleRange(1)
        error('selectSignalSegment:invalidRange', 'sampleRange must be ordered and within the signal.');
    end
    if diff(sampleRange) + 1 < minimumSamples
        error('selectSignalSegment:tooShort', 'Select at least %d samples.', minimumSamples);
    end
    segment = double(signal(sampleRange(1):sampleRange(2)));
    segment = segment(:);
    if any(~isfinite(segment))
        error('selectSignalSegment:invalidValues', 'Selected samples contain NaN or Inf.');
    end
end

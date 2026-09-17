function [psd, f] = computeWelchPSD(x, Fs, segmentLength, overlap, window, nfft)
%COMPUTEWELCHPSD Average windowed segment PSDs, restored from 9f4df66.
    x = x(:);
    n = numel(x);
    step = segmentLength - overlap;
    if step <= 0 || overlap < 0 || segmentLength > n
        error('computeWelchPSD:invalidSegments', 'Require 0 <= overlap < segmentLength <= signal length.');
    end
    numSegments = floor((n - overlap) / step);
    psdSum = zeros(floor(nfft/2) + 1, 1);

    for k = 1:numSegments
        startIdx = 1 + (k - 1) * step;
        endIdx = startIdx + segmentLength - 1;
        if endIdx > n
            break;
        end
        [segPSD, f] = computePeriodogramPSD(x(startIdx:endIdx), Fs, window, nfft);
        psdSum = psdSum + segPSD;
    end

    psd = psdSum / numSegments;
end

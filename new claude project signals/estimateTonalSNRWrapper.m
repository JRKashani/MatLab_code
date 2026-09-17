function result = estimateTonalSNRWrapper(signal, sampleRange, Fs, options)
%ESTIMATETONALSNRWRAPPER Thin compatibility wrapper for the tonal SNR API.
%   Kept as a separate entry so callers can use a consistent independent
%   interface while the main estimator remains in estimateTonalSNR.m.

    if nargin < 4 || isempty(options)
        options = struct();
    end
    if nargin < 3 || isempty(Fs)
        error('estimateTonalSNRWrapper:invalidFs', 'Fs is required and must be positive.');
    end
    if nargin < 2 || isempty(sampleRange)
        sampleRange = [1, numel(signal)];
    end

    result = estimateTonalSNR(signal, sampleRange, Fs, options);
end

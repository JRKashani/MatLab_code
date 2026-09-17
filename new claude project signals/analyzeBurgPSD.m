function result = analyzeBurgPSD(signal, sampleRange, Fs, options)
%ANALYZEBURGPSD Independent Burg AR PSD analysis for a selected segment.
%
%   result = analyzeBurgPSD(signal, sampleRange, Fs, options)
%
%   Compares configurable AR model orders and keeps the PSD computation
%   independent from the periodogram / Welch wrappers.

    if nargin < 4 || isempty(options)
        options = struct();
    end
    if nargin < 3 || isempty(Fs)
        error('analyzeBurgPSD:invalidFs', 'Fs is required and must be positive.');
    end
    if nargin < 2 || isempty(sampleRange)
        sampleRange = [1, numel(signal)];
    end

    orders = getOption(options, 'orders', [4, 8, 16, 24]);
    nfft = getOption(options, 'nfft', 1024);

    psdOptions = struct();
    psdOptions.burg = struct('orders', orders, 'nfft', nfft);
    psdOptions.periodogram = struct('windows', {'hann'}, 'nfftFactors', [1], 'nfftWindow', 'hann', 'chebSidelobe', 80);
    psdOptions.welch = struct('windows', {'hann'}, 'segmentSecondsFixed', 1, 'overlapPercentFixed', 50, ...
        'segmentSecondsList', 1, 'overlapPercentList', 50, 'nfftFactor', 2);

    analysis = analyzeAccelerationPSD(signal, sampleRange, Fs, psdOptions);
    result = analysis;
    result.method = 'burg';
    result.orders = orders;
    result.nfft = nfft;
end

function value = getOption(options, fieldName, defaultValue)
    if isfield(options, fieldName) && ~isempty(options.(fieldName))
        value = options.(fieldName);
    else
        value = defaultValue;
    end
end

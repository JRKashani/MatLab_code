function result = analyzePeriodogram(signal, sampleRange, Fs, options)
%ANALYZEPERIODOGRAM Independent periodogram analysis for a selected segment.
%
%   result = analyzePeriodogram(signal, sampleRange, Fs, options)
%
%   The method is independent from Welch/Burg and the FFT wrapper. It compares
%   multiple window types and NFFT values using the existing PSD implementation.

    if nargin < 4 || isempty(options)
        options = struct();
    end
    if nargin < 3 || isempty(Fs)
        error('analyzePeriodogram:invalidFs', 'Fs is required and must be positive.');
    end
    if nargin < 2 || isempty(sampleRange)
        sampleRange = [1, numel(signal)];
    end

    wins = getOption(options, 'windows', {'hann', 'hamming', 'blackman'});
    nfftFactors = getOption(options, 'nfftFactors', [1, 2, 4]);
    nfftWindow = getOption(options, 'nfftWindow', 'hann');
    chebSidelobe = getOption(options, 'chebSidelobe', 80);

    psdOptions = struct();
    psdOptions.periodogram = struct('windows', wins, 'nfftFactors', nfftFactors, ...
        'nfftWindow', nfftWindow, 'chebSidelobe', chebSidelobe);
    psdOptions.welch = struct('windows', {'hann'}, 'segmentSecondsFixed', 1, ...
        'overlapPercentFixed', 50, 'segmentSecondsList', 1, 'overlapPercentList', 50, ...
        'nfftFactor', 2);
    psdOptions.burg = struct('orders', 8, 'nfft', 1024);

    analysis = analyzeAccelerationPSD(signal, sampleRange, Fs, psdOptions);
    result = analysis;
    result.method = 'periodogram';
    result.windows = wins;
    result.nfftFactors = nfftFactors;
end

function value = getOption(options, fieldName, defaultValue)
    if isfield(options, fieldName) && ~isempty(options.(fieldName))
        value = options.(fieldName);
    else
        value = defaultValue;
    end
end

function result = analyzeWelchPSD(signal, sampleRange, Fs, options)
%ANALYZEWELCHPSD Independent Welch PSD analysis for a selected segment.
%
%   result = analyzeWelchPSD(signal, sampleRange, Fs, options)
%
%   Supports comparison of window type, segment length, and overlap.

    if nargin < 4 || isempty(options)
        options = struct();
    end
    if nargin < 3 || isempty(Fs)
        error('analyzeWelchPSD:invalidFs', 'Fs is required and must be positive.');
    end
    if nargin < 2 || isempty(sampleRange)
        sampleRange = [1, numel(signal)];
    end

    wins = getOption(options, 'windows', {'hann', 'hamming', 'blackman'});
    segmentSecondsFixed = getOption(options, 'segmentSecondsFixed', 0.5);
    overlapPercentFixed = getOption(options, 'overlapPercentFixed', 50);
    segmentSecondsList = getOption(options, 'segmentSecondsList', [0.25, 0.5, 1.0]);
    overlapPercentList = getOption(options, 'overlapPercentList', [0, 50, 75]);
    nfftFactor = getOption(options, 'nfftFactor', 2);
    chebSidelobe = getOption(options, 'chebSidelobe', 80);

    psdOptions = struct();
    psdOptions.welch = struct('windows', wins, 'segmentSecondsFixed', segmentSecondsFixed, ...
        'overlapPercentFixed', overlapPercentFixed, 'segmentSecondsList', segmentSecondsList, ...
        'overlapPercentList', overlapPercentList, 'nfftFactor', nfftFactor, ...
        'chebSidelobe', chebSidelobe);
    psdOptions.periodogram = struct('windows', {'hann'}, 'nfftFactors', [1], 'nfftWindow', 'hann', 'chebSidelobe', chebSidelobe);
    psdOptions.burg = struct('orders', 8, 'nfft', 1024);

    analysis = analyzeAccelerationPSD(signal, sampleRange, Fs, psdOptions);
    result = analysis;
    result.method = 'welch';
    result.windows = wins;
    result.segmentSecondsFixed = segmentSecondsFixed;
    result.segmentSecondsList = segmentSecondsList;
    result.overlapPercentList = overlapPercentList;
end

function value = getOption(options, fieldName, defaultValue)
    if isfield(options, fieldName) && ~isempty(options.(fieldName))
        value = options.(fieldName);
    else
        value = defaultValue;
    end
end

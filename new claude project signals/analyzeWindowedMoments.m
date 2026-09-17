function result = analyzeWindowedMoments(signal, sampleRange, Fs, options)
%ANALYZEWINDOWEDMOMENTS Sliding-window moment analysis for a selected segment.
%
%   result = analyzeWindowedMoments(signal, sampleRange, Fs, options)
%
%   Inputs:
%       signal       - full numeric signal vector
%       sampleRange  - [startSample endSample], default full record
%       Fs           - sampling frequency [Hz]
%       options      - optional struct with fields:
%                      windowLengths, outputFolder, savePng, saveFig, plotTitle
%
%   Output:
%       result.summary     - scalar summary for each window length
%       result.series      - time traces for each moment metric
%       result.sampleRange - selected [startSample endSample]
%       result.Fs          - sampling frequency
%       result.files       - saved figure files

    if nargin < 4 || isempty(options)
        options = struct();
    end
    if nargin < 3 || isempty(Fs)
        error('analyzeWindowedMoments:invalidFs', 'Fs is required and must be positive.');
    end
    if nargin < 2 || isempty(sampleRange)
        sampleRange = [1, numel(signal)];
    end

    if ~isnumeric(signal) || ~isvector(signal)
        error('analyzeWindowedMoments:invalidSignal', 'signal must be a numeric vector.');
    end
    if ~(isnumeric(Fs) && isscalar(Fs) && isfinite(Fs) && Fs > 0)
        error('analyzeWindowedMoments:invalidFs', 'Fs must be a positive finite scalar.');
    end
    if ~(isnumeric(sampleRange) && numel(sampleRange) == 2 && all(isfinite(sampleRange)))
        error('analyzeWindowedMoments:invalidRange', 'sampleRange must be [startSample endSample].');
    end

    startSample = round(sampleRange(1));
    endSample = round(sampleRange(2));
    if startSample < 1 || endSample > numel(signal) || endSample < startSample
        error('analyzeWindowedMoments:outOfBounds', 'sampleRange is outside the signal bounds.');
    end

    segment = double(signal(startSample:endSample));
    segment = segment(:);
    N = numel(segment);
    if N < 2
        error('analyzeWindowedMoments:tooShort', 'Selected range must contain at least 2 samples.');
    end

    if isfield(options, 'windowLengths') && ~isempty(options.windowLengths)
        windowLengths = sort(unique(round(options.windowLengths(:))));
    else
        defaultCell = [max(8, round(Fs * 0.25)); max(16, round(Fs * 0.5)); max(32, round(Fs * 1.0))];
        windowLengths = unique(defaultCell);
    end
    windowLengths = windowLengths(windowLengths >= 2 & windowLengths <= N);
    if isempty(windowLengths)
        windowLengths = N;
    end

    outputFolder = getOption(options, 'outputFolder', fullfile(pwd, 'results'));
    savePng = getOption(options, 'savePng', true);
    saveFig = getOption(options, 'saveFig', true);
    plotTitle = getOption(options, 'plotTitle', 'Windowed moments');

    if ~exist(outputFolder, 'dir')
        mkdir(outputFolder);
    end

    allMean = zeros(numel(windowLengths), 1);
    allRms = zeros(numel(windowLengths), 1);
    allSkew = zeros(numel(windowLengths), 1);
    allKurtosis = zeros(numel(windowLengths), 1);
    allSeries = struct();

    figureHandle = figure('Name', plotTitle, 'Color', 'w');
    tiledlayout(figureHandle, numel(windowLengths), 1, 'TileSpacing', 'compact', 'Padding', 'compact');

    files = {};
    for idx = 1:numel(windowLengths)
        winLen = windowLengths(idx);
        halfWindow = floor(winLen / 2);
        meanSeries = zeros(N, 1);
        rmsSeries = zeros(N, 1);
        skewSeries = zeros(N, 1);
        kurtSeries = zeros(N, 1);

        for k = 1:N
            a = max(1, k - halfWindow);
            b = min(N, k + halfWindow);
            windowData = segment(a:b);
            center = windowData - mean(windowData);
            sigma = std(windowData);
            if sigma == 0
                sigma = eps;
            end
            meanSeries(k) = mean(windowData);
            rmsSeries(k) = sqrt(mean(windowData.^2));
            skewSeries(k) = mean(center.^3) / (sigma^3 + eps);
            kurtSeries(k) = mean(center.^4) / (sigma^4 + eps) - 3;
        end

        t = (0:N-1)' / Fs;
        allMean(idx) = mean(meanSeries);
        allRms(idx) = mean(rmsSeries);
        allSkew(idx) = mean(skewSeries);
        allKurtosis(idx) = mean(kurtSeries);

        allSeries(idx).time = t;
        allSeries(idx).mean = meanSeries;
        allSeries(idx).rms = rmsSeries;
        allSeries(idx).skewness = skewSeries;
        allSeries(idx).kurtosis = kurtSeries;
        allSeries(idx).windowLength = winLen;

        nexttile;
        yyaxis left;
        plot(t, meanSeries, 'b', 'LineWidth', 1.1);
        hold on;
        plot(t, rmsSeries, 'g', 'LineWidth', 1.1);
        ylabel('Mean / RMS');
        yyaxis right;
        plot(t, skewSeries, 'r', 'LineWidth', 1.1);
        hold on;
        plot(t, kurtSeries, 'm', 'LineWidth', 1.1);
        ylabel('Skewness / Kurtosis');
        title(sprintf('Window length = %d samples', winLen));
        xlabel('Time [s]');
        grid on;
    end

    if savePng
        pngPath = fullfile(outputFolder, 'windowed_moments.png');
        exportgraphics(figureHandle, pngPath, 'Resolution', 300);
        files{end+1} = pngPath;
    end
    if saveFig
        figPath = fullfile(outputFolder, 'windowed_moments.fig');
        savefig(figureHandle, figPath);
        files{end+1} = figPath;
    end

    result = struct();
    result.sampleRange = sampleRange;
    result.Fs = Fs;
    result.windowLengths = windowLengths;

    summaryCount = numel(windowLengths);
    result.summary = repmat(struct('windowLength', NaN, 'mean', NaN, 'rms', NaN, 'skewness', NaN, 'kurtosis', NaN), 1, summaryCount);
    for idx = 1:summaryCount
        result.summary(idx).windowLength = windowLengths(idx);
        result.summary(idx).mean = allMean(idx);
        result.summary(idx).rms = allRms(idx);
        result.summary(idx).skewness = allSkew(idx);
        result.summary(idx).kurtosis = allKurtosis(idx);
    end

    result.series = allSeries;
    result.figureHandle = figureHandle;
    result.files = files;
end

function value = getOption(options, fieldName, defaultValue)
    if isfield(options, fieldName) && ~isempty(options.(fieldName))
        value = options.(fieldName);
    else
        value = defaultValue;
    end
end

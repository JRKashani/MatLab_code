function result = analyzeWindowedMoments(signal, sampleRange, Fs, options)
%ANALYZEWINDOWEDMOMENTS Efficient local mean, RMS, skewness and excess kurtosis.
%   Window lengths are in samples. Even windows have one extra sample on
%   the left (length 4 uses offsets -2,-1,0,1); edges shrink to available data.
%   Times refer to the original recording, including a selected range offset.
%
%   options fields (defaults come from DEFINE):
%     windowLengths, stepSec, maxRuntimeSec, runtimeSafetyFactor,
%     maxPlotPoints, outputFolder, makePlots, savePng, saveFig, plotTitle.
%   stepSec empty/zero selects a step using a short timing pilot. A positive
%   value fixes the center spacing. The runtime target is advisory and covers
%   calculation only: disk writes and graphics cannot be reliably budgeted.
%
%   Skewness = m3/m2^(3/2); excess kurtosis = m4/m2^2 - 3, where mr is the
%   population central moment (divide by window count, not count-1). Both
%   shape statistics are undefined (NaN) for a constant window. Summaries
%   average evaluated centers, omitting those undefined shape statistics.
%   Each moment has its own figure, comparing all window lengths against
%   the global value over sampleRange. A radical point is the evaluated
%   center maximizing abs(local moment - global moment), separately for
%   each window length. Ties select the earliest center; undefined moments
%   have no radical point. Detection uses all evaluated centers, before
%   display thinning. Values are returned even when makePlots is false.

    timer = tic;
    D = DEFINE();
    if nargin < 4 || isempty(options), options = struct(); end
    if nargin < 2, sampleRange = []; end
    [segment, sampleRange] = selectSignalSegment(signal, sampleRange, Fs, 2);
    N = numel(segment);
    lengths = getOption(options, 'windowLengths', round(D.WM_WINDOW_SIZES_SEC * Fs));
    validateattributes(lengths, {'numeric'}, {'vector', 'real', 'finite', 'integer', 'positive'});
    lengths = sort(unique(lengths(:)));
    lengths = lengths(lengths >= 2 & lengths <= N);
    if isempty(lengths), lengths = N; end

    stepSec = getOption(options, 'stepSec', D.WM_STEP_SEC);
    target = getOption(options, 'maxRuntimeSec', D.WM_MAX_RUNTIME_SEC);
    safety = getOption(options, 'runtimeSafetyFactor', D.WM_RUNTIME_SAFETY_FACTOR);
    maxPlotPoints = getOption(options, 'maxPlotPoints', D.MAX_PLOT_POINTS);
    validateattributes(target, {'numeric'}, {'scalar', 'real', 'finite', 'positive'});
    validateattributes(safety, {'numeric'}, {'scalar', 'real', 'finite', 'positive', '<=', 1});
    validateattributes(maxPlotPoints, {'numeric'}, {'scalar', 'integer', '>=', 2});
    if ~isempty(stepSec)
        validateattributes(stepSec, {'numeric'}, {'scalar', 'real', 'finite', 'nonnegative'});
    end
    outputFolder = getOption(options, 'outputFolder', fullfile(pwd, 'results'));
    makePlots = getOption(options, 'makePlots', true);
    savePng = getOption(options, 'savePng', D.SAVE_PNG_FILES);
    saveFig = getOption(options, 'saveFig', D.SAVE_FIG_FILES);
    plotTitle = getOption(options, 'plotTitle', 'Windowed moments');

    % Shift and scale before forming powers: a large DC offset should not
    % destroy the precision of much smaller fluctuations or overflow x^4.
    offset = mean(segment);
    scale = max(abs(segment - offset));
    if scale == 0, scale = 1; end
    z = (segment - offset) / scale;
    sums = zeros(N + 1, 4);
    power = ones(N, 1);
    for degree = 1:4
        power = power .* z;
        sums(2:end, degree) = cumsum(power);
    end
    % Equal run IDs at both endpoints identify constant windows exactly.
    % This avoids slow direct recalculation across long constant plateaus.
    runIds = cumsum([1; diff(segment) ~= 0]);

    autoStep = isempty(stepSec) || stepSec == 0;
    estimatedFullSeconds = NaN;
    if autoStep
        pilotCenters = unique(round(linspace(1, N, min(N, 1024)))).';
        pilotTimer = tic;
        for i = 1:numel(lengths)
            calculateSeries(segment, sums, runIds, offset, scale, pilotCenters, lengths(i));
        end
        estimatedFullSeconds = toc(pilotTimer) * N / numel(pilotCenters);
        remaining = max(realmin, target * safety - toc(timer));
        step = min(N, max(1, ceil(estimatedFullSeconds / remaining)));
    else
        step = min(N, max(1, round(stepSec * Fs)));
    end
    centers = (1:step:N).';
    times = (sampleRange(1) + centers - 2) / Fs;
    seriesCells = cell(1, numel(lengths));
    summaryCells = cell(1, numel(lengths));
    for i = 1:numel(lengths)
        current = calculateSeries(segment, sums, runIds, offset, scale, centers, lengths(i));
        seriesCells{i} = current;
        summaryCells{i} = struct('windowLength', lengths(i), ...
            'mean', mean(current.mean), 'rms', mean(current.rms), ...
            'skewness', mean(current.skewness, 'omitnan'), ...
            'kurtosis', mean(current.kurtosis, 'omitnan'));
    end
    series = [seriesCells{:}];
    summary = [summaryCells{:}];
    % Attach common coordinates after assembling the uniform struct array.
    for i = 1:numel(series)
        series(i).time = times;
        series(i).sampleIndices = sampleRange(1) + centers - 1;
    end
    % Use the same population definitions globally and locally. The global
    % reference is calculated directly from the selected signal, never by
    % averaging overlapping windows (which would weight samples unevenly).
    centered = z - mean(z);
    secondMoment = mean(centered.^2);
    globalMoments = struct('mean', offset, ...
        'rms', hypot(offset, scale * sqrt(secondMoment)), ...
        'skewness', NaN, 'kurtosis', NaN);
    if secondMoment > 0
        globalMoments.skewness = mean(centered.^3) / secondMoment^1.5;
        globalMoments.kurtosis = mean(centered.^4) / secondMoment^2 - 3;
    end
    radicalPoints = findRadicalPoints(series, globalMoments);
    calculationSeconds = toc(timer);
    if calculationSeconds > target
        warning('analyzeWindowedMoments:runtimeTargetExceeded', ...
            'Moment calculation took %.2f s (target %.2f s; step %d samples).', calculationSeconds, target, step);
    end

    files = {};
    figureHandle = [];
    if makePlots
        plotOptions = struct('maxPlotPoints', maxPlotPoints, 'outputFolder', outputFolder, ...
            'savePng', savePng, 'saveFig', saveFig, 'plotTitle', plotTitle);
        [figureHandle, files] = plotWindowedMoments(series, globalMoments, radicalPoints, Fs, plotOptions);
    end

    result = struct('sampleRange', sampleRange, 'Fs', Fs, 'windowLengths', lengths, ...
        'summary', summary, 'series', series, 'figureHandle', figureHandle, 'files', {files});
    % figureHandle now contains four figures in this documented order.
    result.figureMoments = {'mean', 'rms', 'skewness', 'kurtosis'};
    result.globalMoments = globalMoments;
    result.radicalPoints = radicalPoints;
    result.settings = struct('WM_WINDOW_SIZES_SEC', lengths / Fs, ...
        'WM_STEP_SEC', stepSec, 'WM_MAX_RUNTIME_SEC', target, ...
        'WM_RUNTIME_SAFETY_FACTOR', safety, 'stepSamples', step, ...
        'actualStepSec', step / Fs, 'automaticStep', autoStep, ...
        'maxPlotPoints', maxPlotPoints, 'estimatedFullCalculationSeconds', estimatedFullSeconds);
    result.calculationSeconds = calculationSeconds;
    result.elapsedSeconds = toc(timer);
end

function radicalPoints = findRadicalPoints(series, globalMoments)
% Store coordinates and signed/absolute differences so saved numerical
% results describe the markers without requiring a live figure handle.
    names = fieldnames(globalMoments);
    emptyPoint = struct('defined', false, 'windowLength', NaN, 'seriesIndex', NaN, ...
        'sampleIndex', NaN, 'time', NaN, 'value', NaN, 'globalValue', NaN, ...
        'signedDeviation', NaN, 'absoluteDeviation', NaN);
    radicalPoints = struct();
    for m = 1:numel(names)
        name = names{m};
        reference = globalMoments.(name);
        points = repmat(emptyPoint, 1, numel(series));
        for i = 1:numel(series)
            points(i).windowLength = series(i).windowLength;
            points(i).globalValue = reference;
            values = series(i).(name);
            valid = find(isfinite(values) & isfinite(reference));
            if isempty(valid), continue; end
            [deviation, position] = max(abs(values(valid) - reference));
            index = valid(position);
            points(i).defined = true;
            points(i).seriesIndex = index;
            points(i).sampleIndex = series(i).sampleIndices(index);
            points(i).time = series(i).time(index);
            points(i).value = values(index);
            points(i).signedDeviation = values(index) - reference;
            points(i).absoluteDeviation = deviation;
        end
        radicalPoints.(name) = points;
    end
end

function series = calculateSeries(x, sums, runIds, offset, scale, centers, lengthSamples)
% Four prefix-sum differences give each window's raw moments in constant
% time. Total normal-case work is O(N + windows * evaluatedCenters).
    left = floor(lengthSamples / 2);
    right = lengthSamples - left - 1;
    first = max(1, centers - left);
    last = min(numel(x), centers + right);
    count = last - first + 1;
    raw = (sums(last + 1, :) - sums(first, :)) ./ count;
    mu = raw(:, 1);
    m2 = raw(:, 2) - mu.^2;
    m3 = raw(:, 3) - 3*mu.*raw(:, 2) + 2*mu.^3;
    m4 = raw(:, 4) - 4*mu.*raw(:, 3) + 6*mu.^2.*raw(:, 2) - 3*mu.^4;
    constant = runIds(first) == runIds(last);

    % Nearly constant windows far from the overall mean suffer cancellation
    % in raw-to-central conversion. Recompute only these exceptional windows
    % directly about their own mean, rather than report unreliable ratios.
    suspect = ~constant & (m2 <= 1e-8 * max(raw(:, 2), mu.^2) | m4 < m2.^2);
    for j = find(suspect).'
        local = (x(first(j):last(j)) - x(first(j))) / scale;
        localMean = mean(local);
        mu(j) = (x(first(j)) - offset) / scale + localMean;
        centered = local - localMean;
        m2(j) = mean(centered.^2);
        m3(j) = mean(centered.^3);
        m4(j) = mean(centered.^4);
    end
    means = offset + scale * mu;
    rmsValues = hypot(means, scale * sqrt(max(0, m2)));
    skew = NaN(size(mu));
    kurt = NaN(size(mu));
    valid = ~constant & m2 > 0;
    skew(valid) = m3(valid) ./ m2(valid).^1.5;
    kurt(valid) = m4(valid) ./ m2(valid).^2 - 3;
    means(constant) = x(first(constant));
    rmsValues(constant) = abs(means(constant));
    series = struct('mean', means, 'rms', rmsValues, 'skewness', skew, ...
        'kurtosis', kurt, 'windowLength', lengthSamples, 'sampleCount', count);
end

function value = getOption(options, fieldName, defaultValue)
    if isfield(options, fieldName) && ~isempty(options.(fieldName))
        value = options.(fieldName);
    else
        value = defaultValue;
    end
end

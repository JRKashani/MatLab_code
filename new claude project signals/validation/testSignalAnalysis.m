function tests = testSignalAnalysis
%TESTSIGNALANALYSIS Regression checks using known signals and direct formulas.
%   From the project root: results = runtests('validation/testSignalAnalysis.m')
%   Fixtures use a temporary folder; project configurations/results are untouched.
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    testCase.TestData.originalPath = path;
    testCase.TestData.originalRng = rng;
    root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(root, 'utilities'), fullfile(root, 'psd'), ...
        fullfile(root, 'moments'), fullfile(root, 'plotting'), root);
    testCase.TestData.outputFolder = tempname;
    mkdir(testCase.TestData.outputFolder);
    testCase.TestData.visible = get(groot, 'DefaultFigureVisible');
    set(groot, 'DefaultFigureVisible', 'off');
end

function setup(testCase)
    testCase.TestData.previousFigures = findall(groot, 'Type', 'figure');
end

function teardown(testCase)
    created = setdiff(findall(groot, 'Type', 'figure'), testCase.TestData.previousFigures);
    close(created);
end

function teardownOnce(testCase)
    set(groot, 'DefaultFigureVisible', testCase.TestData.visible);
    path(testCase.TestData.originalPath);
    rng(testCase.TestData.originalRng);
end

function testPSDsUseOnlySelectedSamples(testCase)
    Fs = 1024;
    t = (0:1023)' / Fs;
    selected = sin(2*pi*128*t) + 0.02*cos(2*pi*211*t);
    signal = [100*sin(2*pi*32*t); selected; NaN(10, 1)];
    methods = {@runPeriodogramPSD, @runWelchPSD, @runBurgPSD};
    for k = 1:numel(methods)
        result = methods{k}(signal, [1025 2048], Fs, 'range test', testCase.TestData.outputFolder);
        cropped = methods{k}(selected, [], Fs, 'cropped test', testCase.TestData.outputFolder);
        verifyEqual(testCase, result.psd, cropped.psd, 'AbsTol', 1e-12);
        verifyEqual(testCase, result.sampleRange, [1025 2048]);
        verifyEqual(testCase, result.sampleCount, 1024);
        [~, peak] = max(result.psd);
        verifyLessThanOrEqual(testCase, abs(result.f(peak) - 128), 1);
    end
end

function testProjectPathsUsesRootConfig(testCase)
    root = fileparts(fileparts(mfilename('fullpath')));
    paths = projectPaths(root);
    verifyEqual(testCase, paths.configPath, fullfile(root, 'main_config.txt'));
    verifyTrue(testCase, isfile(paths.configPath));
end

function testInvalidSegmentsFailBeforePlotting(testCase)
    methods = {@runPeriodogramPSD, @runWelchPSD, @runBurgPSD};
    for k = 1:numel(methods)
        verifyError(testCase, @() methods{k}(1:20, [5 21], 10), 'selectSignalSegment:invalidRange');
        verifyError(testCase, @() methods{k}(1:20, [8 2], 10), 'selectSignalSegment:invalidRange');
        verifyError(testCase, @() methods{k}([1 NaN 3], [], 10), 'selectSignalSegment:invalidValues');
    end
    verifyError(testCase, @() runPeriodogramPSD([1 2], [], 10), 'selectSignalSegment:tooShort');
    verifyError(testCase, @() runWelchPSD([1 2], [], 10), 'selectSignalSegment:tooShort');
    didFail = false;
    try
        selectSignalSegment(1:20, [1.5 10], 10);
    catch
        didFail = true;
    end
    verifyTrue(testCase, didFail, 'Fractional indices must not be silently rounded.');
end

function testMomentsAgainstDirectWindows(testCase)
    x = (1:40)'.^2 - 50;
    options = struct('windowLengths', [4 5], 'stepSec', 0.1, 'makePlots', false);
    result = analyzeWindowedMoments(x, [5 30], 10, options);
    selected = x(5:30);
    for i = 1:numel(result.series)
        series = result.series(i);
        L = series.windowLength;
        for k = 1:numel(selected)
            indices = max(1, k-floor(L/2)):min(numel(selected), k+ceil(L/2)-1);
            w = selected(indices);
            central = w - mean(w);
            expected = [mean(w), sqrt(mean(w.^2)), ...
                mean(central.^3)/mean(central.^2)^1.5, mean(central.^4)/mean(central.^2)^2 - 3];
            actual = [series.mean(k), series.rms(k), series.skewness(k), series.kurtosis(k)];
            verifyEqual(testCase, actual, expected, 'AbsTol', 1e-7);
            verifyEqual(testCase, series.sampleCount(k), numel(w));
        end
        verifyEqual(testCase, series.time, (4:29)'/10);
        verifyEqual(testCase, series.sampleIndices, (5:30)');
    end
end

function testConstantAndOffsetSignals(testCase)
    options = struct('windowLengths', 4, 'stepSec', 1, 'makePlots', false);
    result = analyzeWindowedMoments(3*ones(20, 1), [], 1, options);
    verifyEqual(testCase, result.series.mean, 3*ones(20, 1));
    verifyEqual(testCase, result.series.rms, 3*ones(20, 1));
    verifyTrue(testCase, all(isnan(result.series.skewness)));
    verifyTrue(testCase, all(isnan(result.series.kurtosis)));
    fluctuation = repmat([-2; -1; 1; 2], 10, 1);
    shifted = analyzeWindowedMoments(1e10 + fluctuation, [], 1, options);
    baseline = analyzeWindowedMoments(fluctuation, [], 1, options);
    verifyEqual(testCase, shifted.series.skewness, baseline.series.skewness, 'AbsTol', 1e-10);
    verifyEqual(testCase, shifted.series.kurtosis, baseline.series.kurtosis, 'AbsTol', 1e-10);
end

function testSineMoments(testCase)
    x = sin(2*pi*(0:999)'/100);
    result = analyzeWindowedMoments(x, [], 100, ...
        struct('windowLengths', 100, 'stepSec', 0.01, 'makePlots', false));
    interior = 51:950;
    verifyEqual(testCase, result.series.rms(interior), repmat(sqrt(0.5), 900, 1), 'AbsTol', 1e-10);
    verifyEqual(testCase, result.series.skewness(interior), zeros(900, 1), 'AbsTol', 1e-10);
    verifyEqual(testCase, result.series.kurtosis(interior), -1.5*ones(900, 1), 'AbsTol', 1e-10);
end

function testStepAndPlotLimit(testCase)
    options = struct('windowLengths', 8, 'stepSec', 0.03, ...
        'maxPlotPoints', 7, 'saveFig', false, 'savePng', false);
    result = analyzeWindowedMoments(sin((1:100)'), [11 90], 100, options);
    verifyEqual(testCase, result.settings.stepSamples, 3);
    verifyEqual(testCase, result.series.sampleIndices, (11:3:90)');
    lines = findall(result.figureHandle, 'Type', 'line');
    for k = 1:numel(lines)
        verifyLessThanOrEqual(testCase, numel(lines(k).XData), 7);
    end
    verifyGreaterThan(testCase, numel(result.series.mean), 7);
end

function testAutomaticBudgetAndInputValidation(testCase)
    options = struct('windowLengths', 8, 'stepSec', 0, 'makePlots', false, 'maxRuntimeSec', 1e-12);
    state = warning('off', 'analyzeWindowedMoments:runtimeTargetExceeded');
    cleanup = onCleanup(@() warning(state)); %#ok<NASGU>
    result = analyzeWindowedMoments(sin((1:1000)'), [], 100, options);
    verifyTrue(testCase, result.settings.automaticStep);
    verifyGreaterThan(testCase, result.settings.stepSamples, 1);
    verifyError(testCase, @() analyzeWindowedMoments([1 Inf 2], [], 10, options), 'selectSignalSegment:invalidValues');
end

function testRadicalPointsUseGlobalSelectedSignal(testCase)
    x = [1000*ones(10, 1); (1:50)'; -1000*ones(10, 1)];
    result = analyzeWindowedMoments(x, [11 60], 10, ...
        struct('windowLengths', [4 9], 'stepSec', 0.1, 'makePlots', false));
    selected = (1:50)';
    centered = selected - mean(selected);
    expected = struct('mean', mean(selected), 'rms', sqrt(mean(selected.^2)), ...
        'skewness', mean(centered.^3)/mean(centered.^2)^1.5, ...
        'kurtosis', mean(centered.^4)/mean(centered.^2)^2 - 3);
    names = fieldnames(expected);
    for m = 1:numel(names)
        name = names{m};
        verifyEqual(testCase, result.globalMoments.(name), expected.(name), 'AbsTol', 1e-12);
        for i = 1:numel(result.series)
            point = result.radicalPoints.(name)(i);
            values = result.series(i).(name);
            [distance, index] = max(abs(values - result.globalMoments.(name)));
            verifyTrue(testCase, point.defined);
            verifyEqual(testCase, point.seriesIndex, index);
            verifyEqual(testCase, point.sampleIndex, index + 10);
            verifyEqual(testCase, point.time, (point.sampleIndex - 1)/10);
            verifyEqual(testCase, point.absoluteDeviation, distance);
            verifyEqual(testCase, point.value, values(index));
        end
    end
end

function testSeparateMomentFiguresRetainRadicalPoints(testCase)
    x = sin((1:100)' / 5);
    x(44) = 30;
    options = struct('windowLengths', [4 9], 'stepSec', 0.1, 'maxPlotPoints', 5, ...
        'saveFig', true, 'savePng', true, 'outputFolder', testCase.TestData.outputFolder);
    result = analyzeWindowedMoments(x, [], 10, options);
    verifyNumElements(testCase, result.figureHandle, 4);
    verifyNumElements(testCase, result.files, 8);
    for m = 1:4
        name = result.figureMoments{m};
        fig = result.figureHandle(m);
        verifyNumElements(testCase, findall(fig, 'Type', 'axes'), 1);
        legends = findall(fig, 'Type', 'legend');
        verifyNumElements(testCase, legends, 1);
        verifyEqual(testCase, legends.Location, 'southoutside');
        verifyNumElements(testCase, legends.String, 4); % Two windows, global line, largest marker.
        curves = findall(fig, 'Tag', 'momentCurve');
        verifyNumElements(testCase, curves, 2);
        verifyNumElements(testCase, findall(fig, 'Tag', 'radicalPoint'), 2);
        verifyNumElements(testCase, findall(fig, 'Tag', 'largestDeviation'), 1);
        reference = findall(fig, 'Tag', 'globalMoment');
        verifyEqual(testCase, reference.Value, result.globalMoments.(name));
        for i = 1:2
            point = result.radicalPoints.(name)(i);
            curve = findobj(curves, 'DisplayName', sprintf('%.4g s (%d samples), |rad - global| = %.5g', ...
                point.windowLength / 10, point.windowLength, point.absoluteDeviation));
            verifyLessThanOrEqual(testCase, numel(curve.XData), 5);
            verifyTrue(testCase, any(curve.XData == point.time & curve.YData == point.value));
        end
    end
    for i = 1:numel(result.files)
        verifyTrue(testCase, isfile(result.files{i}));
    end
    saved = numericalResults(result);
    verifyEmpty(testCase, saved.figureHandle);
    verifyEqual(testCase, saved.radicalPoints, result.radicalPoints);
end

function testUndefinedRadicalPointsAndTies(testCase)
    result = analyzeWindowedMoments(3*ones(20, 1), [], 1, ...
        struct('windowLengths', [4 5], 'stepSec', 1, 'saveFig', false, 'savePng', false));
    for name = {'mean', 'rms'}
        points = result.radicalPoints.(name{1});
        verifyEqual(testCase, [points.seriesIndex], [1 1]);
        verifyEqual(testCase, [points.absoluteDeviation], [0 0]);
    end
    for m = 3:4
        points = result.radicalPoints.(result.figureMoments{m});
        verifyFalse(testCase, any([points.defined]));
        verifyEmpty(testCase, findall(result.figureHandle(m), 'Tag', 'radicalPoint'));
        verifyEmpty(testCase, findall(result.figureHandle(m), 'Tag', 'globalMoment'));
    end
end

function testMissionFailuresRemainVisibleAndNonfatal(testCase)
    logPath = fullfile(testCase.TestData.outputFolder, 'mission_test.log');
    fid = fopen(logPath, 'w');
    cleanup = onCleanup(@() fclose(fid));
    captured = evalc('[ok, result] = runMission(fid, ''expected exception'', @throwExpected);');
    verifyFalse(testCase, ok);
    verifyEmpty(testCase, result);
    verifyTrue(testCase, contains(captured, 'diagnostic text'));
    report = struct('allPassed', false, 'failedTests', {{'known check'}});
    [ok, result] = runMission(fid, 'failed validation', @() report);
    verifyFalse(testCase, ok);
    verifyEqual(testCase, result, report);
    [ok, ~] = runMission(fid, 'placeholder', @() struct('status', 'not_implemented'));
    verifyFalse(testCase, ok);
    [ok, result] = runMission(fid, 'subsequent mission', @() 42);
    verifyTrue(testCase, ok);
    verifyEqual(testCase, result, 42);
    clear cleanup;
    logText = fileread(logPath);
    verifyTrue(testCase, contains(logText, 'FAILURE: expected exception'));
    verifyTrue(testCase, contains(logText, 'SUCCESS: subsequent mission'));
end

function result = throwExpected() %#ok<STOUT>
    error('test:expected', 'diagnostic text');
end

function testSavedResultsExcludeFigures(testCase)
    figureHandle = figure('Visible', 'off');
    plot(1:10);
    results = struct('windowedMoments', struct('figureHandle', figureHandle, ...
        'series', struct('mean', (1:10)')), 'timePlot', figureHandle);
    output = fullfile(testCase.TestData.outputFolder, 'final.mat');
    saveFinalResults(output, results, struct('moments', true), struct());
    saved = load(output);
    verifyEmpty(testCase, saved.results.windowedMoments.figureHandle);
    verifyEmpty(testCase, saved.results.timePlot);
    verifyEqual(testCase, saved.results.windowedMoments.series.mean, (1:10)');
    saveAnalysisResults(results, struct(), testCase.TestData.outputFolder);
    saved = load(fullfile(testCase.TestData.outputFolder, 'analysis_results.mat'));
    verifyEmpty(testCase, saved.analysisSubset.windowedMoments.figureHandle);
end

function testPSDNormalizationAndBurgKnownProcess(testCase)
    rng(42);
    Fs = 1000;
    x = randn(4096, 1);
    w = hannWindowManual(numel(x));
    for nfft = [4096 4097]
        [p, ~] = computePeriodogramPSD(x, Fs, w, nfft);
        verifyEqual(testCase, sum(p)*Fs/nfft, sum((x.*w).^2)/sum(w.^2), 'AbsTol', 1e-10);
        [welch, ~] = computeWelchPSD(x, Fs, numel(x), 0, w, nfft);
        verifyEqual(testCase, welch, p, 'AbsTol', 1e-12);
    end
    x = filter(1, [1 -0.8], randn(100000, 1));
    [p, f] = computeBurgPSD(x, Fs, 1, 4096);
    expected = 1 ./ abs(1 - 0.8*exp(-1i*2*pi*f/Fs)).^2 / Fs;
    expected(2:end-1) = 2*expected(2:end-1);
    verifyLessThan(testCase, norm(p-expected)/norm(expected), 0.05);
end

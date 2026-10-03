function tests = testVariableWelch
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    testCase.TestData.originalPath = path;
    testCase.TestData.originalRng = rng;
    root = fileparts(fileparts(mfilename('fullpath')));
    addpath(root, fullfile(root, 'psd'), fullfile(root, 'utilities'));
    testCase.TestData.visible = get(groot, 'DefaultFigureVisible');
    set(groot, 'DefaultFigureVisible', 'off');
end

function teardownOnce(testCase)
    path(testCase.TestData.originalPath);
    rng(testCase.TestData.originalRng);
    set(groot, 'DefaultFigureVisible', testCase.TestData.visible);
end

function testFineBandsResolveCloseTonesAndBackgroundIsCalmer(testCase)
    rng(84);
    Fs = 1000;
    t = (0:59999)'/Fs;
    x = sin(2*pi*100*t) + 0.6*sin(2*pi*102*t) + 0.2*randn(size(t));
    r = computeVariableWelchPSD(x, [], Fs, [100 102], struct('coarseWindowSamples',256));
    verifyEqual(testCase, r.fineWindowSamples, 128*r.coarseWindowSamples);
    verifyEqual(testCase, r.coarseResolutionHz/r.fineResolutionHz, 128, 'AbsTol', 1e-12);
    verifyEqual(testCase, r.fineBandsHz, [90 112]);
    verifyEqual(testCase, r.transitionFrequenciesHz, [90; 112]);
    verifyTrue(testCase, all(diff(r.f) > 0));
    verifyTrue(testCase, all(isfinite(r.psd) & r.psd >= 0));
    for frequency = [100 102]
        indices = find(abs(r.f-frequency) < 0.5);
        [~, maximum] = max(r.psd(indices));
        verifyLessThanOrEqual(testCase, abs(r.f(indices(maximum))-frequency), r.fineResolutionHz);
    end
    mask = r.isFineResolution;
    verifyEqual(testCase, trapz(r.f(mask), r.psd(mask)), (1^2+0.6^2)/2, 'RelTol', 0.04);
    coarseNoise = r.coarse.psd(r.coarse.f > 200 & r.coarse.f < 400);
    fineNoise = r.fine.psd(r.fine.f > 200 & r.fine.f < 400);
    verifyLessThan(testCase, std(coarseNoise)/mean(coarseNoise), std(fineNoise)/mean(fineNoise));
end

function testNoPeaksShortRecordsAndRangeIsolation(testCase)
    rng(17);
    x = randn(600,1);
    r = computeVariableWelchPSD(x, [], 1000, []);
    verifyEqual(testCase, r.coarseWindowSamples, 4);
    verifyEqual(testCase, r.fineWindowSamples, 512);
    verifyEmpty(testCase, r.fineBandsHz);
    verifyEmpty(testCase, r.transitionFrequenciesHz);
    verifyEqual(testCase, r.psd, r.coarse.psd);
    original = [NaN(10,1); x; NaN(5,1)];
    cropped = computeVariableWelchPSD(original, [11 610], 1000, []);
    verifyEqual(testCase, cropped.psd, r.psd);
    verifyError(testCase, @() computeVariableWelchPSD(x(1:511), [], 1000, 100), ...
        'selectSignalSegment:tooShort');
    edges = computeVariableWelchPSD(x, [], 1000, [1 499]);
    verifyEqual(testCase, edges.fineBandsHz, [0 11; 489 500]);
    verifyEqual(testCase, edges.transitionFrequenciesHz, [11; 489]);
end

function testOneCurveBoundariesAndSavedMetadata(testCase)
    Fs = 1000;
    x = sin(2*pi*100*(0:9999)'/Fs);
    fftResult = struct('allPeakFrequenciesHz', 100, 'sampleRange', [1 numel(x)], ...
        'frequencyResolutionHz', Fs/numel(x), 'sampleCount', numel(x));
    options = struct('savePng',false,'saveFig',false);
    folder = tempname;
    r = runVariableWelchPSD(x, [], Fs, fftResult, 'test', folder, options);
    cleanup = onCleanup(@() close(r.figureHandle)); %#ok<NASGU>
    verifyEqual(testCase, numel(findall(r.figureHandle, 'Tag', 'variableWelchCurve')), 1);
    verifyEqual(testCase, numel(findall(r.figureHandle, 'Tag', 'welchResolutionBoundary')), 2);
    verifyEqual(testCase, numel(findall(r.figureHandle, 'Tag', 'psdIntegralLegend')), 1);
    leg = findall(r.figureHandle, 'Type', 'legend');
    verifyEqual(testCase, numel(leg.String), 2);
    % On this nonuniform grid the integral must use each interval's width.
    expectedArea = sum(diff(r.f) .* (r.psd(1:end-1)+r.psd(2:end))/2);
    verifyEqual(testCase, r.integratedPower, expectedArea, 'RelTol', 1e-12);
    verifyFalse(testCase, isfolder(folder));
    saveAnalysisResults(struct('variableWelch',r), struct(), folder);
    loaded = load(fullfile(folder,'analysis_results.mat'));
    verifyEqual(testCase, loaded.analysisSubset.variableWelch.psd, r.psd);
    verifyEqual(testCase, loaded.analysisSubset.variableWelch.integratedPower, r.integratedPower);
    verifyEmpty(testCase, loaded.analysisSubset.variableWelch.figureHandle);
    verifyTrue(testCase, contains(fileread(fullfile(folder,'analysis_summary.txt')), '128 times finer'));
    verifyError(testCase, @() runVariableWelchPSD(x, [], Fs, [], 'test', folder), ...
        'runVariableWelchPSD:missingFFT');
    verifyError(testCase, @() runVariableWelchPSD(x, [], Fs*2, fftResult, 'test', folder), ...
        'runVariableWelchPSD:incompatibleFFT');
end

function testWindowLengthsRemainPowersOfTwoWhenRecordLimitsThem(testCase)
    r = computeVariableWelchPSD(ones(10000,1), [], 16384, 100);
    verifyEqual(testCase, [r.coarseWindowSamples r.fineWindowSamples], [64 8192]);
    verifyEqual(testCase, [r.coarse.nfft r.fine.nfft], [64 8192]);
    r = computeVariableWelchPSD(ones(131072,1), [], 16384, 100, ...
        struct('coarseWindowSamples',1000));
    verifyEqual(testCase, [r.coarseWindowSamples r.fineWindowSamples], [512 65536]);
    verifyError(testCase, @() computeVariableWelchPSD(ones(10000,1), [], 16384, 100, ...
        struct('resolutionRatio',100)), 'computeVariableWelchPSD:invalidRatio');
end

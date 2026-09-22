function tests = testTonalSNR
%TESTTONALSNR Check blind estimates against known signals, not generator input.
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    testCase.TestData.originalPath = path;
    testCase.TestData.originalRng = rng;
    root = fileparts(fileparts(mfilename('fullpath')));
    addpath(root, fullfile(root,'snr'), fullfile(root,'psd'), ...
        fullfile(root,'utilities'), fullfile(root,'plotting'));
end

function teardownOnce(testCase)
    path(testCase.TestData.originalPath);
    rng(testCase.TestData.originalRng);
end

function testStationaryTonesAndFullBandNoise(testCase)
    rng(121);
    Fs = 2048;
    t = (0:Fs*12-1)'/Fs;
    s = 2*sin(2*pi*123.4*t) + sin(2*pi*347.8*t+0.6);
    noise = 0.5*randn(size(t));
    r = estimateTonalSNR(s+noise, [], Fs);
    verifyEqual(testCase, r.status, 'ok');
    verifyEqual(testCase, numel(r.tracks), 2);
    verifyEqual(testCase, sort(r.peakFrequenciesHz), [123.4 347.8], 'AbsTol', 0.2);
    verifyEqual(testCase, r.noiseRMS, sqrt(mean(noise.^2)), 'RelTol', 0.05);
    verifyEqual(testCase, r.overallSNRdB, 10*log10(mean(s.^2)/mean(noise.^2)), 'AbsTol', 0.5);
    verifyEqual(testCase, sum([r.tracks.meanPower]), r.signalPower, 'AbsTol', 1e-12);
    verifyEqual(testCase, r.noiseBandHz, [0 Fs/2]);
    verifyEqual(testCase, sum(r.frames.weights), 1, 'AbsTol', 1e-12);
end

function testDecayingChirpTracksFrequencyAndAmplitude(testCase)
    rng(22);
    Fs = 1024;
    t = (0:Fs*8-1)'/Fs;
    amplitude = 2*exp(-t/6);
    s = amplitude .* sin(2*pi*(80*t+1.5*t.^2)); % 80 + 3*t Hz
    noise = 0.15*randn(size(t));
    r = estimateTonalSNR(s+noise, [], Fs);
    verifyEqual(testCase, numel(r.tracks), 1);
    track = r.tracks(1);
    expectedFrequency = 80+3*r.frames.time;
    verifyEqual(testCase, track.frequencyHz, expectedFrequency, 'AbsTol', 0.35);
    verifyEqual(testCase, track.amplitude, 2*exp(-r.frames.time/6), 'AbsTol', 0.1);
    verifyEqual(testCase, r.noiseRMS, sqrt(mean(noise.^2)), 'RelTol', 0.08);
    verifyEqual(testCase, r.overallSNRdB, 10*log10(mean(s.^2)/mean(noise.^2)), 'AbsTol', 0.6);
end

function testNoiseOnlyDoesNotInventPersistentTones(testCase)
    rng(33);
    x = 0.4*randn(2048*12,1);
    r = estimateTonalSNR(x, [], 2048);
    verifyEqual(testCase, r.status, 'no_tones_detected');
    verifyEmpty(testCase, r.tracks);
    verifyEqual(testCase, r.noiseRMS, sqrt(mean(x.^2)), 'RelTol', 0.05);
    verifyEqual(testCase, r.overallSNRdB, -Inf);
end

function testConstantSignalAndShortRecording(testCase)
    r = estimateTonalSNR(3*ones(1024,1), [], 1024);
    verifyEqual(testCase, r.status, 'no_ac_power');
    verifyEqual(testCase, r.noiseRMS, 0);
    verifyTrue(testCase, isnan(r.overallSNRdB));
    r = estimateTonalSNR(ones(64,1), [], 1024);
    verifyEqual(testCase, numel(r.frames.time), 1);
    verifyError(testCase, @() estimateTonalSNR(ones(63,1), [], 1024), ...
        'selectSignalSegment:tooShort');
end

function testSelectedRangeAndDcDoNotAffectNoiseEstimate(testCase)
    rng(55);
    Fs = 1024;
    t = (0:Fs*3-1)'/Fs;
    selected = sin(2*pi*150.3*t) + 0.1*randn(size(t));
    original = [NaN(200,1); selected+10; NaN(100,1)];
    r = estimateTonalSNR(original, [201 200+numel(selected)], Fs);
    cropped = estimateTonalSNR(selected, [], Fs);
    verifyEqual(testCase, r.noiseRMS, cropped.noiseRMS, 'AbsTol', 1e-12);
    verifyEqual(testCase, r.overallSNRdB, cropped.overallSNRdB, 'AbsTol', 1e-10);
    verifyEqual(testCase, r.frames.time, cropped.frames.time+200/Fs, 'AbsTol', 1e-12);
end

function testWrapperSavesNumericalSummaryWithoutPlots(testCase)
    rng(77);
    Fs = 1024;
    t = (0:Fs*3-1)'/Fs;
    folder = tempname;
    r = runSNRAnalysis(sin(2*pi*100*t)+0.2*randn(size(t)), [], Fs, ...
        'experimental', folder, struct('makePlots',false));
    verifyEmpty(testCase, r.figureHandle);
    verifyFalse(testCase, isfolder(folder));
    saveAnalysisResults(struct('snr',r),struct('Fs',Fs),folder);
    summary = fileread(fullfile(folder,'analysis_summary.txt'));
    verifyTrue(testCase, contains(summary,'Estimated white-noise RMS:'));
    verifyTrue(testCase, contains(summary,'Tone 1:'));
    loaded = load(fullfile(folder,'analysis_results.mat'));
    verifyEqual(testCase, loaded.analysisSubset.snr.noiseRMS, r.noiseRMS);
end

function main()
%MAIN Orchestrator for the synthetic signal analysis project.
%   This entry point only sets up paths, loads/generates the signal,
%   defines the sample range, runs enabled missions, logs failures, and
%   saves final numerical results. It does not contain the main analysis
%   algorithms themselves.

    clc;
    close all;

    % 1) Project path setup.
    projectRoot = fileparts(mfilename('fullpath'));
    if isempty(projectRoot)
        projectRoot = pwd;
    end

    utilitiesDir = fullfile(projectRoot, 'utilities');
    if exist(utilitiesDir, 'dir')
        addpath(utilitiesDir);
    end

    paths = projectPaths(projectRoot);
    addpath(genpath(projectRoot));
    addpath(paths.generationDir, paths.plottingDir, paths.momentsDir, paths.fftDir, paths.psdDir, paths.snrDir, paths.validationDir, paths.utilitiesDir);
    if ~exist(paths.resultsDir, 'dir')
        mkdir(paths.resultsDir);
    end

    % 2) Mission flags.
    RUN_GENERATION = true;
    RUN_TIME_PLOT = true;
    RUN_HISTOGRAMS = true;
    RUN_MOMENTS = true;
    RUN_FFT = true;
    RUN_PERIODOGRAM = true;
    RUN_WELCH = true;
    RUN_BURG = true;
    RUN_SNR = false;
    RUN_VALIDATION = true;

    flags = struct();
    flags.RUN_GENERATION = RUN_GENERATION;
    flags.RUN_TIME_PLOT = RUN_TIME_PLOT;
    flags.RUN_HISTOGRAMS = RUN_HISTOGRAMS;
    flags.RUN_MOMENTS = RUN_MOMENTS;
    flags.RUN_FFT = RUN_FFT;
    flags.RUN_PERIODOGRAM = RUN_PERIODOGRAM;
    flags.RUN_WELCH = RUN_WELCH;
    flags.RUN_BURG = RUN_BURG;
    flags.RUN_SNR = RUN_SNR;
    flags.RUN_VALIDATION = RUN_VALIDATION;

    fid = fopen(paths.logFile, 'w');
    if fid == -1
        error('main:cannotWriteLog', 'Could not open mission log at %s.', paths.logFile);
    end

    fprintf(fid, 'Project run started at %s\n', datestr(now));
    missionStatus = struct();
    results = struct();

    % 3) Generate or load signal.
    if RUN_GENERATION
        [missionStatus.generation, results.generation] = runMission(fid, 'Generate signal', @() ...
            generateSignalMission(paths.configPath, paths.signalMatPath));

        if missionStatus.generation
            loaded = load(paths.signalMatPath);
            data = loaded.(DEFINE().MAT_ROOT_VARNAME);
            signal = data.combinedSignal(:);
            time = (0:numel(signal)-1)' / data.Fs;
            sampleRange = [1, numel(signal)];
            cfg = data.Config;
            results.generation = struct('signal', signal, 'time', time, 'Fs', data.Fs, 'sampleRange', sampleRange, 'cfg', cfg);
        else
            fclose(fid);
            error('main:signalGenerationFailed', 'Signal generation failed; mission set cannot continue without signal data.');
        end
    else
        % TODO: add optional load-from-mat workflow once non-synthetic data use is required.
        error('main:generationDisabled', 'Generation is currently required for this orchestrator.');
    end

    % 4) Define the sample range for analysis use.
    %    This is intentionally kept plain and reusable; downstream analysis files
    %    may clamp or validate it independently.
    sampleRange = [1, numel(signal)];

    % 5) Run enabled missions independently.
    if RUN_TIME_PLOT
        [missionStatus.timePlot, resultTmp] = runMission(fid, 'Signal vs time plot', @() ...
            plotSignalVsTime(signal, time, paths.resultsDir));
        results.timePlot = resultTmp;
    end

    if RUN_HISTOGRAMS
        [missionStatus.histograms, resultTmp] = runMission(fid, 'Histogram plot', @() ...
            plotHistogram(signal, paths.resultsDir));
        results.histograms = resultTmp;
    end

    if RUN_MOMENTS
        [missionStatus.windowedMoments, resultTmp] = runMission(fid, 'Windowed moments', @() ...
            computeWindowedMoments(signal, max(64, round(0.25 * cfg.Fs)), cfg.Fs, paths.resultsDir));
        results.windowedMoments = resultTmp;
    end

    if RUN_FFT
        [missionStatus.fft, resultTmp] = runMission(fid, 'FFT', @() ...
            runFFTAnalysis(signal, sampleRange, cfg.Fs, 'combinedSignal', paths.resultsDir, 'm/s^2', true, true));
        results.fft = resultTmp;
    end

    if RUN_PERIODOGRAM
        [missionStatus.periodogram, resultTmp] = runMission(fid, 'Periodogram PSD', @() ...
            runPeriodogramPSD(signal, sampleRange, cfg.Fs, 'combinedSignal', paths.resultsDir));
        results.periodogram = resultTmp;
    end

    if RUN_WELCH
        [missionStatus.welch, resultTmp] = runMission(fid, 'Welch PSD', @() ...
            runWelchPSD(signal, sampleRange, cfg.Fs, 'combinedSignal', paths.resultsDir));
        results.welch = resultTmp;
    end

    if RUN_BURG
        [missionStatus.burg, resultTmp] = runMission(fid, 'Burg PSD', @() ...
            runBurgPSD(signal, sampleRange, cfg.Fs, 'combinedSignal', paths.resultsDir));
        results.burg = resultTmp;
    end

    if RUN_SNR
        [missionStatus.snr, resultTmp] = runMission(fid, 'SNR', @() ...
            runSNRAnalysis(signal, sampleRange, cfg.Fs, 'combinedSignal', paths.resultsDir));
        results.snr = resultTmp;
    end

    if RUN_VALIDATION
        [missionStatus.validation, resultTmp] = runMission(fid, 'Validation', @() ...
            validateSyntheticAnalysis(paths.signalMatPath, struct('printSummary', false)));
        results.validation = resultTmp;
    end

    % 6) Save the compact numerical summary and the full result bundle.
    metadata = struct();
    metadata.sampleRange = sampleRange;
    metadata.Fs = cfg.Fs;
    metadata.meanDc = mean(signal);
    metadata.signalName = 'combinedSignal';
    saveAnalysisResults(results, metadata, paths.resultsDir);

    % 7) Log final status summary.
    fprintf(fid, '\nFinal mission status:\n');
    fieldNames = fieldnames(missionStatus);
    for i = 1:numel(fieldNames)
        fprintf(fid, '  %s : %d\n', fieldNames{i}, missionStatus.(fieldNames{i}));
    end
    fclose(fid);

    % 8) Save final numerical results.
    saveFinalResults(paths.finalResultsPath, results, missionStatus, flags);

    fprintf('Completed project mission set.\n');
    fprintf('Results and log stored in: %s\n', paths.resultsDir);
    fprintf('Final summary saved to: %s\n', paths.finalResultsPath);
end

function generateSignalMission(configPath, matPath)
%GENERATESIGNALMISSION Thin wrapper to keep main.m orchestration-only.
    [~, ~] = generateSyntheticAccelSignal(configPath, matPath);
end


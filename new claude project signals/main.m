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
    % The cleanup object also runs when generation, loading or saving throws.
    % Keep the log open until all saves and the final status report finish.
    logCleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

    fprintf(fid, 'Project run started at %s\n', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
    missionStatus = struct();
    results = struct();

    % 3) Generate or load signal.
    if RUN_GENERATION
        [missionStatus.generation, results.generation] = runMission(fid, 'Generate signal', @() ...
            generateSyntheticAccelSignal(paths.configPath, paths.signalMatPath));

        if missionStatus.generation
            loaded = load(paths.signalMatPath);
            data = loaded.(DEFINE().MAT_ROOT_VARNAME);
            signal = data.combinedSignal(:);
            time = (0:numel(signal)-1)' / data.Fs;
            sampleRange = [1, numel(signal)];
            cfg = data.Config;
            results.generation = struct('signal', signal, 'time', time, 'Fs', data.Fs, 'sampleRange', sampleRange, 'cfg', cfg);
        else
            error('main:signalGenerationFailed', 'Signal generation failed; mission set cannot continue without signal data.');
        end
    else
        % TODO: add optional load-from-mat workflow once non-synthetic data use is required.
        error('main:generationDisabled', 'Generation is currently required for this orchestrator.');
    end

    % 4) Define the sample range for analysis use.
    %    Inclusive, one-based endpoints; analyses reject invalid ranges.
    sampleRange = [1, numel(signal)];

    % 5) Run enabled missions independently.
    if RUN_TIME_PLOT
        [missionStatus.timePlot, resultTmp] = runMission(fid, 'Signal vs time plot', @() ...
            plotSignalVsTime(data, paths.resultsDir));
        results.timePlot = resultTmp;
    end

    if RUN_HISTOGRAMS
        [missionStatus.histograms, resultTmp] = runMission(fid, 'Histogram plot', @() ...
            plotHistogram(data, paths.resultsDir));
        results.histograms = resultTmp;
    end

    if RUN_MOMENTS
        momentsOptions = struct();
        momentsOptions.outputFolder = paths.resultsDir;
        momentsOptions.windowLengths = round(DEFINE().WM_WINDOW_SIZES_SEC * cfg.Fs);
        momentsOptions.windowLengths = momentsOptions.windowLengths(momentsOptions.windowLengths >= 8);
        momentsOptions.savePng = DEFINE().SAVE_PNG_FILES;
        momentsOptions.saveFig = DEFINE().SAVE_FIG_FILES;
        momentsOptions.plotTitle = 'Windowed moments';

        [missionStatus.windowedMoments, resultTmp] = runMission(fid, 'Windowed moments', @() ...
            analyzeWindowedMoments(signal, sampleRange, cfg.Fs, momentsOptions));
        results.windowedMoments = resultTmp;
    end

    if RUN_FFT
        [missionStatus.fft, resultTmp] = runMission(fid, 'FFT', @() ...
            analyzeAccelFFT(signal, sampleRange, cfg.Fs, 'combinedSignal', paths.resultsDir, 'm/s^2', true, true));
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
    metadata.meanDc = mean(signal(sampleRange(1):sampleRange(2)));
    metadata.signalName = 'combinedSignal';
    % Failure to write a readable summary must not discard successful
    % numerical missions. Attempt the final MAT bundle independently.
    try
        saveAnalysisResults(results, metadata, paths.resultsDir);
        missionStatus.saveAnalysis = true;
    catch ME
        missionStatus.saveAnalysis = false;
        fprintf(2, 'FAILURE: Save analysis summary - %s\n', ME.message);
        fprintf(fid, 'FAILURE: Save analysis summary\n%s\n', getReport(ME, 'extended', 'hyperlinks', 'off'));
    end

    try
        saveFinalResults(paths.finalResultsPath, results, missionStatus, flags);
    catch ME
        fprintf(2, 'FAILURE: Save final results - %s\n', ME.message);
        fprintf(fid, 'FAILURE: Save final results\n%s\n', getReport(ME, 'extended', 'hyperlinks', 'off'));
        rethrow(ME);
    end

    % 7) Log final status summary.
    fprintf(fid, '\nFinal mission status:\n');
    fieldNames = fieldnames(missionStatus);
    for i = 1:numel(fieldNames)
        fprintf(fid, '  %s : %d\n', fieldNames{i}, missionStatus.(fieldNames{i}));
    end
    failed = fieldNames(~structfun(@(passed) passed, missionStatus));
    if isempty(failed)
        fprintf('Completed: all %d enabled missions/save checks passed.\n', numel(fieldNames));
    else
        fprintf(2, 'Completed with %d failure(s): %s. See mission_log.txt for details.\n', ...
            numel(failed), strjoin(failed, ', '));
    end
    fprintf('Results and log stored in: %s\n', paths.resultsDir);
    fprintf('Final summary saved to: %s\n', paths.finalResultsPath);
end


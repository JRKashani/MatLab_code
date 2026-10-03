function main()
%MAIN Orchestrator for the synthetic signal analysis project.
%   This entry point only sets up paths, loads/generates the signal,
%   defines the sample range, runs enabled missions, logs failures, and
%   saves final numerical results. It does not contain the main analysis
%   algorithms themselves.

    runTimer = tic;
    clc;
    close all;

    % Keep explicit and implicitly created figures in the shared tabbed
    % container. Restore the user's desktop default when this run finishes.
    previousWindowStyle = get(groot, 'DefaultFigureWindowStyle');
    figureStyleCleanup = onCleanup(@() set(groot, ...
        'DefaultFigureWindowStyle', previousWindowStyle)); 
    set(groot, 'DefaultFigureWindowStyle', 'docked');

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
    if ~exist(paths.figuresDir, 'dir')
        mkdir(paths.figuresDir);
    end

    % 2) Mission flags.
    RUN_GENERATION     = true;
    RUN_TIME_PLOT      = false;
    RUN_HISTOGRAMS     = false;
    RUN_MOMENTS        = false;
    RUN_FFT            = true;
    RUN_PERIODOGRAM    = true;
    RUN_WELCH          = true;
    RUN_VARIABLE_WELCH = true;
    RUN_BURG           = false;
    RUN_SNR            = false;
    RUN_VALIDATION     = true;

    flags = struct();
    flags.RUN_GENERATION = RUN_GENERATION;
    flags.RUN_TIME_PLOT = RUN_TIME_PLOT;
    flags.RUN_HISTOGRAMS = RUN_HISTOGRAMS;
    flags.RUN_MOMENTS = RUN_MOMENTS;
    flags.RUN_FFT = RUN_FFT;
    flags.RUN_PERIODOGRAM = RUN_PERIODOGRAM;
    flags.RUN_WELCH = RUN_WELCH;
    flags.RUN_VARIABLE_WELCH = RUN_VARIABLE_WELCH;
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
    missionSeconds = struct();

    % 3) Generate or load signal.
    if RUN_GENERATION
        [missionStatus.generation, results.generation, missionSeconds.generation] = runMission(fid, 'Generate signal', @() ...
            generateSyntheticAccelSignal(paths.configPath, paths.signalMatPath));

        if missionStatus.generation
            loadTimer = tic;
            loaded = load(paths.signalMatPath);
            data = loaded.(DEFINE().MAT_ROOT_VARNAME);
            signal = data.combinedSignal(:);
            time = (0:numel(signal)-1)' / data.Fs;
            sampleRange = [1, numel(signal)];
            cfg = data.Config;
            results.generation = struct('signal', signal, 'time', time, 'Fs', data.Fs, 'sampleRange', sampleRange, 'cfg', cfg);
            missionSeconds.loadSignal = toc(loadTimer);
            fprintf('SUCCESS: Load signal (%.3f s)\n', missionSeconds.loadSignal);
            fprintf(fid, 'SUCCESS: Load signal (%.3f s)\n', missionSeconds.loadSignal);
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
        [missionStatus.timePlot, resultTmp, missionSeconds.timePlot] = runMission(fid, 'Signal vs time plot', @() ...
            plotSignalVsTime(data, paths.figuresDir));
        results.timePlot = resultTmp;
    end

    if RUN_HISTOGRAMS
        [missionStatus.histograms, resultTmp, missionSeconds.histograms] = runMission(fid, 'Histogram plot', @() ...
            plotHistogram(data, paths.figuresDir));
        results.histograms = resultTmp;
    end

    if RUN_MOMENTS
        momentsOptions = struct();
        momentsOptions.outputFolder = paths.figuresDir;
        momentsOptions.windowLengths = round(DEFINE().WM_WINDOW_SIZES_SEC * cfg.Fs);
        momentsOptions.windowLengths = momentsOptions.windowLengths(momentsOptions.windowLengths >= 8);
        momentsOptions.savePng = DEFINE().SAVE_PNG_FILES;
        momentsOptions.saveFig = DEFINE().SAVE_FIG_FILES;
        momentsOptions.plotTitle = 'Windowed moments';
        % Calculate all three before plotting so matching moments share limits.
        momentsOptions.makePlots = false;

        [missionStatus.windowedMoments, resultTmp, missionSeconds.windowedMoments] = runMission(fid, 'Windowed moments', @() ...
            analyzeWindowedMoments(signal, sampleRange, cfg.Fs, momentsOptions));
        results.windowedMoments = resultTmp;
        [missionStatus.noiseMoments, results.noiseMoments, missionSeconds.noiseMoments] = runMission(fid, 'Pure noise moments', @() ...
            analyzeWindowedMoments(data.pureNoiseSignal, sampleRange, cfg.Fs, momentsOptions));
        [missionStatus.sineMoments, results.sineMoments, missionSeconds.sineMoments] = runMission(fid, 'Pure sine moments', @() ...
            analyzeWindowedMoments(data.pureSineSignal, sampleRange, cfg.Fs, momentsOptions));
        bundles = struct('windowedMoments', results.windowedMoments, ...
            'noiseMoments', results.noiseMoments, 'sineMoments', results.sineMoments);
        [missionStatus.momentPlots, plotted, missionSeconds.momentPlots] = runMission(fid, 'Moment comparison plots', @() ...
            plotMomentComparison(bundles, cfg.Fs, momentsOptions));
        if missionStatus.momentPlots
            names = fieldnames(plotted);
            for k = 1:numel(names)
                results.(names{k}) = plotted.(names{k});
            end
        end
    end

    if RUN_FFT
        [missionStatus.fft, resultTmp, missionSeconds.fft] = runMission(fid, 'FFT', @() ...
            analyzeAccelFFT(signal, sampleRange, cfg.Fs, 'combinedSignal', paths.figuresDir, 'm/s^2', true, true));
        results.fft = resultTmp;
    end

    if RUN_PERIODOGRAM
        [missionStatus.periodogram, resultTmp, missionSeconds.periodogram] = runMission(fid, 'Periodogram PSD', @() ...
            runPeriodogramPSD(signal, sampleRange, cfg.Fs, 'combinedSignal', paths.figuresDir));
        results.periodogram = resultTmp;
    end

    if RUN_WELCH
        [missionStatus.welch, resultTmp, missionSeconds.welch] = runMission(fid, 'Welch PSD', @() ...
            runWelchPSD(signal, sampleRange, cfg.Fs, 'combinedSignal', paths.figuresDir));
        results.welch = resultTmp;
    end

    if RUN_VARIABLE_WELCH
        fftForWelch = [];
        if isfield(results, 'fft'), fftForWelch = results.fft; end
        [missionStatus.variableWelch, results.variableWelch, missionSeconds.variableWelch] = ...
            runMission(fid, 'Variable-resolution Welch PSD', @() ...
            runVariableWelchPSD(signal, sampleRange, cfg.Fs, fftForWelch, 'combinedSignal', paths.figuresDir));
    end

    if RUN_BURG
        [missionStatus.burg, resultTmp, missionSeconds.burg] = runMission(fid, 'Burg PSD', @() ...
            runBurgPSD(signal, sampleRange, cfg.Fs, 'combinedSignal', paths.figuresDir));
        results.burg = resultTmp;
    end

    if RUN_SNR
        [missionStatus.snr, resultTmp, missionSeconds.snr] = runMission(fid, 'SNR', @() ...
            runSNRAnalysis(signal, sampleRange, cfg.Fs, 'combinedSignal', paths.figuresDir));
        results.snr = resultTmp;
    end

    if RUN_VALIDATION
        [missionStatus.validation, resultTmp, missionSeconds.validation] = runMission(fid, 'Validation', @() ...
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
    saveTimer = tic;
    try
        saveAnalysisResults(results, metadata, paths.figuresDir, paths.resultsDir);
        missionSeconds.saveAnalysis = toc(saveTimer);
        missionStatus.saveAnalysis = true;
        fprintf('SUCCESS: Save analysis summary (%.3f s)\n', missionSeconds.saveAnalysis);
        fprintf(fid, 'SUCCESS: Save analysis summary (%.3f s)\n', missionSeconds.saveAnalysis);
    catch ME
        missionSeconds.saveAnalysis = toc(saveTimer);
        missionStatus.saveAnalysis = false;
        fprintf(2, 'FAILURE: Save analysis summary (%.3f s) - %s\n', missionSeconds.saveAnalysis, ME.message);
        fprintf(fid, 'FAILURE: Save analysis summary (%.3f s)\n%s\n', missionSeconds.saveAnalysis, getReport(ME, 'extended', 'hyperlinks', 'off'));
    end

    saveTimer = tic;
    try
        saveFinalResults(paths.finalResultsPath, results, missionStatus, flags);
        missionSeconds.saveFinal = toc(saveTimer);
        fprintf('SUCCESS: Save final results (%.3f s)\n', missionSeconds.saveFinal);
        fprintf(fid, 'SUCCESS: Save final results (%.3f s)\n', missionSeconds.saveFinal);
    catch ME
        missionSeconds.saveFinal = toc(saveTimer);
        fprintf(2, 'FAILURE: Save final results (%.3f s) - %s\n', missionSeconds.saveFinal, ME.message);
        fprintf(fid, 'FAILURE: Save final results (%.3f s)\n%s\n', missionSeconds.saveFinal, getReport(ME, 'extended', 'hyperlinks', 'off'));
        rethrow(ME);
    end

    % Total includes setup, loading and saves, before timing-report persistence.
    missionSeconds.total = toc(runTimer);
    [missionStatus.saveTimings, ~] = runMission(fid, 'Save timing summary', @() ...
        saveTimingSummary(missionSeconds, paths.resultsDir, missionStatus.saveAnalysis, paths.figuresDir));

    % 7) Log final status summary.
    fprintf(fid, '\nFinal mission status:\n');
    fieldNames = fieldnames(missionStatus);
    for i = 1:numel(fieldNames)
        name = fieldNames{i};
        fprintf(fid, '  %s : %d\n', name, missionStatus.(name));
    end
    fprintf('Total run time before timing report: %.3f s\n', missionSeconds.total);
    fprintf(fid, 'Total run time before timing report: %.3f s\n', missionSeconds.total);
    failed = fieldNames(~structfun(@(passed) passed, missionStatus));
    if isempty(failed)
        fprintf('Completed: all %d enabled missions/save checks passed.\n', numel(fieldNames));
    else
        fprintf(2, 'Completed with %d failure(s): %s. See mission_log.txt for details.\n', ...
            numel(failed), strjoin(failed, ', '));
    end
    fprintf('Reports and log stored in: %s\n', paths.resultsDir);
    fprintf('Final summary saved to: %s\n', paths.finalResultsPath);
end

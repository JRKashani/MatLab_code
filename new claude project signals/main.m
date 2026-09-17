function main()
%MAIN Generate a synthetic acceleration signal and run the independent
%     analysis tasks requested for the project:
%       1) signal generation
%       2) windowed moments
%       3) FFT
%       4) Welch PSD
%       5) periodogram
%       6) Burg PSD
%
% This script is intentionally organized so each mission is a separate
% plotting routine that uses the same generated input, but does not rely on
% the others for its internal calculations.

    clc;
    close all;

    scriptDir = fileparts(mfilename('fullpath'));
    if isempty(scriptDir)
        scriptDir = pwd;
    end

    resultDir = fullfile(scriptDir, 'results');
    if ~exist(resultDir, 'dir')
        mkdir(resultDir);
    end

    logFile = fullfile(resultDir, 'mission_log.txt');
    fid = fopen(logFile, 'w');
    if fid == -1
        error('main:cannotWriteLog', 'Could not open mission log at %s.', logFile);
    end

    missionStatus = struct();
    configPath = fullfile(scriptDir, 'example_config.txt');
    matPath = fullfile(resultDir, 'synthetic_accel_data.mat');

    fprintf(fid, 'Project run started at %s\n', datestr(now));

    missionStatus.generation = runMission(fid, 'Generate signal', @() generateSignalMission(configPath, matPath));
    if missionStatus.generation
        loaded = load(matPath);
        signalData = loaded.(DEFINE().MAT_ROOT_VARNAME);
        signal = signalData.combinedSignal(:);
        time = (0:numel(signal)-1)' / signalData.Fs;
        cfg = signalData.Config;
    else
        error('main:signalGenerationFailed', 'Signal generation failed; analysis missions cannot continue.');
    end

    missionStatus.windowedMoments = runMission(fid, 'Windowed moments', @() ...
        plotWindowedMoments(time, signal, computeWindowedMoments(signal, max(64, round(0.25 * cfg.Fs)), cfg.Fs), fullfile(resultDir, 'windowed_moments.png')));

    missionStatus.fft = runMission(fid, 'FFT', @() ...
        plotFFTAnalysis(signal, cfg.Fs, 'combinedSignal', fullfile(resultDir, 'fft.png')));

    missionStatus.welch = runMission(fid, 'Welch PSD', @() ...
        plotWelchPSD(signal, cfg.Fs, 'combinedSignal', fullfile(resultDir, 'welch_psd.png')));

    missionStatus.periodogram = runMission(fid, 'Periodogram', @() ...
        plotPeriodogram(signal, cfg.Fs, 'combinedSignal', fullfile(resultDir, 'periodogram.png')));

    missionStatus.burg = runMission(fid, 'Burg PSD', @() ...
        plotBurgPSD(signal, cfg.Fs, 'combinedSignal', fullfile(resultDir, 'burg_psd.png')));

    save(fullfile(resultDir, 'mission_status.mat'), 'missionStatus');
    fprintf(fid, '\nFinal mission status:\n');
    fprintf(fid, '  generation      : %d\n', missionStatus.generation);
    fprintf(fid, '  windowedMoments : %d\n', missionStatus.windowedMoments);
    fprintf(fid, '  fft             : %d\n', missionStatus.fft);
    fprintf(fid, '  welch           : %d\n', missionStatus.welch);
    fprintf(fid, '  periodogram     : %d\n', missionStatus.periodogram);
    fprintf(fid, '  burg            : %d\n', missionStatus.burg);
    fclose(fid);

    fprintf('Generated signal and completed the project mission set.\n');
    fprintf('Results and status log stored in: %s\n', resultDir);
end

function status = runMission(fid, missionName, missionFn)
    status = false;
    try
        missionFn();
        status = true;
        fprintf(fid, 'SUCCESS: %s\n', missionName);
    catch ME
        fprintf(fid, 'FAILURE: %s\n%s\n', missionName, getReport(ME));
    end
end

function generateSignalMission(configPath, matPath)
    [~, ~] = generateSyntheticAccelSignal(configPath, matPath);
end

function stats = computeWindowedMoments(signal, windowLength, Fs)
%COMPUTEWINDOWEDMOMENTS Compute sliding-window moment estimates for the input.
%   The output is intentionally independent from the FFT / Welch / Burg
%   routines and only depends on the raw signal samples.

    signal = signal(:);
    N = numel(signal);
    halfWindow = floor(windowLength / 2);

    stats.mean = zeros(N, 1);
    stats.variance = zeros(N, 1);
    stats.skewness = zeros(N, 1);
    stats.kurtosis = zeros(N, 1);
    stats.time = (0:N-1)' / Fs;

    for k = 1:N
        startIndex = max(1, k - halfWindow);
        endIndex = min(N, k + halfWindow);
        windowData = signal(startIndex:endIndex);

        mu = mean(windowData);
        centered = windowData - mu;
        sigma2 = mean(centered.^2);
        sigma = sqrt(max(sigma2, eps));

        stats.mean(k) = mu;
        stats.variance(k) = sigma2;
        stats.skewness(k) = mean(centered.^3) / (sigma^3 + eps);
        stats.kurtosis(k) = mean(centered.^4) / (sigma^4 + eps) - 3;
    end
end

function plotWindowedMoments(time, signal, momentStats, outputPath)
%PLOTWINDOWEDMOMENTS Plot the original signal and its sliding-window moments.

    fig = figure('Name', 'Windowed moments');
    tiledlayout(fig, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

    nexttile;
    plot(time, signal, 'b');
    title('Signal');
    xlabel('Time [s]');
    ylabel('Amplitude');
    grid on;

    nexttile;
    plot(time, momentStats.mean, 'r');
    title('Sliding-window mean');
    xlabel('Time [s]');
    ylabel('Mean');
    grid on;

    nexttile;
    yyaxis left;
    plot(time, momentStats.variance, 'g');
    ylabel('Variance');
    yyaxis right;
    plot(time, momentStats.kurtosis, 'm');
    ylabel('Kurtosis');
    title('Sliding-window variance and kurtosis');
    xlabel('Time [s]');
    grid on;

    drawnow;
    exportgraphics(fig, outputPath, 'Resolution', 300);
end

function plotFFTAnalysis(signal, Fs, signalName, outputPath)
%PLOTFFTANALYSIS Compute and plot the FFT magnitude spectrum.

    x = signal(:) - mean(signal(:));
    N = numel(x);
    Y = fft(x);
    f = (0:floor(N/2)) * Fs / N;
    amplitude = abs(Y(1:floor(N/2)+1)) / N;
    amplitude(2:end-1) = 2 * amplitude(2:end-1);

    fig = figure('Name', ['FFT - ' signalName]);
    plot(f, amplitude, 'LineWidth', 1.5);
    title(['FFT magnitude spectrum: ' signalName]);
    xlabel('Frequency [Hz]');
    ylabel('|X(f)|');
    grid on;
    xlim([0, min(Fs/2, max(f))]);

    drawnow;
    exportgraphics(fig, outputPath, 'Resolution', 300);
end

function plotWelchPSD(signal, Fs, signalName, outputPath)
%PLOTWELCHPSD Compute and plot the Welch PSD estimate without toolbox calls.

    x = signal(:) - mean(signal(:));
    n = numel(x);
    segmentLength = min(1024, n);
    overlap = floor(0.5 * segmentLength);
    step = segmentLength - overlap;
    if step <= 0
        step = segmentLength;
    end

    window = hannWindow(segmentLength);
    nfft = max(1024, 2^nextpow2(segmentLength));
    [psd, f] = computeWelchPSD(x, Fs, segmentLength, overlap, window, nfft);

    fig = figure('Name', ['Welch PSD - ' signalName]);
    plot(f, 10 * log10(psd + eps), 'LineWidth', 1.5);
    title(['Welch PSD: ' signalName]);
    xlabel('Frequency [Hz]');
    ylabel('Power spectral density [dB/Hz]');
    grid on;
    xlim([0, Fs/2]);

    drawnow;
    exportgraphics(fig, outputPath, 'Resolution', 300);
end

function [psd, f] = computeWelchPSD(x, Fs, segmentLength, overlap, window, nfft)
    x = x(:);
    n = numel(x);
    step = segmentLength - overlap;
    numSegments = max(1, floor((n - overlap) / step));
    psdSum = zeros(nfft, 1);

    for k = 1:numSegments
        startIdx = 1 + (k - 1) * step;
        endIdx = startIdx + segmentLength - 1;
        if endIdx > n
            break;
        end
        seg = x(startIdx:endIdx) .* window;
        segSpectrum = abs(fft(seg, nfft)).^2;
        segPSD = segSpectrum(1:ceil(nfft/2)+1) / (Fs * sum(window.^2));
        segPSD(2:end-1) = 2 * segPSD(2:end-1);
        psdSum = psdSum + segPSD;
    end

    psd = psdSum / numSegments;
    f = (0:floor(numel(psd)-1)) * Fs / nfft;
end

function plotPeriodogram(signal, Fs, signalName, outputPath)
%PLOTPERIODOGRAM Compute and plot the standard periodogram without toolbox calls.

    x = signal(:) - mean(signal(:));
    nfft = max(1024, 2^nextpow2(numel(x)));
    window = hannWindow(numel(x));
    [psd, f] = computePeriodogramPSD(x, Fs, window, nfft);

    fig = figure('Name', ['Periodogram - ' signalName]);
    plot(f, 10 * log10(psd + eps), 'LineWidth', 1.5);
    title(['Periodogram: ' signalName]);
    xlabel('Frequency [Hz]');
    ylabel('Power spectral density [dB/Hz]');
    grid on;
    xlim([0, Fs/2]);

    drawnow;
    exportgraphics(fig, outputPath, 'Resolution', 300);
end

function [psd, f] = computePeriodogramPSD(x, Fs, window, nfft)
    x = x(:);
    xw = x .* window;
    spectrum = abs(fft(xw, nfft)).^2;
    psd = spectrum(1:ceil(nfft/2)+1) / (Fs * sum(window.^2));
    psd(2:end-1) = 2 * psd(2:end-1);
    f = (0:floor(numel(psd)-1)) * Fs / nfft;
end

function plotBurgPSD(signal, Fs, signalName, outputPath)
%PLOTBURGPSD Compute and plot an AR-based Burg-style PSD estimate without toolbox calls.

    x = signal(:) - mean(signal(:));
    order = min(40, max(4, floor(numel(x) / 20)));
    nfft = max(1024, 2^nextpow2(numel(x)));
    [psd, f] = computeBurgPSD(x, Fs, order, nfft);

    fig = figure('Name', ['Burg PSD - ' signalName]);
    plot(f, 10 * log10(psd + eps), 'LineWidth', 1.5);
    title(['Burg PSD: ' signalName]);
    xlabel('Frequency [Hz]');
    ylabel('Power spectral density [dB/Hz]');
    grid on;
    xlim([0, Fs/2]);

    drawnow;
    exportgraphics(fig, outputPath, 'Resolution', 300);
end

function [psd, f] = computeBurgPSD(x, Fs, order, nfft)
    x = x(:);
    N = numel(x);
    if N <= order
        order = max(1, N - 1);
    end

    r = xcorr(x, order, 'biased');
    r = r(order + 1:end);
    r0 = r(1);
    if r0 <= 0
        psd = zeros(nfft/2 + 1, 1);
        f = (0:nfft/2).' * Fs / nfft;
        return;
    end

    arCoeffs = levinsonDurbin(r, order);
    freqs = (0:nfft/2).' * Fs / nfft;
    omega = 2 * pi * freqs / Fs;
    phaseMatrix = exp(-1i * (1:order).' * omega);
    denom = 1 + phaseMatrix * arCoeffs;
    psd = (r0 ./ abs(denom).^2) / Fs;
    f = freqs;
end

function a = levinsonDurbin(r, order)
    if order <= 0
        a = [];
        return;
    end

    n = numel(r);
    if n < order + 1
        order = n - 1;
    end
    if order <= 0
        a = [];
        return;
    end

    a = zeros(order, 1);
    a(1) = -r(2) / r(1);
    if order == 1
        return;
    end

    for m = 1:order-1
        if abs(r(m + 1)) < eps
            break;
        end
        gamma = -r(m + 2);
        for k = 1:m
            gamma = gamma + r(k + 1) * a(k);
        end
        if abs(gamma) < eps
            break;
        end
        a_new = zeros(m + 1, 1);
        a_new(1:m) = a(1:m) + gamma * flipud(a(1:m));
        a_new(m + 1) = gamma;
        a = a_new;
    end
end

function w = hannWindow(N)
    if N <= 0
        w = [];
        return;
    end
    n = 0:N-1;
    w = 0.5 - 0.5 * cos(2 * pi * n / (N - 1));
    if N == 1
        w = 1;
    end
end

function result = computeWindowedMoments(signal, windowLength, Fs, outputFolder)
%COMPUTEWINDOWEDMOMENTS Compute sliding-window moment estimates for the input.
%   This file was moved out of main.m to keep the entry point orchestration-only.
%   The mathematics are unchanged; this is a structural extraction only.

    if nargin < 4 || isempty(outputFolder)
        outputFolder = fullfile(pwd, 'results');
    end

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

    result = struct();
    result.stats = stats;
    result.outputFolder = outputFolder;
    result.windowLength = windowLength;
    result.Fs = Fs;

    % TODO: extract this into a dedicated plotting routine when the moments
    % file is fully modularized.
    fig = figure('Name', 'Windowed moments');
    tiledlayout(fig, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

    nexttile;
    plot(stats.time, signal, 'b');
    title('Signal');
    xlabel('Time [s]');
    ylabel('Amplitude');
    grid on;

    nexttile;
    plot(stats.time, stats.mean, 'r');
    title('Sliding-window mean');
    xlabel('Time [s]');
    ylabel('Mean');
    grid on;

    nexttile;
    yyaxis left;
    plot(stats.time, stats.variance, 'g');
    ylabel('Variance');
    yyaxis right;
    plot(stats.time, stats.kurtosis, 'm');
    ylabel('Kurtosis');
    title('Sliding-window variance and kurtosis');
    xlabel('Time [s]');
    grid on;

    drawnow;
    if ~exist(outputFolder, 'dir')
        mkdir(outputFolder);
    end
    exportgraphics(fig, fullfile(outputFolder, 'windowed_moments.png'), 'Resolution', 300);
end

function result = runWelchPSD(signal, sampleRange, Fs, signalName, outputFolder)
%RUNWELCHPSD Thin wrapper for a Welch-style PSD routine.
%   TODO: separate algorithm and plotting responsibilities once the PSD folder
%   is fully expanded.

    if nargin < 5 || isempty(outputFolder)
        outputFolder = fullfile(pwd, 'results');
    end
    if nargin < 4 || isempty(signalName)
        signalName = 'signal';
    end

    x = signal(:) - mean(signal(:));
    n = numel(x);
    segmentLength = min(1024, n);
    overlap = floor(0.5 * segmentLength);
    if overlap <= 0
        overlap = 0;
    end
    window = hannWindowManual(segmentLength);
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
    if ~exist(outputFolder, 'dir')
        mkdir(outputFolder);
    end
    exportgraphics(fig, fullfile(outputFolder, 'welch_psd.png'), 'Resolution', 300);

    result = struct();
    result.f = f;
    result.psd = psd;
    result.outputFile = fullfile(outputFolder, 'welch_psd.png');
end

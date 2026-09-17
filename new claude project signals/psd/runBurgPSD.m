function result = runBurgPSD(signal, sampleRange, Fs, signalName, outputFolder)
%RUNBURGPSD Thin wrapper for a Burg-style AR PSD estimate.
%   TODO: move the algorithm and plotting into a dedicated PSD file with a
%   more expressive options struct.

    if nargin < 5 || isempty(outputFolder)
        outputFolder = fullfile(pwd, 'results');
    end
    if nargin < 4 || isempty(signalName)
        signalName = 'signal';
    end

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
    if ~exist(outputFolder, 'dir')
        mkdir(outputFolder);
    end
    exportgraphics(fig, fullfile(outputFolder, 'burg_psd.png'), 'Resolution', 300);

    result = struct();
    result.f = f;
    result.psd = psd;
    result.outputFile = fullfile(outputFolder, 'burg_psd.png');
end

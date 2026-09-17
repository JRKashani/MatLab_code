function result = runPeriodogramPSD(signal, sampleRange, Fs, signalName, outputFolder)
%RUNPERIODOGRAMPSD Thin wrapper around the existing periodogram-based PSD logic.
%   TODO: move this to a dedicated PSD module with explicit options struct.

    if nargin < 5 || isempty(outputFolder)
        outputFolder = fullfile(pwd, 'results');
    end
    if nargin < 4 || isempty(signalName)
        signalName = 'signal';
    end

    x = signal(:) - mean(signal(:));
    nfft = max(1024, 2^nextpow2(numel(x)));
    window = hannWindowManual(numel(x));
    [psd, f] = computePeriodogramPSD(x, Fs, window, nfft);

    fig = figure('Name', ['Periodogram - ' signalName]);
    plot(f, 10 * log10(psd + eps), 'LineWidth', 1.5);
    title(['Periodogram: ' signalName]);
    xlabel('Frequency [Hz]');
    ylabel('Power spectral density [dB/Hz]');
    grid on;
    xlim([0, Fs/2]);

    drawnow;
    if ~exist(outputFolder, 'dir')
        mkdir(outputFolder);
    end
    exportgraphics(fig, fullfile(outputFolder, 'periodogram.png'), 'Resolution', 300);

    result = struct();
    result.f = f;
    result.psd = psd;
    result.outputFile = fullfile(outputFolder, 'periodogram.png');
end

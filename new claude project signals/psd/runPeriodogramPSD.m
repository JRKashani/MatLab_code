function result = runPeriodogramPSD(signal, sampleRange, Fs, signalName, outputFolder)
%RUNPERIODOGRAMPSD Hann-windowed PSD of the inclusive sampleRange.
%   Remove the selected segment's mean before estimating spectral power.
%   Returned PSD units are signal-units squared per Hz; integrate over Hz
%   to obtain mean-square power. NFFT padding refines the displayed grid.

    if nargin < 5 || isempty(outputFolder)
        outputFolder = fullfile(pwd, 'results');
    end
    if nargin < 4 || isempty(signalName)
        signalName = 'signal';
    end

    % A symmetric Hann window needs at least three samples for nonzero power.
    [x, sampleRange] = selectSignalSegment(signal, sampleRange, Fs, 3);
    meanRemoved = mean(x);
    x = x - meanRemoved;
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
    result.sampleRange = sampleRange;
    result.sampleCount = numel(x);
    result.Fs = Fs;
    result.meanRemoved = meanRemoved;
    result.outputFile = fullfile(outputFolder, 'periodogram.png');
end

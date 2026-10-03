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
    % MATLAB alternative (Signal Processing Toolbox):
    % windowMatlab = hann(numel(x), 'symmetric');
    [psd, f] = computePeriodogramPSD(x, Fs, window, nfft);
    % [psdMatlab, fMatlab] = periodogram(x, window, nfft, Fs, 'onesided');
    % Area under the displayed PSD, using the actual frequency coordinates.
    integratedPower = trapz(f, psd);

    fig = figure('Name', ['Periodogram - ' signalName], 'WindowStyle', 'docked');
    plot(f, psd, 'LineWidth', 1.5);
    title(['Periodogram: ' signalName]);
    subtitle(sprintf('PSD integral: %.6g [m^2/s^4]', integratedPower));
    xlabel('Frequency [Hz]');
    ylabel('Power spectral density [m^2/s^4/Hz]');
    set(gca, 'YScale', 'linear');
    grid on;
    xlim([0, Fs/2]);
    peaks = markPSDPeaks(gca, f, psd);

    drawnow;
    if ~exist(outputFolder, 'dir')
        mkdir(outputFolder);
    end
    exportgraphics(fig, fullfile(outputFolder, 'periodogram.png'), 'Resolution', 300);

    result = struct();
    result.f = f;
    result.psd = psd;
    result.integratedPower = integratedPower;
    result.peaks = peaks;
    result.sampleRange = sampleRange;
    result.sampleCount = numel(x);
    result.Fs = Fs;
    result.meanRemoved = meanRemoved;
    result.outputFile = fullfile(outputFolder, 'periodogram.png');
end

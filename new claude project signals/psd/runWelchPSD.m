function result = runWelchPSD(signal, sampleRange, Fs, signalName, outputFolder)
%RUNWELCHPSD Four window lengths and four overlaps in two comparison figures.
%   Hann windows; window comparison holds requested overlap at 67 percent.
%   Overlap comparison holds length at min(1024, selected sample count).
%   Resolution labels report Fs/windowLength, not the zero-padded bin grid.
%   f/psd retain the default 1024-sample, 50-percent-overlap result.

    if nargin < 5 || isempty(outputFolder)
        outputFolder = fullfile(pwd, 'figures');
    end
    if nargin < 4 || isempty(signalName), signalName = 'signal'; end
    [x, sampleRange] = selectSignalSegment(signal, sampleRange, Fs, 8);
    meanRemoved = mean(x);
    x = x - meanRemoved;
    n = numel(x);
    lengths = [256 1024 4096 16384];
    % Short records still get four distinct valid window lengths.
    if n < lengths(end)
        lengths = round(logspace(log10(3), log10(n), 4));
    end
    overlaps = [0 0.25 0.5 0.75];
    windowComparisonOverlap = 0.67;
    defaultLength = min(1024, n);
    windowCurves = calculateCurve(x, Fs, lengths(1), windowComparisonOverlap);
    overlapCurves = calculateCurve(x, Fs, defaultLength, overlaps(1));
    for k = 2:4
        windowCurves(k) = calculateCurve(x, Fs, lengths(k), windowComparisonOverlap);
        overlapCurves(k) = calculateCurve(x, Fs, defaultLength, overlaps(k));
    end

    figures = gobjects(1, 2);
    figures(1) = figure('Name', ['Welch window lengths - ' signalName], 'WindowStyle', 'docked');
    ax = axes('Parent', figures(1));
    hold(ax, 'on');
    for k = 1:4
        c = windowCurves(k);
        plot(ax, c.f, c.psd, 'LineWidth', 1.2, ...
            'DisplayName', sprintf('%d samples (%.4g [s]), resolution %.4g [Hz]', ...
            c.segmentLength, c.segmentLength/Fs, c.frequencyResolutionHz));
        addPSDIntegralLegendEntry(ax, c.integratedPower, sprintf('%d-sample window', c.segmentLength));
    end
    title(ax, ['Welch PSD window length comparison: ' signalName], 'Interpreter', 'none');
    subtitle(ax, sprintf('Hann window | %.0f%% requested overlap | resolution = Fs / window length', ...
        100*windowComparisonOverlap));
    finishAxes(ax, Fs);

    figures(2) = figure('Name', ['Welch overlap - ' signalName], 'WindowStyle', 'docked');
    ax = axes('Parent', figures(2));
    hold(ax, 'on');
    for k = 1:4
        c = overlapCurves(k);
        plot(ax, c.f, c.psd, 'LineWidth', 1.2, ...
            'DisplayName', sprintf('%.3g%% overlap (%d samples), %d segments', ...
            100*c.actualOverlapFraction, c.overlapSamples, c.segmentCount));
        addPSDIntegralLegendEntry(ax, c.integratedPower, sprintf('%.3g%% overlap', 100*c.actualOverlapFraction));
    end
    title(ax, ['Welch PSD overlap comparison: ' signalName], 'Interpreter', 'none');
    subtitle(ax, sprintf('Hann | %d samples (%.4g [s]) | resolution %.4g [Hz] (Fs / window length)', ...
        defaultLength, defaultLength/Fs, Fs/defaultLength));
    finishAxes(ax, Fs);

    D = DEFINE();
    files = {};
    if D.SAVE_PNG_FILES || D.SAVE_FIG_FILES
        if ~exist(outputFolder, 'dir'), mkdir(outputFolder); end
        bases = {'welch_window_sizes', 'welch_overlap'};
        for k = 1:2
            base = fullfile(outputFolder, bases{k});
            if D.SAVE_PNG_FILES
                files{end+1} = [base '.png']; %#ok<AGROW>
                exportgraphics(figures(k), files{end}, 'Resolution', 300);
            end
            if D.SAVE_FIG_FILES
                files{end+1} = [base '.fig']; %#ok<AGROW>
                savefig(figures(k), files{end});
            end
        end
    end
    primary = overlapCurves(3);
    result = struct('f', primary.f, 'psd', primary.psd, 'sampleRange', sampleRange, ...
        'sampleCount', n, 'Fs', Fs, 'meanRemoved', meanRemoved, ...
        'windowComparison', windowCurves, 'overlapComparison', overlapCurves, ...
        'figureHandle', figures, 'files', {files}, ...
        'windows', {{'Hann'}}, 'segmentSecondsList', lengths/Fs, ...
        'windowLengths', lengths, 'overlapFractions', overlaps, ...
        'frequencyResolutionHz', Fs/defaultLength, 'integratedPower', primary.integratedPower);
end

function curve = calculateCurve(x, Fs, lengthSamples, fraction)
    overlap = floor(fraction * lengthSamples);
    nfft = max(1024, 2^nextpow2(lengthSamples));
    [p, f] = computeWelchPSD(x, Fs, lengthSamples, overlap, ...
        hannWindowManual(lengthSamples), nfft);
    % MATLAB alternative (Signal Processing Toolbox), same window/overlap:
    % [pMatlab, fMatlab] = pwelch(x, hann(lengthSamples, 'symmetric'), overlap, nfft, Fs, 'onesided');
    count = floor((numel(x)-lengthSamples)/(lengthSamples-overlap)) + 1;
    curve = struct('f', f, 'psd', p, 'segmentLength', lengthSamples, ...
        'overlapSamples', overlap, 'requestedOverlapFraction', fraction, ...
        'actualOverlapFraction', overlap/lengthSamples, 'segmentCount', count, ...
        'nfft', nfft, 'frequencyResolutionHz', Fs/lengthSamples, 'binSpacingHz', Fs/nfft, ...
        'integratedPower', trapz(f, p));
end

function finishAxes(ax, Fs)
    hold(ax, 'off');
    xlabel(ax, 'Frequency [Hz]');
    ylabel(ax, 'Power spectral density [m^2/s^4/Hz]');
    set(ax, 'YScale', 'linear');
    grid(ax, 'on');
    xlim(ax, [0 Fs/2]);
    legend(ax, 'show', 'Location', 'best', 'Interpreter', 'none');
end

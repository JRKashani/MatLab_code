function figHandle = plotSNRDiagnostic(result, options)
%PLOTSNRDIAGNOSTIC Build (and optionally save) the tonal-SNR diagnostic figure.
%
% figHandle = plotSNRDiagnostic(result, options)
%
% Inputs:
%   result  - the result struct returned by estimateTonalSNR
%   options - the options struct passed into estimateTonalSNR (uses
%             .SaveFig, .SavePng, .OutputFolder)
%
% Output:
%   figHandle - handle of the created figure
%
% Plots, on one frequency axis:
%   - the measured PSD (dB scale)
%   - the estimated local noise floor (dB scale)
%   - markers at each detected tonal peak frequency
%   - shaded bands showing each detected tonal region
% together with the overall SNR, iteration/convergence status, and (if
% available) the ground-truth comparison, so the automatic estimate can
% be visually sanity-checked rather than trusted as a bare number.

figHandle = figure('Name', 'Tonal SNR diagnostic', 'Color', 'w');
ax = axes(figHandle);
hold(ax, 'on');

freqHz = result.frequencyHz;
psdDb = 10*log10(max(result.measuredPSD, eps));
noiseDb = 10*log10(max(result.estimatedNoisePSD, eps));

numPeaks = numel(result.peakFrequenciesHz);

% Shade each detected tonal band first, so the PSD/noise-floor lines and
% peak markers are drawn on top and remain legible.
yLimsGuess = [min([psdDb; noiseDb]) - 3, max([psdDb; noiseDb]) + 3];
for p = 1:numPeaks
    band = result.peakBandsHz(p, :);
    xBox = [band(1), band(2), band(2), band(1)];
    yBox = [yLimsGuess(1), yLimsGuess(1), yLimsGuess(2), yLimsGuess(2)];
    patch(ax, xBox, yBox, [0.95 0.85 0.1], 'FaceAlpha', 0.15, ...
        'EdgeColor', 'none', 'HandleVisibility', 'off');
end

plot(ax, freqHz, psdDb, 'Color', [0 0.4470 0.7410], 'LineWidth', 1);
plot(ax, freqHz, noiseDb, 'Color', [0.8500 0.3250 0.0980], 'LineWidth', 1.5);
legendEntries = {'Measured PSD', 'Estimated noise floor'};

if numPeaks > 0
    peakPsdAtFreq = interp1(freqHz, result.measuredPSD, result.peakFrequenciesHz, 'linear', 'extrap');
    peakPsdDb = 10*log10(max(peakPsdAtFreq, eps));

    plot(ax, result.peakFrequenciesHz, peakPsdDb, 'v', ...
        'MarkerFaceColor', 'k', 'MarkerEdgeColor', 'k', 'MarkerSize', 6, ...
        'LineStyle', 'none');
    legendEntries{end+1} = 'Detected tones';

    if numPeaks <= 8
        for p = 1:numPeaks
            text(ax, result.peakFrequenciesHz(p), peakPsdDb(p) + 1.5, ...
                sprintf('%.1f dB', result.peakSNRdB(p)), 'FontSize', 8);
        end
    end
end

xlabel(ax, 'Frequency (Hz)');
ylabel(ax, 'PSD (dB re (units)^2/Hz)');
grid(ax, 'on');
ylim(ax, yLimsGuess);
legend(ax, legendEntries, 'Location', 'best');

if result.converged
    convergedStr = 'converged';
else
    convergedStr = 'NOT converged';
end

titleLines = { ...
    sprintf('%s | samples %d-%d', result.signalName, result.sampleRange(1), result.sampleRange(2)), ...
    sprintf('Overall SNR = %.2f dB | %d tone(s) detected | iterations = %d (%s)', ...
        result.overallSNRdB, numPeaks, result.iterationCount, convergedStr) };

if result.groundTruth.available
    titleLines{end+1} = sprintf('Ground truth SNR = %.2f dB | estimation error = %.2f dB', ...
        result.groundTruth.SNRdB, result.groundTruth.estimatedErrorDb);
end

title(ax, titleLines, 'Interpreter', 'none');
hold(ax, 'off');

% ---- saving (independent flags, explicit filenames, no cd) ----------
if options.SaveFig || options.SavePng
    if ~exist(options.OutputFolder, 'dir')
        mkdir(options.OutputFolder);
    end

    baseName = sprintf('SNR_%s_samples_%d_%d', ...
        sanitizeFileName(result.signalName), result.sampleRange(1), result.sampleRange(2));

    if options.SaveFig
        savefig(figHandle, fullfile(options.OutputFolder, [baseName '.fig']));
    end
    if options.SavePng
        print(figHandle, fullfile(options.OutputFolder, [baseName '.png']), '-dpng', '-r150');
    end
end
end

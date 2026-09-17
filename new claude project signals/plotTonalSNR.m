function figHandle = plotTonalSNR(result, options)
%PLOTTONALSNR Diagnostic plot of measured PSD, estimated noise floor, and detected tones.
%
%   figHandle = PLOTTONALSNR(result, options)
%
%   Draws ONE diagnostic figure so the automatic tonal-SNR estimate can
%   be visually sanity-checked, rather than trusted as a bare number
%   (see the "Scientific limitations" note in estimateTonalSNR.m: the
%   detection/noise-floor parameters influence the numeric result, so
%   unfamiliar real data should always be inspected this way).
%
%   On a single frequency axis, in dB re 1 (signal unit)^2/Hz:
%       - measured PSD
%       - estimated noise-floor PSD
%       - detected tonal regions (shaded bands) with peak markers
%       - per-peak SNR labels (only if there are few enough peaks to
%         stay readable)
%   Plus a title block with: overall SNR, number of detected tones,
%   iteration count / convergence status, and (if available) the
%   ground-truth SNR and estimation error.
%
%   Inputs:
%       result  - the struct returned by estimateTonalSNR
%       options - struct with fields SignalName, OutputFolder, SaveFIG,
%                 SavePNG (matching the corresponding estimateTonalSNR
%                 name-value options)
%   Output:
%       figHandle - handle of the created figure

    figHandle = figure('Color', 'w');
    ax = axes('Parent', figHandle);

    PxxDB = 10*log10(max(result.measuredPSD, realmin));
    noiseDB = 10*log10(max(result.estimatedNoisePSD, realmin));

    plot(ax, result.frequencyHz, PxxDB, 'Color', [0.20 0.40 0.80], 'LineWidth', 1);
    hold(ax, 'on');
    plot(ax, result.frequencyHz, noiseDB, 'Color', [0.85 0.33 0.10], 'LineWidth', 1.5);
    legendEntries = {'Measured PSD', 'Estimated noise floor'};

    nPeaks = numel(result.peakFrequenciesHz);
    if nPeaks > 0
        peakDB = zeros(nPeaks, 1);
        for k = 1:nPeaks
            [~, idx] = min(abs(result.frequencyHz - result.peakFrequenciesHz(k)));
            peakDB(k) = PxxDB(idx);
        end

        plot(ax, result.peakFrequenciesHz, peakDB, 'v', ...
            'MarkerSize', 7, 'MarkerFaceColor', [0.10 0.60 0.20], 'MarkerEdgeColor', 'k');
        legendEntries{end+1} = 'Detected tone peaks'; %#ok<AGROW>

        yl = ylim(ax);
        for k = 1:size(result.peakBandsHz, 1)
            bandX = result.peakBandsHz(k, [1 2 2 1]);
            bandY = [yl(1) yl(1) yl(2) yl(2)];
            patch(ax, bandX, bandY, [0.10 0.60 0.20], ...
                'FaceAlpha', 0.08, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        end
        ylim(ax, yl);

        if nPeaks <= 12
            for k = 1:nPeaks
                text(ax, result.peakFrequenciesHz(k), peakDB(k) + 2, ...
                    sprintf('%.1f dB', result.peakSNRdB(k)), ...
                    'FontSize', 8, 'HorizontalAlignment', 'center');
            end
        end
    end

    xlabel(ax, 'Frequency (Hz)');
    ylabel(ax, 'PSD (dB re 1 (signal unit)^2/Hz)');
    grid(ax, 'on');
    legend(ax, legendEntries, 'Location', 'best');

    titleLines = {sprintf('%s -- samples %d:%d', options.SignalName, ...
        result.sampleRange(1), result.sampleRange(2))};

    if isfinite(result.overallSNRdB)
        titleLines{end+1} = sprintf('Overall estimated SNR = %.2f dB (%d tone(s) detected)', ...
            result.overallSNRdB, nPeaks);
    else
        titleLines{end+1} = 'No tones detected above threshold -- overall SNR undefined';
    end

    titleLines{end+1} = sprintf('Iterations: %d, converged: %s', ...
        result.iterationCount, mat2str(result.converged));

    if result.groundTruth.available
        titleLines{end+1} = sprintf('Ground-truth SNR = %.2f dB, error = %.2f dB', ...
            result.groundTruth.SNRdB, result.groundTruth.estimatedErrorDb);
    end

    title(ax, titleLines);
    hold(ax, 'off');

    if options.SaveFIG || options.SavePNG
        safeName = sanitizeFileName(options.SignalName);
        baseName = sprintf('SNR_%s_samples_%d_%d', safeName, ...
            result.sampleRange(1), result.sampleRange(2));

        if ~exist(options.OutputFolder, 'dir')
            mkdir(options.OutputFolder);
        end

        if options.SaveFIG
            savefig(figHandle, fullfile(options.OutputFolder, [baseName '.fig']));
        end
        if options.SavePNG
            print(figHandle, fullfile(options.OutputFolder, [baseName '.png']), '-dpng', '-r150');
        end
    end
end

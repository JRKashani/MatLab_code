function bundles = plotMomentComparison(bundles, Fs, options)
%PLOTMOMENTCOMPARISON Four moments for three signals with matching y limits.
%   Limits use all computed values and global references, before thinning.
    keys = {'windowedMoments', 'noiseMoments', 'sineMoments'};
    labels = {'Combined signal', 'Pure noise', 'Pure sine'};
    prefixes = {'windowed_', 'windowed_noise_', 'windowed_sine_'};
    moments = {'mean', 'rms', 'skewness', 'kurtosis'};
    limits = zeros(4, 2);
    for m = 1:4
        low = Inf; high = -Inf;
        for k = 1:3
            r = bundles.(keys{k});
            if isempty(r), continue; end
            values = r.globalMoments.(moments{m});
            values = values(isfinite(values));
            if ~isempty(values)
                low = min(low, min(values)); high = max(high, max(values));
            end
            for j = 1:numel(r.series)
                values = r.series(j).(moments{m});
                values = values(isfinite(values));
                if ~isempty(values)
                    low = min(low, min(values)); high = max(high, max(values));
                end
            end
        end
        if ~isfinite(low)
            limits(m, :) = [-1 1];
        else
            padding = 0.05 * (high-low);
            if padding == 0, padding = 0.05 * max(1, abs(low)); end
            limits(m, :) = [low-padding high+padding];
        end
    end
    plotOptions = struct('maxPlotPoints', DEFINE().MAX_PLOT_POINTS, ...
        'outputFolder', options.outputFolder, 'savePng', options.savePng, ...
        'saveFig', options.saveFig, 'yLimits', limits);
    for k = 1:3
        r = bundles.(keys{k});
        if isempty(r), continue; end
        plotOptions.plotTitle = ['Windowed moments - ' labels{k}];
        plotOptions.filePrefix = prefixes{k};
        [r.figureHandle, r.files] = plotWindowedMoments(r.series, r.globalMoments, ...
            r.radicalPoints, Fs, plotOptions);
        r.sharedYLimits = limits;
        bundles.(keys{k}) = r;
    end
end

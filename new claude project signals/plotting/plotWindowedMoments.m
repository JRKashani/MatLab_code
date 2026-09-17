function [figures, files] = plotWindowedMoments(series, globalMoments, radicalPoints, Fs, options)
%PLOTWINDOWEDMOMENTS One axes per figure, one figure per statistical moment.
%   Colors identify window sizes consistently across the four figures. The
%   dashed line is the global moment over the selected signal; colored circles
%   mark the greatest absolute departure for each window. A black diamond
%   emphasizes the greatest departure across all the displayed window sizes.
%   Thinning affects display only and always retains each radical point.
%   The legend below the axes reports abs(radical value - global value)
%   for each window; undefined statistics are explicitly labelled.

    names = {'mean', 'rms', 'skewness', 'kurtosis'};
    labels = {'Mean', 'RMS', 'Skewness', 'Excess kurtosis'};
    colors = lines(numel(series));
    figures = gobjects(1, numel(names));
    files = {};
    if options.savePng || options.saveFig
        if ~exist(options.outputFolder, 'dir'), mkdir(options.outputFolder); end
    end
    for m = 1:numel(names)
        name = names{m};
        label = labels{m};
        figures(m) = figure('Name', [options.plotTitle ' - ' label], ...
            'Color', 'w', 'Position', [100 100 1150 620]);
        ax = axes('Parent', figures(m));
        hold(ax, 'on');
        points = radicalPoints.(name);
        for i = 1:numel(series)
            values = series(i).(name);
            count = numel(values);
            % Reserve one display point for the actual extreme, which a
            % uniform plotting stride could otherwise skip completely.
            if count > options.maxPlotPoints
                budget = options.maxPlotPoints - double(points(i).defined);
                indices = unique(round(linspace(1, count, budget)));
                if points(i).defined
                    indices = unique([indices, points(i).seriesIndex]);
                end
            else
                indices = 1:count;
            end
            windowLabel = sprintf('%.4g s (%d samples)', series(i).windowLength / Fs, series(i).windowLength);
            if points(i).defined
                windowLabel = sprintf('%s, |rad - global| = %.5g', windowLabel, points(i).absoluteDeviation);
            else
                windowLabel = [windowLabel ', |rad - global| = undefined'];
            end
            plot(ax, series(i).time(indices), values(indices), ...
                'Color', colors(i, :), 'LineWidth', 1.1, 'Tag', 'momentCurve', ...
                'DisplayName', windowLabel);
            if points(i).defined
                plot(ax, points(i).time, points(i).value, 'o', 'Color', colors(i, :), ...
                    'MarkerFaceColor', colors(i, :), 'MarkerSize', 7, ...
                    'HandleVisibility', 'off', 'Tag', 'radicalPoint');
            end
        end

        reference = globalMoments.(name);
        if isfinite(reference)
            yline(ax, reference, '--k', 'LineWidth', 1.3, 'Tag', 'globalMoment', ...
                'DisplayName', sprintf('Global %s = %.5g', lower(label), reference));
        end
        defined = find([points.defined]);
        if ~isempty(defined)
            [~, position] = max([points(defined).absoluteDeviation]);
            largest = points(defined(position));
            plot(ax, largest.time, largest.value, 'kd', 'MarkerSize', 12, ...
                'LineWidth', 1.6, 'Tag', 'largestDeviation', 'DisplayName', 'Largest deviation');
            subtitle(ax, sprintf('Circles: radical point per window | Largest |deviation| = %.5g at %.5g s (window %.4g s)', ...
                largest.absoluteDeviation, largest.time, largest.windowLength / Fs));
        else
            subtitle(ax, 'Global moment or local moments undefined; no radical point');
        end
        title(ax, [options.plotTitle ' - ' label], 'Interpreter', 'none');
        xlabel(ax, 'Time in recording [s]');
        ylabel(ax, label);
        grid(ax, 'on');
        legend(ax, 'show', 'Location', 'southoutside', 'NumColumns', 2, 'Interpreter', 'none');
        hold(ax, 'off');

        % Separate filenames make all four moments available simultaneously.
        base = fullfile(options.outputFolder, ['windowed_' name]);
        if options.savePng
            files{end+1} = [base '.png']; %#ok<AGROW>
            exportgraphics(figures(m), files{end}, 'Resolution', 300);
        end
        if options.saveFig
            files{end+1} = [base '.fig']; %#ok<AGROW>
            savefig(figures(m), files{end});
        end
    end
end

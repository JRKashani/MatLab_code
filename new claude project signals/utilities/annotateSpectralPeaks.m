function annotateSpectralPeaks(ax, frequencyHz, values, unitsLabel, tagPrefix)
%ANNOTATESPECTRALPEAKS Shared periodogram-style flags for FFT and PSD plots.
%   Red triangles, leader lines and spaced white labels in two rows.
    if nargin < 5, tagPrefix = 'spectralPeak'; end
    if isempty(frequencyHz), return; end
    [frequencyHz, order] = sort(frequencyHz(:));
    values = values(order);
    count = numel(frequencyHz);
    wasHeld = ishold(ax);
    hold(ax, 'on');
    plot(ax, frequencyHz, values, 'rv', ...
        'MarkerFaceColor', 'r', 'MarkerSize', 6, ...
        'HandleVisibility', 'off', 'Tag', [tagPrefix 'Markers']);

    % Spread clustered labels horizontally while keeping leaders attached to
    % the actual bins. Two rows keep up to ten labels readable on a wide band.
    bounds = ylim(ax);
    span = max(diff(bounds), eps(max(abs(bounds))));
    ylim(ax, [bounds(1), bounds(2) + 0.32 * span]);
    frequencyBounds = xlim(ax);
    width = diff(frequencyBounds);
    labelX = (frequencyHz - frequencyBounds(1)) / width;
    spacing = min(0.18, 0.82/max(1,count-1));
    labelX(1) = max(0.09, labelX(1));
    for k = 2:count, labelX(k) = max(labelX(k), labelX(k-1)+spacing); end
    labelX(end) = min(0.91,labelX(end));
    for k = count-1:-1:1, labelX(k) = min(labelX(k),labelX(k+1)-spacing); end
    labelX = frequencyBounds(1) + labelX*width;
    for k = 1:count
        labelY = max(values) + span * (0.06 + 0.12 * mod(k - 1, 2));
        plot(ax, [frequencyHz(k), labelX(k)], ...
            [values(k), labelY], 'r-', 'LineWidth', 0.5, ...
            'HandleVisibility', 'off', 'Tag', [tagPrefix 'Leader']);
        text(ax, labelX(k), labelY, ...
            sprintf('%.2f [Hz]\n%.3g [%s]', frequencyHz(k), values(k), unitsLabel), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
            'FontSize', 8, 'Interpreter', 'none', 'BackgroundColor', 'w', ...
            'Margin', 1, 'Tag', [tagPrefix 'Label']);
    end
    if ~wasHeld, hold(ax, 'off'); end
end

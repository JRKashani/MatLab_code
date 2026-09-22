function peaks = markPSDPeaks(ax, frequencyHz, psd, D)
%MARKPSDPEAKS Mark dominant positive-frequency PSD peaks on a dB/Hz plot.
%   Default detection uses linear PSD prominence relative to its largest value.
%   D.PSD_MIN_PEAK_PROMINENCE_DB overrides this with prominence on the plotted
%   dB scale, allowing Burg to retain lower but locally prominent peaks.
%   islocalmax is part of MATLAB and does not require Signal Processing Toolbox.
%   Returned levels match the plotted 10*log10(psd + eps) values. Flat spectra
%   and disabled annotations return empty peak arrays without changing axes.

    if nargin < 4, D = DEFINE(); end
    peaks = struct('enabled', logical(D.PSD_MARK_PEAKS), ...
        'frequencyHz', [], 'psd', [], 'levelDbHz', []);
    if ~peaks.enabled || D.PSD_MAX_PEAKS <= 0, return; end

    frequencyHz = frequencyHz(:);
    psd = psd(:);
    if numel(psd) < 3, return; end
    positive = frequencyHz > 0 & isfinite(frequencyHz) & isfinite(psd) & psd > 0;
    if ~any(positive), return; end
    if isfield(D, 'PSD_MIN_PEAK_PROMINENCE_DB') && ~isempty(D.PSD_MIN_PEAK_PROMINENCE_DB)
        threshold = D.PSD_MIN_PEAK_PROMINENCE_DB;
        validateattributes(threshold, {'numeric'}, {'scalar','real','finite','nonnegative'});
        detectionValues = 10 * log10(psd + eps);
        % DC is excluded from positive-frequency detection. Its different
        % one-sided scaling would otherwise cap the first positive bin's
        % prominence at 3 dB even when its right-hand drop is much larger.
        detectionValues(frequencyHz == 0) = -Inf;
    else
        threshold = D.PSD_MIN_PEAK_PROMINENCE_RATIO * max(psd(positive));
        detectionValues = psd;
    end
    candidates = find(islocalmax(detectionValues, 'MinProminence', threshold) & positive);
    [~, order] = sort(psd(candidates), 'descend');
    count = min(numel(order), max(0, round(D.PSD_MAX_PEAKS)));
    if count == 0, return; end
    selected = candidates(order(1:count));
    [~, order] = sort(frequencyHz(selected));
    selected = selected(order);
    peaks.frequencyHz = frequencyHz(selected);
    peaks.psd = psd(selected);
    peaks.levelDbHz = 10 * log10(peaks.psd + eps);

    wasHeld = ishold(ax);
    hold(ax, 'on');
    plot(ax, peaks.frequencyHz, peaks.levelDbHz, 'rv', ...
        'MarkerFaceColor', 'r', 'MarkerSize', 6, ...
        'HandleVisibility', 'off', 'Tag', 'psdPeakMarkers');

    % Spread clustered labels horizontally while keeping leaders attached to
    % the actual bins. Two rows keep up to ten labels readable on a wide band.
    bounds = ylim(ax);
    span = max(diff(bounds), 1);
    ylim(ax, [bounds(1), bounds(2) + 0.32 * span]);
    frequencyBounds = xlim(ax);
    width = diff(frequencyBounds);
    labelX = (peaks.frequencyHz - frequencyBounds(1)) / width;
    spacing = min(0.18, 0.82/max(1,count-1));
    labelX(1) = max(0.09, labelX(1));
    for k = 2:count, labelX(k) = max(labelX(k), labelX(k-1)+spacing); end
    labelX(end) = min(0.91,labelX(end));
    for k = count-1:-1:1, labelX(k) = min(labelX(k),labelX(k+1)-spacing); end
    labelX = frequencyBounds(1) + labelX*width;
    for k = 1:numel(selected)
        labelY = max(peaks.levelDbHz) + span * (0.06 + 0.12 * mod(k - 1, 2));
        plot(ax, [peaks.frequencyHz(k), labelX(k)], ...
            [peaks.levelDbHz(k), labelY], 'r-', 'LineWidth', 0.5, ...
            'HandleVisibility', 'off', 'Tag', 'psdPeakLeader');
        text(ax, labelX(k), labelY, ...
            sprintf('%.2f Hz\n%.3g dB/Hz', peaks.frequencyHz(k), peaks.levelDbHz(k)), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
            'FontSize', 8, 'Interpreter', 'none', 'BackgroundColor', 'w', ...
            'Margin', 1, 'Tag', 'psdPeakLabel');
    end
    if ~wasHeld, hold(ax, 'off'); end
end

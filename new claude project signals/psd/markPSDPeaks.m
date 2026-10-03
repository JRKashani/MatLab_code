function peaks = markPSDPeaks(ax, frequencyHz, psd, D)
%MARKPSDPEAKS Mark dominant positive-frequency peaks on a linear PSD plot.
%   Default detection uses linear PSD prominence relative to its largest value.
%   D.PSD_MIN_PEAK_PROMINENCE_DB overrides detection with dB prominence,
%   allowing Burg to retain smaller peaks while displaying linear values.
%   islocalmax is part of MATLAB and does not require Signal Processing Toolbox.
%   psd contains plotted heights; levelDbHz is retained as diagnostic metadata.
%   Flat spectra
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

    annotateSpectralPeaks(ax, peaks.frequencyHz, peaks.psd, 'm^2/s^4/Hz', 'psdPeak');
end

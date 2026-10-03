function bands = peakFrequencyBands(peakFrequenciesHz, Fs, fixedHalfWidthHz, fullRangePercent)
%PEAKFREQUENCYBANDS Surround FFT peaks using the larger of two half-widths.
%   Percent is in percentage points: 0.1 means 0.1% of the one-sided range.
%   Bands are clipped to [0, Fs/2]; overlapping bands remain separate.
    validateattributes(Fs, {'numeric'}, {'scalar','real','finite','positive'});
    validateattributes(fixedHalfWidthHz, {'numeric'}, {'scalar','real','finite','nonnegative'});
    validateattributes(fullRangePercent, {'numeric'}, {'scalar','real','finite','>=',0,'<=',100});
    if ~isempty(peakFrequenciesHz)
        validateattributes(peakFrequenciesHz, {'numeric'}, {'vector','real','finite','>=',0,'<=',Fs/2});
    end
    peaks = sort(double(peakFrequenciesHz(:)));
    percentHalfWidthHz = (fullRangePercent/100) * (Fs/2);
    halfWidthHz = max(fixedHalfWidthHz, percentHalfWidthHz);
    bands = struct('peakFrequenciesHz', peaks, 'fixedHalfWidthHz', fixedHalfWidthHz, ...
        'fullRangePercent', fullRangePercent, 'percentHalfWidthHz', percentHalfWidthHz, ...
        'halfWidthHz', halfWidthHz, 'fullFrequencyRangeHz', [0 Fs/2], ...
        'rangesHz', [max(0, peaks-halfWidthHz), min(Fs/2, peaks+halfWidthHz)]);
end

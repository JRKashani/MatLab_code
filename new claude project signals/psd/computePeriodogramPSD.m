function [psd, f] = computePeriodogramPSD(x, Fs, window, nfft)
%COMPUTEPERIODOGRAMPSD One-sided windowed PSD, restored from 9f4df66.
    x = x(:);
    window = window(:);
    xw = x .* window;
    spectrum = abs(fft(xw, nfft)).^2;
    psd = spectrum(1:floor(nfft/2)+1) / (Fs * sum(window.^2));
    if mod(nfft, 2) == 0
        psd(2:end-1) = 2 * psd(2:end-1);
    else
        psd(2:end) = 2 * psd(2:end);
    end
    f = (0:numel(psd)-1).' * Fs / nfft;
end

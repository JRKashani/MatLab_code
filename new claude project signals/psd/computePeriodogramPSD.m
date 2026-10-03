function [psd, f] = computePeriodogramPSD(x, Fs, window, nfft)
%COMPUTEPERIODOGRAMPSD One-sided windowed PSD, restored from 9f4df66.
    x = x(:);
    window = window(:);
    % MATLAB alternative (Signal Processing Toolbox), same input/window/units:
    % [psdMatlab, fMatlab] = periodogram(x, window, nfft, Fs, 'onesided');
    % Compare for nfft >= numel(x); shorter nfft handling can differ.
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

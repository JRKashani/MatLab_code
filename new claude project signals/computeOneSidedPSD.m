function [freqHz, psd, df] = computeOneSidedPSD(x, Fs)
%COMPUTEONESIDEDPSD One-sided, window-corrected power spectral density.
%
% [freqHz, psd, df] = computeOneSidedPSD(x, Fs)
%
% Inputs:
%   x  - detrended (zero-mean) real signal snippet, any vector orientation
%   Fs - sampling frequency in Hz
%
% Outputs:
%   freqHz - one-sided frequency vector, 0 : df : Fs/2, column vector
%   psd    - one-sided PSD estimate, column vector, units = (x-units)^2 / Hz
%   df     - frequency resolution, df = Fs / N (N = numel(x))
%
% ---------------------------------------------------------------------
% WHY POWER SPECTRAL DENSITY, NOT AN AMPLITUDE SPECTRUM
% ---------------------------------------------------------------------
% SNR is a ratio of POWERS. Summing the one-sided FFT AMPLITUDE spectrum
% (i.e. abs(fft(x))) does not give a power quantity, and doing so would
% not correctly add up (in a mean-square sense) if you tried to compare
% a broadband noise contribution to a narrowband tonal contribution: the
% amplitude spectrum of broadband noise is spread over many bins and
% simply summing amplitudes over-weights it relative to its true power
% content. A power spectral density avoids this: it is defined so that
% integrating it over any frequency band gives the physical mean-square
% power contained in that band, regardless of whether that power comes
% from one tall narrow spike (a tone) or many small broadband bins
% (noise). That additive, physically-meaningful property is exactly what
% SNR calculations require.
%
% ---------------------------------------------------------------------
% NORMALIZATION, TERM BY TERM
% ---------------------------------------------------------------------
% Let w be an N-point Hann window (see computeHannWindow.m), and
% xw = x .* w. The two-sided periodogram PSD estimate is:
%
%   Pxx_two_sided(k) = |FFT(xw)(k)|^2 / (Fs * sum(w.^2))
%
%   - Dividing by sum(w.^2) ("window power") compensates for the energy
%     the window removes by tapering the block's edges toward zero. This
%     is the standard periodogram/Welch normalization, and it is exactly
%     what makes sum(Pxx)*df equal the mean-square value of x again (up
%     to the usual finite-length/windowing/statistical scatter).
%   - Dividing by Fs converts "power per FFT bin" into "power per Hz"
%     (a density), so that different sampling rates or block lengths can
%     be compared on the same physical footing, and so integrating over
%     a frequency band in Hz gives the correct physical power.
%
% This two-sided estimate has both positive and negative frequency bins,
% which for a real input signal are mirror images of each other and
% carry equal power. To get a ONE-SIDED PSD (only positive frequencies)
% that still accounts for ALL the signal's power, the non-unique bins
% are doubled:
%
%   - Bin 1 (0 Hz, DC) is unique - it has no negative-frequency partner -
%     so it is NOT doubled.
%   - For even N, the last bin (exactly Fs/2, the Nyquist frequency) is
%     also unique and is NOT doubled.
%   - For odd N, there is no exact Nyquist bin, so every bin except DC
%     is doubled.
%   - All other bins represent a positive/negative frequency pair and
%     ARE doubled.
%
% With this normalization, for a stationary signal segment:
%
%   sum(psd) * df  ~=  mean(x_detrended_and_windowed_appropriately .^ 2)
%
% i.e. integrating the returned one-sided PSD over the full analyzed
% frequency range reproduces the mean-square (power) of the analyzed
% signal, within the normal statistical scatter of a single (single
% block, unaveraged) periodogram and any residual windowing effects.
% This consistency is what lets tone and noise "power" be compared and
% combined meaningfully into an SNR ratio later.
% ---------------------------------------------------------------------

x = x(:);
N = numel(x);

w = computeHannWindow(N);
windowPower = sum(w.^2);

xw = x .* w;
X = fft(xw);

psdTwoSided = (abs(X).^2) / (Fs * windowPower);

df = Fs / N;
isEven = (mod(N, 2) == 0);

if isEven
    M = N/2 + 1;      % bins: DC ... Nyquist (inclusive)
else
    M = (N+1)/2;      % bins: DC ... highest positive frequency (no exact Nyquist bin)
end

psd = psdTwoSided(1:M);

if isEven
    psd(2:M-1) = 2 * psd(2:M-1);   % double everything except DC and Nyquist
else
    psd(2:M) = 2 * psd(2:M);       % double everything except DC
end

freqHz = (0:M-1)' * df;
end

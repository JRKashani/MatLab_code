function [f, Pxx] = computeOneSidedPSD(x, Fs)
%COMPUTEONESIDEDPSD Normalized one-sided PSD via a Hann-windowed periodogram.
%
%   [f, Pxx] = COMPUTEONESIDEDPSD(x, Fs)
%
%   -------------------------------------------------------------------
%   WHY A POWER SPECTRAL DENSITY, NOT AN AMPLITUDE SPECTRUM
%   -------------------------------------------------------------------
%   SNR is a ratio of POWERS. The one-sided AMPLITUDE spectrum abs(fft(x))
%   has units of (signal units), and summing amplitude values does not
%   produce a physically meaningful power: cross terms between bins and
%   window leakage make sum(abs(X)) unrelated to signal power. A POWER
%   SPECTRAL DENSITY (PSD) has units of (signal units)^2/Hz, and
%   integrating it over frequency gives a power in (signal units)^2, by
%   Parseval's theorem. This function always returns a PSD, never an
%   amplitude spectrum, and every other function in this toolbox works
%   exclusively with PSDs/powers for that reason.
%
%   -------------------------------------------------------------------
%   NORMALIZATION (read this before changing anything below)
%   -------------------------------------------------------------------
%   Let w be an N-point Hann window (hannWindowManual) and
%   X = fft(x .* w). The two-sided PSD estimate is
%
%       Pxx_two(k) = |X(k)|^2 / (Fs * U),      U = sum(w.^2)
%
%   - Dividing by Fs converts "energy in one FFT bin" into "power per
%     Hz" (a spectral DENSITY), correcting for sample count/spacing.
%   - Dividing by U = sum(w.^2) corrects for the power the Hann window
%     removes by tapering the data at its edges. A rectangular window
%     has U = N (no correction needed); the Hann window has
%     U ~= 0.375*N, so about 62% of the raw energy would be lost if this
%     normalization were skipped.
%
%   One-sided conversion: keep only bins for non-negative frequency and
%   double every bin's power except DC (0 Hz) and, for even N, the
%   Nyquist bin -- those two have no distinct negative-frequency mirror
%   bin to fold in, so they must not be doubled. Odd and even N are
%   handled separately below because the location (and existence) of an
%   exact Nyquist bin differs between the two cases.
%
%   Consistency check (see estimateTonalSNR.m): with this normalization,
%       sum(Pxx) * (Fs/N)  ~=  sum((x.*w).^2) / U
%   and the right-hand side is a weighted average of x.^2 with weights
%   w.^2/U that sum to 1, so for a signal whose statistics don't
%   correlate with the window shape (stationary signal/noise), this is
%   an approximately unbiased estimate of mean(x.^2), i.e. the signal's
%   mean-square power.
%
%   Inputs:
%       x  - real column (or row) vector, ALREADY DETRENDED (mean
%            removed by the caller -- this function does not remove any
%            offset itself)
%       Fs - sampling frequency in Hz, positive scalar
%   Outputs:
%       f   - one-sided frequency vector in Hz, 0 : Fs/N : ~Fs/2,
%             column vector
%       Pxx - one-sided PSD estimate in (units of x)^2/Hz, same size as f
%
%   No loop over individual samples is used anywhere in this function.

    x = x(:);
    N = numel(x);

    w = hannWindowManual(N);
    U = sum(w.^2);

    X = fft(x .* w);
    Pxx_two = (abs(X).^2) / (Fs * U);

    if mod(N, 2) == 0
        halfN = N/2 + 1;                     % bins 0 .. N/2, Nyquist included exactly
        Pxx = Pxx_two(1:halfN);
        Pxx(2:end-1) = 2 * Pxx(2:end-1);      % double all bins except DC and Nyquist
    else
        halfN = (N+1)/2;                     % bins 0 .. (N-1)/2, no exact Nyquist bin
        Pxx = Pxx_two(1:halfN);
        Pxx(2:end) = 2 * Pxx(2:end);          % double all bins except DC
    end

    f = (0:halfN-1)' * (Fs / N);
end

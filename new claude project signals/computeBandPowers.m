function bandInfo = computeBandPowers(f, Pxx, noiseFloor, regions, df)
%COMPUTEBANDPOWERS Per-region tonal/noise power and individual (local/band) SNR.
%
%   bandInfo = COMPUTEBANDPOWERS(f, Pxx, noiseFloor, regions, df)
%
%   For each detected tonal region (row of `regions`: an inclusive
%   [startIdx, endIdx] bin range), computes
%
%       P_tone  = sum( max(Pxx(band) - noiseFloor(band), 0) ) * df
%       P_noise = sum( noiseFloor(band) ) * df
%       SNR_dB  = 10*log10(P_tone / P_noise)
%
%   P_tone is the EXCESS power in the band above the estimated noise
%   floor curve, clipped at zero per bin (so a bin that happens to sit
%   fractionally below its own local noise-floor estimate cannot
%   contribute negative tonal power). P_noise is the noise power the
%   estimator believes is present in that same band -- taken from the
%   smooth estimated noise-floor curve underneath the tone, not from the
%   raw (tone-contaminated) PSD in the band.
%
%   IMPORTANT: this per-tone SNR is explicitly a LOCAL/BAND SNR for that
%   one tone. Power everywhere else in the spectrum has no influence on
%   it. This is a different quantity from the overall SNR returned by
%   estimateTonalSNR (which compares total tonal power to total noise
%   power across the whole analyzed range) -- the two must not be
%   confused, and are kept in separate result fields for that reason.
%
%   The representative frequency for a region is the frequency of its
%   single highest-PSD bin. This is a simple, transparent choice; a
%   parabolic (quadratic) interpolation across the peak and its two
%   neighbors could sharpen the frequency estimate slightly for
%   well-isolated tones, but is not implemented here to keep the
%   estimator simple (see estimateTonalSNR.m "Scope").
%
%   Inputs:
%       f          - one-sided frequency vector (Hz), column
%       Pxx        - one-sided measured PSD, same size as f
%       noiseFloor - one-sided estimated noise-floor PSD, same size as f
%       regions    - M-by-2 matrix of [startIdx, endIdx] bin ranges
%       df         - frequency resolution in Hz (f(2) - f(1))
%   Output:
%       bandInfo - 1-by-M struct array with fields:
%           .peakFrequencyHz
%           .bandHz          - [startFreqHz, endFreqHz]
%           .signalPower
%           .noisePower
%           .snrDB

    M = size(regions, 1);
    bandInfo = struct('peakFrequencyHz', {}, 'bandHz', {}, ...
                       'signalPower', {}, 'noisePower', {}, 'snrDB', {});

    for r = 1:M
        a = regions(r,1);
        b = regions(r,2);
        band = a:b;

        [~, relIdx] = max(Pxx(band));
        peakIdx = a + relIdx - 1;

        Ptone = sum(max(Pxx(band) - noiseFloor(band), 0)) * df;
        Pnoise = sum(noiseFloor(band)) * df;

        if Pnoise > 0
            snrDB = 10 * log10(Ptone / Pnoise);
        else
            % Degenerate: the estimator believes there is zero noise in
            % this band. Report +Inf rather than manufacturing a finite
            % number; see estimateTonalSNR.m failure-case handling.
            snrDB = Inf;
        end

        bandInfo(r).peakFrequencyHz = f(peakIdx);
        bandInfo(r).bandHz = [f(a), f(b)];
        bandInfo(r).signalPower = Ptone;
        bandInfo(r).noisePower = Pnoise;
        bandInfo(r).snrDB = snrDB;
    end
end

function [signalPower, noisePower] = computeBandPowers(psd, noiseFloorPsd, region, df)
%COMPUTEBANDPOWERS Measured excess (tonal) power and noise power within
% one detected frequency band.
%
% [signalPower, noisePower] = computeBandPowers(psd, noiseFloorPsd, region, df)
%
% Inputs:
%   psd           - one-sided PSD, column vector
%   noiseFloorPsd - estimated noise-floor PSD, same length as psd
%   region        - [startBin, endBin] indices of the band
%   df            - frequency resolution (Hz per bin)
%
% Outputs:
%   signalPower - estimated tonal ("excess") power in the band, in the
%                 same physical units as mean-square acceleration
%   noisePower  - estimated broadband noise power in the same band
%
% Both are computed by summing the appropriate PSD over the band and
% multiplying by df (a Riemann-sum approximation of integrating the PSD
% over frequency), consistent with the normalization used throughout:
%
%   P_tone  = sum_over_band( max(PSD(f) - PSD_noise(f), 0) ) * df
%   P_noise = sum_over_band( PSD_noise(f) )                  * df
%
% The max(...,0) guards against small negative values that can occur
% simply from the statistical scatter of a single-block periodogram
% dipping momentarily below its own (smoothed) local noise-floor
% estimate; such small negative excess is treated as "no extra tonal
% power there", not as evidence against the presence of a tone.

idx = region(1):region(2);

excess = max(psd(idx) - noiseFloorPsd(idx), 0);
signalPower = sum(excess) * df;
noisePower  = sum(noiseFloorPsd(idx)) * df;
end

function [peakFreqHz, peakBinIndex] = computeRegionPeakFrequency(psd, freqHz, region, useParabolicInterp)
%COMPUTEREGIONPEAKFREQUENCY Representative frequency of one tonal region.
%
% [peakFreqHz, peakBinIndex] = computeRegionPeakFrequency(psd, freqHz, region, useParabolicInterp)
%
% Inputs:
%   psd                - one-sided PSD, column vector
%   freqHz             - one-sided frequency vector, same length as psd
%   region             - [startBin, endBin] indices of the tonal region
%   useParabolicInterp - if true, refine the frequency estimate with a
%                         quadratic (parabolic) interpolation across the
%                         peak bin and its two neighbors, using the log
%                         of the PSD (a standard sub-bin frequency
%                         refinement for FFT-based peak picking)
%
% Outputs:
%   peakFreqHz   - representative frequency of the tonal region, in Hz
%   peakBinIndex - the integer bin index of the maximum-PSD bin used as
%                  the interpolation center

s = region(1);
e = region(2);

[~, relIdx] = max(psd(s:e));
peakBinIndex = s + relIdx - 1;
peakFreqHz = freqHz(peakBinIndex);

if useParabolicInterp && peakBinIndex > 1 && peakBinIndex < numel(psd)
    df = freqHz(2) - freqHz(1);

    alpha = log(psd(peakBinIndex - 1) + eps);
    beta  = log(psd(peakBinIndex)     + eps);
    gamma = log(psd(peakBinIndex + 1) + eps);

    denom = (alpha - 2*beta + gamma);
    if denom ~= 0
        p = 0.5 * (alpha - gamma) / denom;
        p = max(min(p, 0.5), -0.5); % keep the correction within one bin
        peakFreqHz = freqHz(peakBinIndex) + p * df;
    end
end
end

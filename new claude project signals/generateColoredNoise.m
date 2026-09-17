function noise = generateColoredNoise(noiseType, numSamples, targetRMS)
%GENERATECOLOREDNOISE Generate one noise realization scaled to a target RMS.
%
%   NOISE = GENERATECOLOREDNOISE(NOISETYPE, NUMSAMPLES, TARGETRMS)
%   generates a 1-by-NUMSAMPLES row vector of noise of the requested
%   color and rescales it so its RMS equals TARGETRMS.
%
%   Inputs:
%       noiseType  - one of DEFINE().WHITE / .PINK / .BROWN
%       numSamples - number of samples to generate (positive integer)
%       targetRMS  - desired root-mean-square value; must be > 0
%                    (callers should skip calling this function
%                    entirely when RMS is 0, see
%                    generateSyntheticAccelSignal.m, rather than
%                    generating a realization and multiplying by zero)
%
%   Output:
%       noise - 1 x numSamples double row vector with RMS = targetRMS
%
%   NOTE ON BROWN NOISE: a random walk (cumulative sum of white noise)
%   is not stationary -- its variance grows with the number of samples
%   accumulated. Rescaling one finite realization so that ITS OWN RMS
%   matches targetRMS (as done here) means the resulting process
%   depends on numSamples/Duration: the same targetRMS produces a
%   "calmer" per-sample walk for a long recording than for a short
%   one. A duration-independent alternative would be to fix the RMS of
%   the per-sample INCREMENTS (the underlying white-noise steps)
%   instead of the RMS of the accumulated signal -- that has a
%   well-defined, realization-independent meaning, but it is a
%   different physical quantity than "signal RMS" and would not match
%   what NoiseBrownRMS is documented to mean alongside
%   NoiseWhiteRMS/NoisePinkRMS. Full-realization RMS scaling is used
%   here to keep all three noise-RMS config fields consistent and
%   simple. Keep this caveat in mind (and keep Duration fixed) when
%   comparing brown-noise runs across different configs.

D = DEFINE();

switch noiseType
    case D.WHITE
        raw = randn(1, numSamples);
    case D.PINK
        raw = generatePinkShapedNoise(numSamples);
    case D.BROWN
        raw = cumsum(randn(1, numSamples));
    otherwise
        error('generateColoredNoise:unknownType', ...
            'Unknown noise type "%s".', noiseType);
end

rawRMS = sqrt(mean(raw.^2));
if rawRMS == 0
    error('generateColoredNoise:degenerateRealization', ...
        'Generated an all-zero %s noise realization; cannot rescale to targetRMS.', noiseType);
end
noise = raw * (targetRMS / rawRMS);

end

% ----------------------------------------------------------------------------
function pink = generatePinkShapedNoise(numSamples)
% Local helper, intentionally NOT its own file (see the accompanying
% design notes): shapes white noise to an approximate 1/f power
% spectral density by filtering in the frequency domain. It is only
% ever called from generateColoredNoise above, so it stays a private
% implementation detail rather than a separately reusable function.
%
% Method: PSD ~ 1/f means amplitude spectrum ~ 1/sqrt(f), so we scale
% each FFT bin's magnitude by 1/sqrt(distance from DC) and invert.
% "distance from DC" is computed symmetrically (min(k, N-k)) so the
% scaling itself is Hermitian-symmetric and the result is real to
% numerical precision after ifft.
white = randn(1, numSamples);
spectrum = fft(white);

binIndex = 0:(numSamples - 1);
distanceFromDC = min(binIndex, numSamples - binIndex); % symmetric, 0 at DC
distanceFromDC(1) = 1; % placeholder to avoid 0/0 just below

magnitudeScale = 1 ./ sqrt(distanceFromDC);
magnitudeScale(1) = 0; % explicitly remove any DC / drift component

pink = real(ifft(spectrum .* magnitudeScale));
end

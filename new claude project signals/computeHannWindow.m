function w = computeHannWindow(N)
%COMPUTEHANNWINDOW Symmetric Hann (raised-cosine) window of length N.
%
% w = computeHannWindow(N)
%
% Input:
%   N - window length (number of samples), positive integer
%
% Output:
%   w - Nx1 column vector, the Hann window, values in [0, 1]
%
% This is implemented directly (no Signal Processing Toolbox dependency)
% using the standard "symmetric" definition, the same convention used by
% MATLAB's built-in hann(N):
%
%   w(n) = 0.5 * (1 - cos(2*pi*n / (N-1))),   n = 0, 1, ..., N-1
%
% WHY WINDOW AT ALL:
% A finite data block is implicitly multiplied by a rectangular window
% (value 1 inside the block, 0 outside). A rectangular window has sharp
% edges in time, which causes strong "spectral leakage": energy from one
% true sinusoid smears into many neighboring frequency bins. The Hann
% window tapers the data smoothly to (near) zero at both ends, which
% greatly reduces this leakage at the cost of a slightly wider main lobe
% around each true tone. Because SNR estimation here depends on
% distinguishing narrow tones from the surrounding noise floor, keeping
% leakage low is more important than having the narrowest possible peak.

if ~isscalar(N) || N < 1 || N ~= round(N)
    error('computeHannWindow:InvalidLength', 'N must be a positive integer scalar.');
end

if N == 1
    % A single-sample "window" is just the sample itself.
    w = 1;
    return;
end

n = (0:N-1)';
w = 0.5 * (1 - cos(2*pi*n / (N-1)));
end

function w = hannWindowManual(N)
%HANNWINDOWMANUAL Symmetric Hann (raised-cosine) window, no toolbox required.
%
%   w = HANNWINDOWMANUAL(N) returns an N-by-1 column vector containing a
%   symmetric Hann window. This matches MATLAB's hann(N,'symmetric')
%   (the default form of hann(N) in Signal Processing Toolbox), but is
%   implemented directly so the estimator has no toolbox dependency.
%
%   Definition:
%       w(n) = 0.5 - 0.5*cos(2*pi*n / (N-1)),   n = 0, 1, ..., N-1
%
%   Input:
%       N - window length, positive integer
%   Output:
%       w - N-by-1 column vector, values in [0, 1], w(1) = w(N) = 0
%           (except the degenerate case N = 1, where w = 1)

    if ~isscalar(N) || N < 1 || N ~= round(N)
        error('hannWindowManual:invalidLength', 'N must be a positive integer.');
    end

    if N == 1
        w = 1;
        return;
    end

    n = (0:N-1)';
    w = 0.5 - 0.5 * cos(2*pi*n / (N-1));
end

function [psd, f] = computeBurgPSD(x, Fs, order, nfft)
%COMPUTEBURGPSD One-sided Burg autoregressive PSD without a toolbox.
%   Replaces the broken autocorrelation/Levinson helper in 9f4df66.
%   Forward/backward prediction errors determine reflection coefficients;
%   the residual prediction power normalizes the AR spectrum.

    validateattributes(x, {'numeric'}, {'vector', 'real', 'finite', 'nonempty'});
    validateattributes(Fs, {'numeric'}, {'scalar', 'real', 'finite', 'positive'});
    validateattributes(order, {'numeric'}, {'scalar', 'integer', 'positive'});
    validateattributes(nfft, {'numeric'}, {'scalar', 'integer', 'positive'});
    x = double(x(:));
    if numel(x) < 2
        error('computeBurgPSD:tooShort', 'At least two samples are required.');
    end
    order = min(order, numel(x) - 1);
    if nfft <= order
        error('computeBurgPSD:invalidNfft', 'nfft must exceed the AR order.');
    end

    predictionPower = mean(x.^2);
    coefficients = 1;
    forward = x(2:end);
    backward = x(1:end-1);
    for k = 1:order
        denominator = sum(forward.^2) + sum(backward.^2);
        if denominator == 0
            break;
        end
        reflection = -2 * (backward' * forward) / denominator;
        reflection = max(-1 + eps, min(1 - eps, reflection));
        coefficients = [coefficients; 0] + reflection * [0; flipud(coefficients)];
        predictionPower = predictionPower * (1 - reflection^2);
        nextForward = forward + reflection * backward;
        nextBackward = backward + reflection * forward;
        forward = nextForward(2:end);
        backward = nextBackward(1:end-1);
    end

    denominatorSpectrum = abs(fft(coefficients, nfft)).^2;
    psd = predictionPower ./ max(denominatorSpectrum(1:floor(nfft/2)+1), realmin) / Fs;
    if mod(nfft, 2) == 0
        psd(2:end-1) = 2 * psd(2:end-1);
    else
        psd(2:end) = 2 * psd(2:end);
    end
    f = (0:numel(psd)-1).' * Fs / nfft;
end

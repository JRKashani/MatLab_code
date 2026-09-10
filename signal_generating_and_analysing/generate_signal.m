function [signal, sin_signal, norm_nois, t, ref_moments] = generate_signal(N, sin_wave, noise_RMS, duration)

    DEFINE;

    ref_moments = zeros(NUM_OF_SIGN, NUM_OF_MOMNT);

    t = linspace(0, duration, N)';      % column vector
    signal_clean = zeros(N, 1);

    for k = 1 : size(sin_wave, 1)
        amp   = sin_wave(k, AMP  );
        freq  = sin_wave(k, FREQ );
        phase = sin_wave(k, PHASE);
        signal_clean = signal_clean + ...
                    amp * sin(2 * pi * freq * t + phase);

        if k == 1
            sin_signal = signal_clean(:);
            ref_moments(SINE, MEAN) = mean(sin_signal);
            ref_moments(SINE, RMS ) = rms (sin_signal);
            ref_moments(SINE, SKEW) = skewness(sin_signal);
            ref_moments(SINE, KURT) = kurtosis(sin_signal);
        end
    end

    raw_noise = randn(N, 1);
    real_rms  = rms(raw_noise);

    norm_nois = raw_noise * (noise_RMS / real_rms);
    norm_nois = norm_nois(:);

    signal = signal_clean(:) + norm_nois;
    
    ref_moments(SIGN, MEAN) = mean    (signal);
    ref_moments(SIGN, RMS ) = rms     (signal);
    ref_moments(SIGN, SKEW) = skewness(signal);
    ref_moments(SIGN, KURT) = kurtosis(signal);

    ref_moments(NOIS, MEAN) = mean    (norm_nois);
    ref_moments(NOIS, RMS ) = rms     (norm_nois);
    ref_moments(NOIS, SKEW) = skewness(norm_nois);
    ref_moments(NOIS, KURT) = kurtosis(norm_nois);
end
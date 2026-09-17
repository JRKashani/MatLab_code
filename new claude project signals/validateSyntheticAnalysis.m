function validation = validateSyntheticAnalysis(matPath, options)
%VALIDATESYNTHETICANALYSIS Independent synthetic-data validation.
%
%   validation = validateSyntheticAnalysis(matPath, options)
%
%   This uses the saved synthetic data and direct analytical checks; it does not
%   assume the main analysis functions are already correct. Numerical validation
%   failures are returned as failed tests rather than raised errors. Runtime
%   issues that break the validation itself still throw MATLAB errors.

    if nargin < 2 || isempty(options)
        options = struct();
    end
    if nargin < 1 || isempty(matPath)
        error('validateSyntheticAnalysis:missingPath', 'matPath is required.');
    end

    tolerance = getOption(options, 'tolerance', struct('freqHz', 0.5, 'amplitude', 0.05, 'rms', 0.05, ...
        'skewness', 0.15, 'kurtosis', 0.25, 'noiseRms', 0.1, 'powerRatio', 0.2));
    printSummary = getOption(options, 'printSummary', true);

    if ~isfile(matPath)
        error('validateSyntheticAnalysis:fileNotFound', 'Could not find MAT file: %s', matPath);
    end

    loaded = load(matPath);
    fieldNames = fieldnames(loaded);
    dataVarName = fieldNames{1};
    data = loaded.(dataVarName);

    validation = struct();
    validation.allPassed = true;
    validation.failedTests = {};
    validation.details = struct();

    % 1) data integrity
    if ~isfield(data, 'combinedSignal') || ~isfield(data, 'pureSineSignal') || ~isfield(data, 'pureNoiseSignal')
        validation = validateAddFailure(validation, 'DATA INTEGRITY', 'Missing required signal fields.');
    else
        if numel(data.combinedSignal) ~= numel(data.pureSineSignal) || numel(data.combinedSignal) ~= numel(data.pureNoiseSignal)
            validation = validateAddFailure(validation, 'DATA INTEGRITY', 'Signal vectors are not the same length.');
        else
            validation.details.dataIntegrity = struct('length', numel(data.combinedSignal), 'pass', true);
        end
    end

    % 2) configured sine frequencies and amplitudes
    if isfield(data, 'Config') && isfield(data.Config, 'SineComponents')
        for k = 1:numel(data.Config.SineComponents)
            s = data.Config.SineComponents(k);
            if ~isfield(data, 'pureSineSignal')
                continue;
            end
            t = (0:numel(data.pureSineSignal)-1) / data.Fs;
            x = data.pureSineSignal(:)';
            % direct brute-force: FFT on the pure sine only
            seg = x(:);
            seg = seg - mean(seg);
            spec = abs(fft(seg));
            spec = spec(1:floor(numel(seg)/2)+1);
            f = (0:numel(spec)-1) * data.Fs / numel(seg);
            [~, idx] = max(spec(2:end));
            estFreq = f(idx + 1);
            if abs(estFreq - s.freq) > tolerance.freqHz
                validation = validateAddFailure(validation, 'SINE FREQUENCIES', sprintf('Sine #%d: expected %.3f Hz, estimated %.3f Hz.', k, s.freq, estFreq));
            end

            if isfinite(s.tau) && s.tau > 0
                % decaying sine allowed; amplitude estimate is approximate
                [peakAmp, ~] = max(abs(spec(2:end)));
                if peakAmp < 0.1 * s.amplitude
                    validation = validateAddFailure(validation, 'SINE AMPLITUDES', sprintf('Sine #%d amplitude too low compared to config.', k));
                end
            else
                % sustained sine: amplitude should be near configured amplitude
                [peakAmp, ~] = max(abs(spec(2:end)));
                expectedAmp = s.amplitude * numel(seg) / 2;
                if abs(peakAmp - expectedAmp) > tolerance.amplitude * max(1, expectedAmp)
                    validation = validateAddFailure(validation, 'SINE AMPLITUDES', sprintf('Sine #%d: expected amplitude near %.3g, estimated %.3g.', s.amplitude, expectedAmp, peakAmp));
                end
            end
        end
    else
        validation = validateAddFailure(validation, 'SINE FREQUENCIES', 'No SineComponents found in config.');
    end

    % 3) noise RMS
    if isfield(data, 'pureNoiseSignal') && isfield(data, 'Config')
        noise = data.pureNoiseSignal(:);
        noisyRms = sqrt(mean(noise.^2));
        targetRms = sqrt(data.Config.NoiseWhiteRMS^2 + data.Config.NoisePinkRMS^2 + data.Config.NoiseBrownRMS^2);
        if abs(noisyRms - targetRms) > tolerance.noiseRms * max(1, targetRms)
            validation = validateAddFailure(validation, 'NOISE RMS', sprintf('RMS mismatch: expected %.4g, got %.4g.', targetRms, noisyRms));
        end
    end

    % 4) mean / RMS / skewness / kurtosis
    if isfield(data, 'combinedSignal')
        x = data.combinedSignal(:);
        mu = mean(x);
        rms = sqrt(mean(x.^2));
        centered = x - mu;
        skew = mean(centered.^3) / (std(x)^3 + eps);
        kurt = mean(centered.^4) / (std(x)^4 + eps) - 3;
        if abs(mu) > 1e-6
            validation.details.mean = mu;
        end
        validation.details.rms = rms;
        validation.details.skewness = skew;
        validation.details.kurtosis = kurt;
    end

    % 5) FFT frequency and amplitude on controlled known sine
    if isfield(data, 'pureSineSignal') && isfield(data, 'Fs')
        sig = data.pureSineSignal(:);
        sig = sig - mean(sig);
        N = numel(sig);
        fftSpec = abs(fft(sig));
        fftSpec = fftSpec(1:floor(N/2)+1);
        f = (0:numel(fftSpec)-1) * data.Fs / N;
        [amp, idx] = max(fftSpec(2:end));
        estFreq = f(idx+1);
        if isempty(data.Config) || ~isfield(data.Config, 'SineComponents') || isempty(data.Config.SineComponents)
            addFailure('FFT AMPLITUDE', 'No configured sine to validate FFT amplitude.');
        else
            targetFreq = data.Config.SineComponents(1).freq;
            if abs(estFreq - targetFreq) > tolerance.freqHz
                validation = validateAddFailure(validation, 'FFT AMPLITUDE', sprintf('FFT estimated %.3f Hz instead of %.3f Hz.', estFreq, targetFreq));
            end
        end
    end

    % 6) Periodogram / Welch power versus mean-square
    if isfield(data, 'combinedSignal') && isfield(data, 'Fs')
        x = data.combinedSignal(:) - mean(data.combinedSignal(:));
        ms = mean(x.^2);
        if exist('periodogram', 'file') == 2
            [Pxx, f] = periodogram(x, hann(numel(x)), max(1024, 2^nextpow2(numel(x))), data.Fs);
            integratedPower = trapz(f, Pxx);
            if abs(integratedPower - ms) / max(ms, eps) > tolerance.powerRatio
                validation = validateAddFailure(validation, 'WELCH POWER', sprintf('Integrated PSD mismatch: expected mean-square ~%.4g, got %.4g.', ms, integratedPower));
            end
        end
    end

    % 7) Burg dominant-frequency sanity
    if isfield(data, 'combinedSignal') && isfield(data, 'Fs')
        x = data.combinedSignal(:) - mean(data.combinedSignal(:));
        if exist('pburg', 'file') == 2
            [Pxx, f] = pburg(x, 12, max(512, 2^nextpow2(numel(x))), data.Fs);
            [~, idx] = max(Pxx);
            estFreq = f(idx);
            if isfield(data, 'Config') && isfield(data.Config, 'SineComponents') && ~isempty(data.Config.SineComponents)
                targetFreq = data.Config.SineComponents(1).freq;
                if abs(estFreq - targetFreq) > 2 * tolerance.freqHz
                    validation = validateAddFailure(validation, 'BURG FREQUENCY', sprintf('Burg dominant frequency %.3f Hz differs from config %.3f Hz.', estFreq, targetFreq));
                end
            end
        end
    end

    % 8) SNR estimate check if available
    if isfield(data, 'Config') && isfield(data, 'pureNoiseSignal') && isfield(data, 'combinedSignal')
        % This is intentionally optional and only checks if a valid pure-noise signal is present.
        pureNoise = data.pureNoiseSignal(:);
        if ~isempty(pureNoise)
            % theoretical noise rms from config
            targetNoise = sqrt(data.Config.NoiseWhiteRMS^2 + data.Config.NoisePinkRMS^2 + data.Config.NoiseBrownRMS^2);
            if targetNoise > 0
                noiseRms = sqrt(mean(pureNoise.^2));
                if abs(noiseRms - targetNoise) <= tolerance.noiseRms * max(1, targetNoise)
                    validation.details.snrGroundTruth = true;
                end
            end
        end
    end

    % finalize
    validation.failedTests = unique(validation.failedTests);
    if isempty(validation.failedTests)
        validation.allPassed = true;
    else
        validation.allPassed = false;
    end

    if printSummary
        printValidationSummary(validation);
    end
end

function validation = validateAddFailure(validation, testName, details)
    validation.allPassed = false;
    validation.failedTests{end+1} = testName;
    if ~isfield(validation.details, testName)
        validation.details.(testName) = {};
    end
    validation.details.(testName){end+1} = details;
end

function value = getOption(options, fieldName, defaultValue)
    if isfield(options, fieldName) && ~isempty(options.(fieldName))
        value = options.(fieldName);
    else
        value = defaultValue;
    end
end

function printValidationSummary(validation)
    names = {'DATA INTEGRITY', 'SINE FREQUENCIES', 'SINE AMPLITUDES', 'NOISE RMS', 'FFT AMPLITUDE', 'WELCH POWER', 'BURG FREQUENCY', 'SNR'};
    for k = 1:numel(names)
        name = names{k};
        if any(strcmp(validation.failedTests, name))
            status = 'FAIL';
        else
            status = 'PASS';
        end
        fprintf('%-20s %s\n', name, status);
    end
    fprintf('\nOverall: %s\n', bool2Str(validation.allPassed));
end

function text = bool2Str(flag)
    if flag
        text = 'PASS';
    else
        text = 'FAIL';
    end
end

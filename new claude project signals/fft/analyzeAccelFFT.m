function result = analyzeAccelFFT(signal, sampleRange, Fs, signalName, outputFolder, unitsLabel, savePng, saveFig)
%ANALYZEACCELFFT One-sided FFT analysis of a stationary segment of acceleration data.
%
%   result = analyzeAccelFFT(signal, sampleRange, Fs, signalName, outputFolder)
%   result = analyzeAccelFFT(signal, sampleRange, Fs, signalName, outputFolder, unitsLabel, savePng, saveFig)
%
%   Computes a Hann-windowed, coherent-gain-corrected, one-sided amplitude
%   spectrum of signal(sampleRange(1):sampleRange(2)), while separately
%   reporting the mean (DC) acceleration of that segment. Also finds a
%   small number of dominant, well-separated spectral peaks and saves an
%   annotated figure.
%
%   INPUTS
%     signal       - numeric vector, the FULL original acceleration record.
%                    Only signal(sampleRange(1):sampleRange(2)) is read;
%                    it is never modified and never copied in full.
%     sampleRange  - [startSample, endSample], 1-based integer sample
%                    indices into signal, with endSample >= startSample.
%     Fs           - sampling frequency in Hz, Fs > 0.
%     signalName   - short descriptive string used in the plot title and
%                    in the saved filename (e.g. 'motor_Z').
%     outputFolder - folder where the .png/.fig files are written. It is
%                    created if it does not already exist. This function
%                    never changes MATLAB's current working directory.
%     unitsLabel   - (optional) string with the physical units of signal,
%                    used only for axis/annotation labels, since a plain
%                    numeric vector carries no unit information itself.
%                    Default: 'm/s^2'.
%     savePng      - (optional) logical, save a .png copy of the figure.
%                    Default: true.
%     saveFig      - (optional) logical, save a MATLAB .fig copy of the
%                    figure (fully re-editable later). Default: true.
%
%   OUTPUT  result, a struct with fields:
%     frequencyHz           - one-sided frequency axis, 0 ... Fs/2 (Hz)
%     amplitudeSpectrum     - one-sided, coherent-gain-corrected amplitude
%                             spectrum, same units as signal
%     meanAcceleration      - mean of the selected segment BEFORE the FFT
%                             (the DC/static component, same units as signal)
%     frequencyResolutionHz - Fs / N, the FFT bin spacing (Hz)
%     sampleCount           - N, number of samples analyzed
%     sampleRange           - the validated [startSample, endSample] used
%     peakFrequenciesHz     - frequencies of the detected dominant peaks
%     peakAmplitudes        - corresponding one-sided amplitudes
%
%   EXAMPLE
%     result = analyzeAccelFFT(accelZ, [150001 220000], 2000, ...
%                               'motor_Z', 'results/fft_plots');

    % ---------------------------------------------------------------
    % 0. Handle optional inputs
    % ---------------------------------------------------------------
    if nargin < 6 || isempty(unitsLabel)
        unitsLabel = 'm/s^2';
    end
    if nargin < 7 || isempty(savePng)
        savePng = true;
    end
    if nargin < 8 || isempty(saveFig)
        saveFig = true;
    end

    % Peak detection settings live in DEFINE.m so they can be changed
    % without editing the FFT calculation itself.
    D = DEFINE();

    % ---------------------------------------------------------------
    % 1. Validate inputs. An invalid range is an ERROR, not something to
    %    silently "fix" -- silently changing it could make you analyze
    %    the wrong part of a recording without noticing.
    % ---------------------------------------------------------------
    if ~isnumeric(signal) || ~isvector(signal)
        error('analyzeAccelFFT:InvalidSignal', 'signal must be a numeric vector.');
    end
    if ~(isnumeric(Fs) && isscalar(Fs) && Fs > 0)
        error('analyzeAccelFFT:InvalidFs', 'Fs must be a positive scalar.');
    end
    if ~(isnumeric(sampleRange) && numel(sampleRange) == 2)
        error('analyzeAccelFFT:InvalidRange', 'sampleRange must be [startSample, endSample].');
    end

    startSample = sampleRange(1);
    endSample   = sampleRange(2);

    if startSample ~= round(startSample) || endSample ~= round(endSample)
        error('analyzeAccelFFT:NonIntegerRange', 'sampleRange indices must be integers.');
    end
    if startSample < 1 || endSample > numel(signal)
        error('analyzeAccelFFT:RangeOutOfBounds', 'sampleRange must lie within the bounds of signal.');
    end
    if endSample < startSample
        error('analyzeAccelFFT:InvalidOrder', 'endSample must be >= startSample.');
    end

    N = endSample - startSample + 1;
    minSamplesRequired = 8; % below this, frequency content is not meaningful
    if N < minSamplesRequired
        error('analyzeAccelFFT:RangeTooShort', ...
            'Selected range has only %d samples; need at least %d for a meaningful FFT.', ...
            N, minSamplesRequired);
    end

    % ---------------------------------------------------------------
    % 2. Extract ONLY the requested segment. This is the only copy made
    %    of any part of "signal"; the original vector is left untouched.
    % ---------------------------------------------------------------
    segment = signal(startSample:endSample);
    segment = segment(:); % force a column vector for consistent math below

    if any(isnan(segment)) || any(isinf(segment))
        error('analyzeAccelFFT:InvalidValues', 'Selected samples contain NaN or Inf.');
    end

    % ---------------------------------------------------------------
    % 3. DC / mean handling.
    %
    % An accelerometer axis aligned with gravity can have a mean near
    % +-9.81 m/s^2. That is real, physically meaningful information
    % (roughly, static orientation) -- not noise -- so it is not simply
    % discarded. It is stored separately as meanAcceleration, and only
    % removed before computing the FFT of the OSCILLATORY content.
    %
    % If the raw (non-zero-mean) segment were fed into the FFT instead,
    % nearly all of its energy would collapse into one huge bin at 0 Hz,
    % which would dominate the plot's y-axis and make the genuinely
    % interesting vibration peaks nearly invisible next to it. Removing
    % the mean first, and reporting it separately, keeps both pieces of
    % information visible and readable.
    % ---------------------------------------------------------------
    meanAcceleration = mean(segment);
    segmentZeroMean  = segment - meanAcceleration;

    % ---------------------------------------------------------------
    % 4. Hann window (spectral leakage reduction).
    %
    % Spectral leakage: the FFT implicitly assumes the analyzed segment
    % repeats periodically forever. If a real sinusoid does not complete
    % an exact whole number of cycles within the segment, that assumed
    % periodic repetition has a discontinuity at the segment edges. The
    % discontinuity's energy "leaks" into many neighboring frequency
    % bins instead of staying in one clean bin, smearing and lowering
    % the apparent peak.
    %
    % A window function such as Hann tapers the segment smoothly to zero
    % at both ends, removing that artificial discontinuity and greatly
    % reducing leakage, at the cost of a slightly wider main lobe.
    %
    % Windowing also reduces the segment's average amplitude (most
    % samples are multiplied by something less than 1), so the raw
    % windowed-FFT amplitude must be corrected afterward to stay
    % physically meaningful -- see coherentGain below.
    %
    % No toolbox is used: the Hann window is built directly from its
    % definition, w(n) = 0.5 - 0.5*cos(2*pi*n/(N-1)), n = 0..N-1.
    % ---------------------------------------------------------------
    n = (0:N-1)';
    hannWindow = 0.5 - 0.5 * cos(2 * pi * n / (N - 1));

    % Coherent gain = the window's average value. Dividing the spectrum
    % by it later undoes the window's attenuation, so a stationary
    % sinusoid's corrected peak approximates its true amplitude.
    coherentGain = mean(hannWindow);

    windowedSegment = segmentZeroMean .* hannWindow;

    % ---------------------------------------------------------------
    % 5. FFT.
    %
    % No zero-padding is used: zero-padding can only interpolate
    % (visually smooth) the spectrum between existing bins, it cannot
    % add real frequency resolution. True resolution is set solely by
    % the analyzed duration: df = Fs / N.
    % ---------------------------------------------------------------
    fftResult = fft(windowedSegment); % O(N log N), operates only on this segment
    df = Fs / N;                      % frequency-bin spacing

    % ---------------------------------------------------------------
    % 6. Build the one-sided spectrum.
    %
    % fft() returns N complex values covering 0 Hz up to just under Fs
    % Hz; for a real input this is symmetric about Fs/2. All physically
    % new information is in the first half, so the second half (mirror
    % image) is discarded here -- but its energy must be folded back
    % into the kept bins (the "x2" in step 7), or amplitudes would read
    % half their true physical value.
    %
    % Two bins never have a distinct mirror partner and must NOT be
    % doubled: the DC bin (0 Hz), and -- only when N is even -- the
    % Nyquist bin (Fs/2). Odd-length segments have no exact Nyquist bin.
    % ---------------------------------------------------------------
    if mod(N, 2) == 0
        numUniquePoints = N/2 + 1;  % bins: 0, df, 2df, ..., Fs/2 (Nyquist included)
    else
        numUniquePoints = (N+1)/2;  % odd N has no exact Nyquist bin
    end

    frequencyHz = (0:numUniquePoints-1)' * df;
    oneSidedFFT = fftResult(1:numUniquePoints);

    % ---------------------------------------------------------------
    % 7. Convert to a physically-scaled one-sided amplitude spectrum.
    %
    % Base (unwindowed) one-sided amplitude of a bin is |X(k)|/N for the
    % DC bin (and the Nyquist bin, if present), and 2*|X(k)|/N for every
    % other bin, because those bins' energy is split with their
    % now-discarded mirror partner. Finally, dividing by coherentGain
    % undoes the Hann window's amplitude loss from step 4.
    % ---------------------------------------------------------------
    amplitudeSpectrum = abs(oneSidedFFT) / N;

    if mod(N, 2) == 0
        amplitudeSpectrum(2:end-1) = 2 * amplitudeSpectrum(2:end-1); % skip DC and Nyquist
    else
        amplitudeSpectrum(2:end)   = 2 * amplitudeSpectrum(2:end);   % skip DC only
    end

    amplitudeSpectrum = amplitudeSpectrum / coherentGain;

    % ---------------------------------------------------------------
    % 8. Detect prominent spectral peaks on the positive-frequency,
    %    one-sided FFT amplitude spectrum only.
    %
    % Peak detection is deliberately kept in the FFT calculation result,
    % while any later labeling on the plot is a separate display concern.
    % ---------------------------------------------------------------
    peaks = detectFFTPeaks(frequencyHz, amplitudeSpectrum, D);

    % ---------------------------------------------------------------
    % 9. Assemble the output structure.
    % ---------------------------------------------------------------
    result.frequencyHz           = frequencyHz;
    result.amplitudeSpectrum     = amplitudeSpectrum;
    result.meanAcceleration      = meanAcceleration;
    result.frequencyResolutionHz = df;
    result.sampleCount           = N;
    result.sampleRange           = [startSample, endSample];
    result.peaks                 = peaks;
    result.peakFrequenciesHz     = peaks.frequencyHz;
    result.peakAmplitudes        = peaks.amplitude;

    % ---------------------------------------------------------------
    % 10. Plot. Linear y-axis by design, so peak heights stay directly
    %     readable in physical acceleration units. (If you later want
    %     to see small peaks buried under large ones, a log-scale y-axis
    %     -- e.g. set(gca,'YScale','log') on the returned figure, or a
    %     dB plot -- can help, but it is not the primary output here
    %     because it distorts the direct "peak height = amplitude"
    %     reading you asked for.)
    % ---------------------------------------------------------------
    fig = figure('Visible', 'on');
    plot(frequencyHz, amplitudeSpectrum, 'b-', 'LineWidth', 1);
    hold on;
    if isfield(peaks, 'enabled') && peaks.enabled && ~isempty(peaks.frequencyHz)
        markerStyle = 'rv';
        plot(peaks.frequencyHz, peaks.amplitude, markerStyle, 'MarkerFaceColor', 'r', 'MarkerSize', 6);
        for k = 1:numel(peaks.frequencyHz)
            peakFreq = peaks.frequencyHz(k);
            peakAmp  = peaks.amplitude(k);
            labelText = sprintf('%.2f Hz\n%.3g %s', peakFreq, peakAmp, unitsLabel);
            text(peakFreq, peakAmp, labelText, ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'bottom', ...
                'FontSize', 8, ...
                'Interpreter', 'none');
        end
    end
    hold off;
    grid on;
    xlabel('Frequency (Hz)');
    ylabel(sprintf('Acceleration amplitude (%s)', unitsLabel));

    titleStr = sprintf('One-sided FFT: %s (samples %d-%d)', signalName, startSample, endSample);
    subtitleStr = sprintf('Mean acceleration removed before FFT: %.4g %s    |    df = %.4g Hz', ...
        meanAcceleration, unitsLabel, df);
    title({titleStr, subtitleStr}, 'Interpreter', 'none');

    % ---------------------------------------------------------------
    % 11. Save the figure without touching MATLAB's current folder.
    % ---------------------------------------------------------------
    if ~exist(outputFolder, 'dir')
        mkdir(outputFolder);
    end
    safeName     = sanitizeFileName(signalName);
    baseFileName = sprintf('FFT_%s_samples_%d_%d', safeName, startSample, endSample);

    if savePng
        print(fig, fullfile(outputFolder, [baseFileName '.png']), '-dpng', '-r150');
    end
    if saveFig
        savefig(fig, fullfile(outputFolder, [baseFileName '.fig']));
    end
end

% ===================================================================
% Local helper functions. These are only ever called by analyzeAccelFFT
% above; MATLAB calls this a "local function", and it is the normal way
% to keep a single callable function's helper logic in one file rather
% than scattering small private helpers across several files.
% ===================================================================

function peaks = detectFFTPeaks(frequencyHz, amplitudeSpectrum, D)
    peaks = struct('enabled', false, 'frequencyHz', [], 'amplitude', [], 'prominence', []);

    if nargin < 3 || isempty(D)
        D = DEFINE();
    end

    if ~isfield(D, 'FFT_MARK_PEAKS') || isempty(D.FFT_MARK_PEAKS) || ~D.FFT_MARK_PEAKS
        return;
    end

    minProminence = 0.01;
    if isfield(D, 'FFT_MIN_PEAK_PROMINENCE') && ~isempty(D.FFT_MIN_PEAK_PROMINENCE)
        minProminence = D.FFT_MIN_PEAK_PROMINENCE;
    end

    maxPeaks = 10;
    if isfield(D, 'FFT_MAX_PEAKS') && ~isempty(D.FFT_MAX_PEAKS)
        maxPeaks = D.FFT_MAX_PEAKS;
    end
    maxPeaks = max(0, round(maxPeaks));

    positiveMask = frequencyHz > 0;
    positiveFreq = frequencyHz(positiveMask);
    positiveAmp  = amplitudeSpectrum(positiveMask);

    if isempty(positiveFreq) || numel(positiveFreq) < 3
        peaks.enabled = true;
        return;
    end

    try
        [peakAmp, peakFreq, ~, peakProm] = findpeaks(positiveAmp, positiveFreq, ...
            'MinPeakProminence', max(0, minProminence), 'SortStr', 'descend');
        usedFallback = false;
    catch
        [peakAmp, peakFreq, peakProm] = fallbackFindPeaks(positiveFreq, positiveAmp, minProminence);
        usedFallback = true;
    end

    if isempty(peakAmp)
        peaks.enabled = true;
        return;
    end

    if maxPeaks == 0
        peaks.enabled = true;
        peaks.frequencyHz = [];
        peaks.amplitude = [];
        peaks.prominence = [];
        return;
    end

    keepCount = min(numel(peakAmp), maxPeaks);
    selectedAmp = peakAmp(1:keepCount);
    selectedFreq = peakFreq(1:keepCount);
    if ~usedFallback && numel(peakProm) >= keepCount
        selectedProm = peakProm(1:keepCount);
    else
        selectedProm = zeros(keepCount, 1);
        selectedProm(:) = NaN;
    end

    [selectedFreq, sortOrder] = sort(selectedFreq, 'ascend');
    selectedAmp = selectedAmp(sortOrder);
    selectedProm = selectedProm(sortOrder);

    peaks.enabled = true;
    peaks.frequencyHz = selectedFreq(:);
    peaks.amplitude = selectedAmp(:);
    peaks.prominence = selectedProm(:);
end

function [peakAmp, peakFreq, peakProm] = fallbackFindPeaks(frequencyHz, amplitudeSpectrum, minProminence)
    n = numel(amplitudeSpectrum);
    if n < 3
        peakAmp = [];
        peakFreq = [];
        peakProm = [];
        return;
    end

    isPeak = false(n, 1);
    isPeak(2:end-1) = amplitudeSpectrum(2:end-1) > amplitudeSpectrum(1:end-2) & ...
        amplitudeSpectrum(2:end-1) >= amplitudeSpectrum(3:end);

    idx = find(isPeak);
    if isempty(idx)
        peakAmp = [];
        peakFreq = [];
        peakProm = [];
        return;
    end

    peakAmp = amplitudeSpectrum(idx);
    peakFreq = frequencyHz(idx);

    localRef = zeros(numel(idx), 1);
    for k = 1:numel(idx)
        thisIdx = idx(k);
        leftBase = amplitudeSpectrum(max(1, thisIdx - 1));
        rightBase = amplitudeSpectrum(min(numel(amplitudeSpectrum), thisIdx + 1));
        baseVal = max(leftBase, rightBase);
        localRef(k) = peakAmp(k) - baseVal;
    end

    valid = peakAmp > 0 & localRef >= max(0, minProminence);
    peakAmp = peakAmp(valid);
    peakFreq = peakFreq(valid);
    peakProm = localRef(valid);

    if isempty(peakAmp)
        peakProm = [];
        return;
    end

    [peakAmp, order] = sort(peakAmp, 'descend');
    peakFreq = peakFreq(order);
    peakProm = peakProm(order);
end

function cleanName = sanitizeFileName(rawName)
    % Replace anything that is not a letter, digit, underscore or hyphen
    % with an underscore, so the string is always a safe filename.
    cleanName = regexprep(rawName, '[^a-zA-Z0-9_-]', '_');
    if isempty(cleanName)
        cleanName = 'signal';
    end
end

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

    % These two constants control the (deliberately simple) peak
    % detector. They live here, at the top, so they are easy to find
    % and tune without hunting through the rest of the function.
    numPeaksToReport      = 5;  % how many dominant peaks to keep
    minPeakSeparationBins = 3;  % minimum bin spacing between reported peaks

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
    % 8. Dominant peak detection (simple and transparent by design).
    %
    % A bin is a peak candidate if it is strictly larger than both of
    % its immediate neighbors (a local maximum). The DC bin is excluded,
    % since it does not represent an oscillation.
    %
    % A single physical spectral peak is normally spread across several
    % adjacent bins (its main lobe, widened further by the Hann window).
    % To avoid reporting several neighboring bins of that same lobe as
    % if they were independent "dominant frequencies", candidates are
    % ranked by amplitude and accepted greedily, skipping any candidate
    % that falls within minPeakSeparationBins of a peak already kept.
    % This is a standard, simple non-maximum-suppression rule.
    % ---------------------------------------------------------------
    [peakFrequenciesHz, peakAmplitudes] = findDominantPeaks( ...
        amplitudeSpectrum, frequencyHz, numPeaksToReport, minPeakSeparationBins);

    % ---------------------------------------------------------------
    % 9. Assemble the output structure.
    % ---------------------------------------------------------------
    result.frequencyHz           = frequencyHz;
    result.amplitudeSpectrum     = amplitudeSpectrum;
    result.meanAcceleration      = meanAcceleration;
    result.frequencyResolutionHz = df;
    result.sampleCount           = N;
    result.sampleRange           = [startSample, endSample];
    result.peakFrequenciesHz     = peakFrequenciesHz;
    result.peakAmplitudes        = peakAmplitudes;

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
    plot(peakFrequenciesHz, peakAmplitudes, 'rv', 'MarkerFaceColor', 'r');
    for k = 1:numel(peakFrequenciesHz)
        text(peakFrequenciesHz(k), peakAmplitudes(k), ...
            sprintf('  %.2f Hz', peakFrequenciesHz(k)), ...
            'VerticalAlignment', 'bottom', 'FontSize', 8);
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

function [peakFreqs, peakAmps] = findDominantPeaks(amplitudeSpectrum, frequencyHz, numPeaksToReport, minSeparationBins)
    numBins = numel(amplitudeSpectrum);

    % Vectorized local-maximum test over interior bins (2 .. numBins-1),
    % which automatically excludes the DC bin (index 1).
    isLocalMax = false(numBins, 1);
    if numBins >= 3
        isLocalMax(2:end-1) = amplitudeSpectrum(2:end-1) > amplitudeSpectrum(1:end-2) & ...
                               amplitudeSpectrum(2:end-1) > amplitudeSpectrum(3:end);
    end
    candidateIdx = find(isLocalMax);

    if isempty(candidateIdx)
        peakFreqs = [];
        peakAmps  = [];
        return;
    end

    % Rank candidates by amplitude, strongest first.
    [~, order]   = sort(amplitudeSpectrum(candidateIdx), 'descend');
    candidateIdx = candidateIdx(order);

    % Greedily accept peaks, skipping any candidate too close (in bin
    % index) to one already accepted -- this prevents several bins of
    % the same broadened lobe from being reported as separate peaks.
    selectedIdx = [];
    for k = 1:numel(candidateIdx)
        idx = candidateIdx(k);
        if isempty(selectedIdx) || all(abs(selectedIdx - idx) > minSeparationBins)
            selectedIdx(end+1) = idx; %#ok<AGROW>
        end
        if numel(selectedIdx) >= numPeaksToReport
            break;
        end
    end

    % Report in increasing-frequency order for a readable plot/output.
    selectedIdx = sort(selectedIdx);
    peakFreqs   = frequencyHz(selectedIdx);
    peakAmps    = amplitudeSpectrum(selectedIdx);
end

function cleanName = sanitizeFileName(rawName)
    % Replace anything that is not a letter, digit, underscore or hyphen
    % with an underscore, so the string is always a safe filename.
    cleanName = regexprep(rawName, '[^a-zA-Z0-9_-]', '_');
    if isempty(cleanName)
        cleanName = 'signal';
    end
end

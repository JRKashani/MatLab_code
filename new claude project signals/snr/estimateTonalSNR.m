function result = estimateTonalSNR(signal, sampleRange, Fs, options)
%ESTIMATETONALSNR Blind short-time tonal SNR against a flat white-noise floor.
%   options: windowSec, overlapFraction, minPeakAboveNoiseDb, maxTones,
%   minTrackFrames, maxDriftHzPerSec. Defaults are SNR_* fields in DEFINE.
%
%   Hann-windowed one-sided periodograms detect peaks above a robust initial
%   noise floor. The median/log(2) initializer assumes approximately complex
%   Gaussian interior Fourier coefficients (exact asymptotically for Gaussian
%   white noise). Final noise power uses the MEAN of non-tonal PSD bins,
%   extrapolated over 0 ... Fs/2, including the noise underneath the tones.
%   Tone power integrates its spectral band and subtracts expected noise.
%   Nearby peaks are linked through time; short unconfirmed tracks are dropped.
%
%   Limits: requires sparse, resolved tones and a broadband white background.
%   Frequencies within four window bins of DC/Nyquist are not resolved as
%   tones. Fast sweeps, crossing/unresolved tones, broadband disturbances and
%   colored noise cannot be uniquely separated by this model. Below-threshold
%   tones are not recovered. Local amplitudes are Hann-weighted RMS-equivalent
%   sine amplitudes, and overall powers are time-weighted frame estimates.

    if nargin < 4 || isempty(options), options = struct(); end
    if nargin < 2, sampleRange = []; end
    [x, sampleRange] = selectSignalSegment(signal, sampleRange, Fs, 64);
    D = DEFINE();
    settings = struct('windowSec', D.SNR_WINDOW_SEC, ...
        'overlapFraction', D.SNR_OVERLAP_FRACTION, ...
        'minPeakAboveNoiseDb', D.SNR_MIN_PEAK_ABOVE_NOISE_DB, ...
        'maxTones', D.SNR_MAX_TONES, 'minTrackFrames', D.SNR_MIN_TRACK_FRAMES, ...
        'maxDriftHzPerSec', D.SNR_MAX_DRIFT_HZ_PER_SEC);
    names = fieldnames(settings);
    for k = 1:numel(names)
        if isfield(options, names{k}) && ~isempty(options.(names{k}))
            settings.(names{k}) = options.(names{k});
        end
    end
    validateattributes(settings.windowSec, {'numeric'}, {'scalar','real','finite','positive'});
    validateattributes(settings.overlapFraction, {'numeric'}, {'scalar','real','finite','>=',0,'<',1});
    validateattributes(settings.minPeakAboveNoiseDb, {'numeric'}, {'scalar','real','finite','positive'});
    validateattributes(settings.maxTones, {'numeric'}, {'scalar','integer','positive','finite'});
    validateattributes(settings.minTrackFrames, {'numeric'}, {'scalar','integer','positive','finite'});
    validateattributes(settings.maxDriftHzPerSec, {'numeric'}, {'scalar','real','finite','nonnegative'});

    N = numel(x);
    L = min(N, max(64, round(settings.windowSec * Fs)));
    hop = max(1, round(L * (1 - settings.overlapFraction)));
    starts = unique([1:hop:N-L+1, N-L+1]);
    frameCount = numel(starts);
    centers = starts(:) + (L - 1)/2;
    time = (sampleRange(1) + centers - 2) / Fs;
    % Midpoint cells account for the final nonuniform hop and sum to duration.
    edges = [0; (centers(1:end-1) + centers(2:end) - 2)/(2*Fs); N/Fs];
    weights = diff(edges) / (N/Fs);
    nfft = 2^nextpow2(L);
    df = Fs/nfft;
    f = (0:nfft/2)' * df;
    resolutionHz = Fs/L;
    guard = ceil(3 * resolutionHz / df);
    interior = f >= 4*resolutionHz & f <= Fs/2 - 4*resolutionHz;
    window = hannWindowManual(L);
    spectra = zeros(numel(f), frameCount);
    candidates = cell(frameCount, 1);

    for j = 1:frameCount
        frame = x(starts(j):starts(j)+L-1);
        frame = frame - mean(frame);
        p = computePeriodogramPSD(frame, Fs, window, nfft);
        spectra(:,j) = p;
        floorPSD = median(p(interior)) / log(2);
        % Do not promote numerical roundoff to meaningful peaks.
        floorPSD = max(floorPSD, max(p) * 1e-12);
        candidate = emptyCandidates();
        if any(p > 0)
            idx = find(islocalmax(p) & interior & ...
                p > floorPSD * 10^(settings.minPeakAboveNoiseDb/10));
            [~, order] = sort(p(idx), 'descend');
            selected = [];
            for a = order(:).'
                q = idx(a);
                if isempty(selected) || all(abs(q - selected) > 2*guard)
                    selected(end+1) = q; %#ok<AGROW>
                    if numel(selected) == settings.maxTones, break; end
                end
            end
            selected = sort(selected);
            for a = 1:numel(selected)
                q = selected(a);
                lower = max(2, q-guard);
                upper = min(numel(f)-1, q+guard);
                % Expand broad lobes caused by within-window frequency drift.
                leftLimit = 2;
                rightLimit = numel(f)-1;
                if a > 1, leftLimit = floor((selected(a-1)+q)/2)+1; end
                if a < numel(selected), rightLimit = floor((q+selected(a+1))/2); end
                while lower > leftLimit && p(lower-1) > 3*floorPSD, lower = lower-1; end
                while upper < rightLimit && p(upper+1) > 3*floorPSD, upper = upper+1; end
                % Log-parabolic interpolation reduces FFT grid quantization.
                v = log(max(p(q-1:q+1), realmin));
                denominator = v(1)-2*v(2)+v(3);
                delta = 0;
                if denominator < 0
                    delta = max(-0.5, min(0.5, 0.5*(v(1)-v(3))/denominator));
                end
                candidate(end+1) = struct('frequencyHz', f(q)+delta*df, ...
                    'firstBin', lower, 'lastBin', upper); %#ok<AGROW>
            end
        end
        candidates{j} = candidate;
    end

    tracks = linkTracks(candidates, time, settings, resolutionHz);
    requiredFrames = min(settings.minTrackFrames, frameCount);
    if ~isempty(tracks)
        keep = arrayfun(@(t) numel(t.frameIndices) >= requiredFrames, tracks);
        tracks = tracks(keep);
    end
    trackCount = numel(tracks);
    owners = zeros(size(spectra));
    frequencySeries = NaN(frameCount, trackCount);
    for k = 1:trackCount
        for a = 1:numel(tracks(k).frameIndices)
            j = tracks(k).frameIndices(a);
            candidate = candidates{j}(tracks(k).candidateIndices(a));
            bins = candidate.firstBin:candidate.lastBin;
            owners(bins,j) = k;
            frequencySeries(j,k) = candidate.frequencyHz;
        end
    end

    noisePSD = zeros(frameCount, 1);
    cleanFraction = zeros(frameCount, 1);
    tonePower = zeros(frameCount, trackCount);
    bandRatios = NaN(frameCount, 1);
    for j = 1:frameCount
        clean = interior & owners(:,j) == 0;
        cleanFraction(j) = nnz(clean)/nnz(interior);
        if cleanFraction(j) < 0.25
            noisePSD(j) = NaN;
            tonePower(j,:) = NaN;
            continue;
        end
        noisePSD(j) = mean(spectra(clean,j));
        for k = 1:trackCount
            bins = owners(:,j) == k;
            tonePower(j,k) = max(0, (sum(spectra(bins,j)) - noisePSD(j)*nnz(bins))*df);
        end
        % A simple model-fit diagnostic, not a proof of statistical whiteness.
        bands = NaN(4,1);
        for b = 1:4
            mask = clean & f >= (b-1)*Fs/8 & f < b*Fs/8;
            if nnz(mask) >= 4, bands(b) = mean(spectra(mask,j)); end
        end
        validBands = bands(isfinite(bands) & bands > 0);
        if numel(validBands) == 4, bandRatios(j) = max(validBands)/min(validBands); end
    end
    noisePower = noisePSD * (Fs/2);
    signalPower = sum(tonePower, 2);
    averageNoisePower = sum(weights .* noisePower);
    averageTonePower = sum(weights .* tonePower, 1);
    averageSignalPower = sum(averageTonePower);
    notes = {};
    if any(cleanFraction < 0.25)
        status = 'insufficient_noise_bins';
        notes{end+1} = 'Too little tone-free bandwidth to estimate white noise reliably.';
    elseif ~any(spectra(:) > 0)
        status = 'no_ac_power';
        notes{end+1} = 'The selected signal is constant; SNR is undefined.';
    elseif trackCount == 0
        status = 'no_tones_detected';
        notes{end+1} = 'No persistent resolved tones passed the threshold; this is not proof of their absence.';
    else
        status = 'ok';
    end
    finiteRatios = bandRatios(isfinite(bandRatios));
    if ~isempty(finiteRatios) && median(finiteRatios) > 4
        notes{end+1} = 'Background power varies by more than 6 dB across broad bands; the white-noise assumption may not hold.';
    end
    if frameCount < settings.minTrackFrames
        notes{end+1} = 'Short recording: persistence was checked over fewer frames than requested.';
    end
    for k = 1:trackCount
        detected = isfinite(frequencySeries(:,k));
        tracks(k).id = k;
        tracks(k).time = time;
        tracks(k).frequencyHz = frequencySeries(:,k);
        tracks(k).power = tonePower(:,k);
        tracks(k).rms = sqrt(tonePower(:,k));
        tracks(k).amplitude = sqrt(2*tonePower(:,k));
        tracks(k).amplitude(~detected) = NaN;
        tracks(k).snrDb = powerRatioDb(tonePower(:,k), noisePower);
        tracks(k).meanPower = averageTonePower(k);
        tracks(k).meanFrequencyHz = sum(weights(detected).*frequencySeries(detected,k))/sum(weights(detected));
        tracks(k).frequencyRangeHz = [min(frequencySeries(detected,k)), max(frequencySeries(detected,k))];
        tracks(k).overallSNRdB = powerRatioDb(averageTonePower(k), averageNoisePower);
    end
    settings.actualWindowSec = L/Fs;
    settings.windowSamples = L;
    settings.hopSamples = hop;
    settings.nfft = nfft;
    settings.resolutionHz = resolutionHz;
    settings.minimumResolvableFrequencyHz = 4*resolutionHz;
    result = struct('status', status, 'sampleRange', sampleRange, 'sampleCount', N, ...
        'Fs', Fs, 'meanRemoved', mean(x), 'noiseBandHz', [0 Fs/2], ...
        'settings', settings, 'overallSNRdB', powerRatioDb(averageSignalPower, averageNoisePower), ...
        'signalPower', averageSignalPower, 'signalRMS', sqrt(averageSignalPower), ...
        'noisePower', averageNoisePower, 'noiseRMS', sqrt(averageNoisePower), ...
        'whiteNoisePSD', averageNoisePower/(Fs/2), 'tracks', tracks, ...
        'peakFrequenciesHz', [tracks.meanFrequencyHz], 'peakSNRdB', [tracks.overallSNRdB], ...
        'notes', {notes});
    result.frames = struct('time', time, 'startSample', sampleRange(1)+starts(:)-1, ...
        'weights', weights, 'signalPower', signalPower, 'noisePower', noisePower, ...
        'noiseRMS', sqrt(noisePower), 'snrDb', powerRatioDb(signalPower, noisePower), ...
        'noisePSD', noisePSD, 'toneFreeFraction', cleanFraction);
    result.frequencyHz = f;
    result.meanPSD = spectra * weights;
end

function candidates = emptyCandidates()
    candidates = struct('frequencyHz', {}, 'firstBin', {}, 'lastBin', {});
end

function tracks = linkTracks(candidates, time, settings, resolutionHz)
    tracks = struct('frameIndices', {}, 'candidateIndices', {}, 'detectedFrequencyHz', {}, ...
        'meanFrequencyHz', {}, 'overallSNRdB', {});
    for j = 1:numel(candidates)
        current = candidates{j};
        assigned = false(1,numel(current));
        costs = Inf(numel(tracks),numel(current));
        for k = 1:numel(tracks)
            previous = tracks(k).frameIndices(end);
            if j - previous > 2, continue; end
            dt = time(j)-time(previous);
            prediction = tracks(k).detectedFrequencyHz(end);
            if numel(tracks(k).frameIndices) >= 2
                earlier = tracks(k).frameIndices(end-1);
                slope = diff(tracks(k).detectedFrequencyHz(end-1:end))/(time(previous)-time(earlier));
                slope = max(-settings.maxDriftHzPerSec, min(settings.maxDriftHzPerSec, slope));
                prediction = prediction + slope*dt;
            end
            tolerance = 2*resolutionHz + settings.maxDriftHzPerSec*dt;
            for a = 1:numel(current)
                distance = abs(current(a).frequencyHz-prediction);
                if distance <= tolerance, costs(k,a) = distance; end
            end
        end
        while ~isempty(costs)
            [value,index] = min(costs(:));
            if ~isfinite(value), break; end
            [k,a] = ind2sub(size(costs),index);
            tracks(k).frameIndices(end+1) = j;
            tracks(k).candidateIndices(end+1) = a;
            tracks(k).detectedFrequencyHz(end+1) = current(a).frequencyHz;
            assigned(a) = true;
            costs(k,:) = Inf;
            costs(:,a) = Inf;
        end
        for a = find(~assigned)
            tracks(end+1) = struct('frameIndices', j, 'candidateIndices', a, ...
                'detectedFrequencyHz', current(a).frequencyHz, ...
                'meanFrequencyHz', [], 'overallSNRdB', []); %#ok<AGROW>
        end
    end
end

function value = powerRatioDb(signalPower, noisePower)
    value = 10*log10(signalPower ./ noisePower);
    value(signalPower == 0 & noisePower == 0) = NaN;
end

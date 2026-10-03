function result = computeVariableWelchPSD(signal, sampleRange, Fs, peakFrequenciesHz, options)
%COMPUTEVARIABLEWELCHPSD Fine peak-band and coarse background Welch estimates.
%   Fine Hann windows are resolutionRatio times longer; nfft equals window
%   length. Both use the same overlap fraction. This piecewise PSD switches
%   methods abruptly; its integral need not equal a uniform Welch estimate.
    if nargin < 5, options = struct(); end
    D = DEFINE();
    ratio = getOption(options, 'resolutionRatio', D.WELCH_VARIABLE_RESOLUTION_RATIO);
    target = getOption(options, 'coarseWindowSamples', D.WELCH_VARIABLE_COARSE_WINDOW_SAMPLES);
    fraction = getOption(options, 'overlapFraction', D.WELCH_VARIABLE_OVERLAP_FRACTION);
    fixedHz = getOption(options, 'surroundHz', D.WELCH_PEAK_SURROUND_HZ);
    percent = getOption(options, 'surroundPercent', D.WELCH_PEAK_SURROUND_PERCENT);
    validateattributes(ratio, {'numeric'}, {'scalar','integer','finite','>=',2});
    if log2(ratio) ~= floor(log2(ratio))
        error('computeVariableWelchPSD:invalidRatio', 'resolutionRatio must be a power of two.');
    end
    validateattributes(target, {'numeric'}, {'scalar','integer','finite','>=',4});
    validateattributes(fraction, {'numeric'}, {'scalar','real','finite','>=',0,'<',1});
    [x, sampleRange] = selectSignalSegment(signal, sampleRange, Fs, 4*ratio);
    meanRemoved = mean(x);
    x = x - meanRemoved;
    % Round down to fit the record while retaining power-of-two window/FFT
    % lengths and an exact power-of-two resolution ratio.
    coarseLength = 2^floor(log2(min(target, floor(numel(x)/ratio))));
    fineLength = ratio*coarseLength;
    bands = peakFrequencyBands(peakFrequenciesHz, Fs, fixedHz, percent);
    mergedBands = mergeBands(bands.rangesHz);
    coarse = estimate(x, Fs, coarseLength, fraction);
    fine = struct();
    if isempty(mergedBands)
        f = coarse.f;
        p = coarse.psd;
        fineMask = false(size(f));
    else
        fine = estimate(x, Fs, fineLength, fraction);
        coarseMask = insideBands(coarse.f, mergedBands);
        fineMask = insideBands(fine.f, mergedBands);
        % Include exact boundaries; interpolate only to place those points.
        f = unique([coarse.f(~coarseMask); fine.f(fineMask); mergedBands(:)]);
        fineMask = insideBands(f, mergedBands);
        p = zeros(size(f));
        p(~fineMask) = interp1(coarse.f, coarse.psd, f(~fineMask), 'linear');
        p(fineMask) = interp1(fine.f, fine.psd, f(fineMask), 'linear');
    end
    transitions = unique(mergedBands(:));
    transitions = transitions(transitions > 0 & transitions < Fs/2);
    resolutionHz = repmat(Fs/coarseLength, size(f));
    resolutionHz(fineMask) = Fs/fineLength;
    % Frequency spacing changes at band boundaries: integrate the actual
    % displayed composite coordinates, not a single assumed bin width.
    result = struct('f', f, 'psd', p, 'integratedPower', trapz(f, p), 'Fs', Fs, 'sampleRange', sampleRange, ...
        'sampleCount', numel(x), 'meanRemoved', meanRemoved, ...
        'peakFrequenciesHz', bands.peakFrequenciesHz, 'peakNeighborhoods', bands, ...
        'fineBandsHz', mergedBands, 'transitionFrequenciesHz', transitions, ...
        'isFineResolution', fineMask, 'resolutionHz', resolutionHz, ...
        'coarseResolutionHz', Fs/coarseLength, 'fineResolutionHz', Fs/fineLength, ...
        'resolutionRatio', ratio, 'coarseWindowSamples', coarseLength, ...
        'fineWindowSamples', fineLength, 'overlapFraction', fraction, ...
        'coarse', coarse, 'fine', fine);
end

function curve = estimate(x, Fs, L, fraction)
    overlap = floor(fraction*L);
    [p, f] = computeWelchPSD(x, Fs, L, overlap, hannWindowManual(L), L);
    % MATLAB alternative (Signal Processing Toolbox) for each resolution:
    % [pMatlab, fMatlab] = pwelch(x, hann(L, 'symmetric'), overlap, L, Fs, 'onesided');
    % There is no single pwelch call for the frequency-dependent window
    % lengths; retain the coarse/fine band selection above with either kernel.
    curve = struct('f', f, 'psd', p, 'segmentLength', L, 'overlapSamples', overlap, ...
        'segmentCount', floor((numel(x)-L)/(L-overlap))+1, 'nfft', L);
end

function merged = mergeBands(ranges)
    ranges = sortrows(ranges, 1);
    merged = zeros(0, 2);
    for k = 1:size(ranges, 1)
        if ranges(k,2) <= ranges(k,1), continue; end
        if isempty(merged) || ranges(k,1) > merged(end,2)
            merged(end+1,:) = ranges(k,:); %#ok<AGROW>
        else
            merged(end,2) = max(merged(end,2), ranges(k,2));
        end
    end
end

function mask = insideBands(f, bands)
    mask = false(size(f));
    for k = 1:size(bands,1)
        mask = mask | (f >= bands(k,1) & f <= bands(k,2));
    end
end

function value = getOption(options, name, default)
    value = default;
    if isfield(options, name) && ~isempty(options.(name)), value = options.(name); end
end

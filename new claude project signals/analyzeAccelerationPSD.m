function result = analyzeAccelerationPSD(signal, sampleRange, Fs, options)
%ANALYZEACCELERATIONPSD  Six-way PSD comparison study for an acceleration record.
%
% SYNTAX
%   opts   = analyzeAccelerationPSD('defaults');
%   result = analyzeAccelerationPSD(signal, [startSample endSample], Fs, opts);
%
% DESCRIPTION
%   Estimates the one-sided power spectral density (PSD) of the samples
%   signal(startSample:endSample) using three methods, and produces six
%   comparison figures:
%
%       1) periodogram, different windows          leakage vs resolution
%       2) periodogram, different NFFT             zero padding
%       3) Welch,       different windows
%       4) Welch,       different segment lengths  resolution vs averaging
%       5) Welch,       different overlaps         number of averages
%       6) Burg,        different AR model orders  model-order selection
%
% UNITS  (important)
%   Every PSD stored in RESULT is LINEAR, in (acceleration unit)^2 / Hz.
%   dB is applied only for plotting, as 10*log10(PSD), i.e. dB/Hz relative
%   to 1 (acceleration unit)^2/Hz. A PSD is power per hertz -- it is NOT an
%   FFT amplitude spectrum and you cannot read a tone's amplitude off it
%   directly without accounting for the window's noise bandwidth.
%
% INPUTS
%   signal       real numeric vector (may be ~1e6 samples; only the
%                requested range is ever copied)
%   sampleRange  [startSample endSample], 1-based integer indices
%   Fs           sampling frequency [Hz], positive finite scalar
%   options      struct; see analyzeAccelerationPSD('defaults')
%
% OUTPUT
%   result.info          name, sample range, count, Fs, removed mean, duration
%   result.periodogram   .windows, .nfft
%   result.welch         .windows, .segmentLength, .overlap
%   result.burg          .order
%   result.figures       explicit figure handles (no gcf anywhere)
%   result.files         cell array of files actually written
%
% NOTES ON PARAMETER CHOICES
%   * A periodogram has 2 degrees of freedom regardless of record length,
%     so its variance does NOT shrink as N grows (std ~ 5.6 dB per bin).
%     For Figures 1 and 2, a SHORT range (1e3 .. 8e3 samples) shows window
%     and zero-padding effects far more clearly than a very long one.
%   * Zero padding (Figure 2) interpolates the spectrum. It never improves
%     the true resolution, which is Fs/N and is set by the record length.
%   * Flat-top is an amplitude-accuracy window, not a resolution window.
%   * A sharp Burg spectrum is not automatically an accurate one.
%
% REQUIRES  Signal Processing Toolbox. Tested against R2019b and later.
%           .png export uses exportgraphics when available, else print.
%
% This function never changes MATLAB's working directory.

%% ========================================================================
%  0. Setup
%  ========================================================================
if nargin == 1 && (ischar(signal) || isstring(signal)) && strcmpi(signal, 'defaults')
    result = localDefaultOptions();
    return
end

narginchk(3, 4)
if nargin < 4 || isempty(options)
    options = struct();
end

if isempty(which('pwelch'))
    error('analyzeAccelerationPSD:missingToolbox', ...
        ['The Signal Processing Toolbox is required ' ...
         '(periodogram / pwelch / pburg / window functions).']);
end

opts = localMergeStruct(localDefaultOptions(), options, 'options');

%% ========================================================================
%  1. Validation of signal, range and Fs
%  ========================================================================
if ~(isnumeric(Fs) && isscalar(Fs) && isreal(Fs) && isfinite(Fs) && Fs > 0)
    error('analyzeAccelerationPSD:badFs', ...
        'Fs must be a real, finite, positive scalar [Hz].');
end
Fs = double(Fs);

if ~(isnumeric(signal) && isreal(signal) && isvector(signal))
    error('analyzeAccelerationPSD:badSignal', ...
        'signal must be a real numeric vector (complex data is not supported).');
end
nTotal = numel(signal);

if ~(isnumeric(sampleRange) && numel(sampleRange) == 2 && all(isfinite(sampleRange)))
    error('analyzeAccelerationPSD:badRange', ...
        'sampleRange must be a finite numeric [startSample endSample].');
end
i1 = double(sampleRange(1));
i2 = double(sampleRange(2));
if any(mod([i1 i2], 1) ~= 0)
    error('analyzeAccelerationPSD:badRange', ...
        'sampleRange entries must be integers (1-based sample indices).');
end
if i1 < 1 || i2 > nTotal || i2 <= i1
    error('analyzeAccelerationPSD:badRange', ...
        ['Invalid sampleRange [%g %g] for a signal of %d samples. ' ...
         'Require 1 <= start < end <= %d.'], i1, i2, nTotal, nTotal);
end

% ---- extract the segment ONCE; this is the only copy of the data --------
x = double(signal(i1:i2));
x = x(:);                       % force column, cheap for an already-column input
N = numel(x);

if N < 16
    error('analyzeAccelerationPSD:tooShort', ...
        'The selected range holds only %d samples; at least 16 are needed.', N);
end

nonFinite = ~isfinite(x);
if any(nonFinite)
    error('analyzeAccelerationPSD:nonFinite', ...
        ['The selected range contains %d NaN/Inf samples ' ...
         '(first at global index %d). Clean or interpolate the data first.'], ...
        nnz(nonFinite), i1 + find(nonFinite, 1) - 1);
end

% ---- remove the segment mean (DC), but keep it --------------------------
% A large DC offset leaks into the lowest bins and can dominate the plot.
% Removing it is standard practice; the value is returned so the operation
% is reversible and auditable.
removedMean = mean(x);
x = x - removedMean;

%% ========================================================================
%  2. Validation of the PSD parameters
%  ========================================================================
% --- periodogram window list
pgWindows = localCheckWindowList(opts.periodogram.windows, 'options.periodogram.windows');
localCheckPositiveScalar(opts.periodogram.chebSidelobe, 'options.periodogram.chebSidelobe');
if any(strcmpi(pgWindows, 'chebyshev')) && N > 2^16
    warning('analyzeAccelerationPSD:chebLarge', ...
        ['chebwin with %d points is slow and can be numerically ' ...
         'ill-conditioned. Consider a shorter sampleRange for the ' ...
         'periodogram window comparison.'], N);
end

% --- periodogram NFFT factors
nfftFactors = double(opts.periodogram.nfftFactors(:)).';
if isempty(nfftFactors) || ~all(isfinite(nfftFactors)) || any(nfftFactors < 1)
    error('analyzeAccelerationPSD:badNfftFactors', ...
        'options.periodogram.nfftFactors must be finite values >= 1 (nfft = factor*N).');
end
pgNfftValues = round(nfftFactors * N);
if max(pgNfftValues) > 2^24
    warning('analyzeAccelerationPSD:hugeNfft', ...
        'Largest NFFT is %d points; this needs a lot of memory and time.', max(pgNfftValues));
end
pgNfftWindowName = localCheckWindowList({opts.periodogram.nfftWindow}, 'options.periodogram.nfftWindow');
pgNfftWindowName = pgNfftWindowName{1};

% --- Welch window list
weWindows = localCheckWindowList(opts.welch.windows, 'options.welch.windows');
localCheckPositiveScalar(opts.welch.chebSidelobe, 'options.welch.chebSidelobe');
localCheckPositiveScalar(opts.welch.nfftFactor,   'options.welch.nfftFactor');

% --- fixed Welch segment length and overlap (used by Figures 3 and 5)
LFixed = localSecondsToSamples(opts.welch.segmentSecondsFixed, Fs, N, ...
    'options.welch.segmentSecondsFixed');
ovFixedPct = localCheckOverlapList(opts.welch.overlapPercentFixed, ...
    'options.welch.overlapPercentFixed');

% --- Welch segment-length list (Figure 4); drop entries that cannot fit
segSecList = double(opts.welch.segmentSecondsList(:)).';
segLenList = zeros(1, numel(segSecList));
keep = true(1, numel(segSecList));
for k = 1:numel(segSecList)
    try
        segLenList(k) = localSecondsToSamples(segSecList(k), Fs, N, ...
            'options.welch.segmentSecondsList');
    catch
        keep(k) = false;
        warning('analyzeAccelerationPSD:segmentSkipped', ...
            ['Segment length %g s (%d samples) does not fit in a %d-sample ' ...
             'range and was skipped.'], segSecList(k), round(segSecList(k)*Fs), N);
    end
end
segSecList = segSecList(keep);
segLenList = segLenList(keep);
if isempty(segLenList)
    error('analyzeAccelerationPSD:noSegmentLengths', ...
        'No usable entry in options.welch.segmentSecondsList for a %d-sample range.', N);
end

% --- Welch overlap list (Figure 5)
ovPctList = localCheckOverlapList(opts.welch.overlapPercentList, ...
    'options.welch.overlapPercentList');

% --- Burg orders
burgOrders = double(opts.burg.orders(:)).';
if isempty(burgOrders) || ~all(isfinite(burgOrders)) || ...
        any(burgOrders < 1) || any(mod(burgOrders, 1) ~= 0)
    error('analyzeAccelerationPSD:badBurgOrders', ...
        'options.burg.orders must be positive integers.');
end
tooBig = burgOrders >= N;
if any(tooBig)
    warning('analyzeAccelerationPSD:burgOrderSkipped', ...
        'Burg order(s) >= %d samples were skipped: %s.', N, mat2str(burgOrders(tooBig)));
    burgOrders = burgOrders(~tooBig);
end
if isempty(burgOrders)
    error('analyzeAccelerationPSD:noBurgOrders', ...
        'No usable Burg model order remains for a %d-sample range.', N);
end
burgNfft = round(double(opts.burg.nfft));
if ~(isscalar(burgNfft) && isfinite(burgNfft) && burgNfft >= 16)
    error('analyzeAccelerationPSD:badBurgNfft', ...
        'options.burg.nfft must be a scalar >= 16.');
end

%% ========================================================================
%  3. Shared context for plotting and saving
%  ========================================================================
safeName = localSanitizeName(opts.name);

ctx = struct( ...
    'opts',     opts, ...
    'safeName', safeName, ...
    'i1',       i1, ...
    'i2',       i2, ...
    'Fs',       Fs, ...
    'N',        N);

result = struct();
result.info = struct( ...
    'name',         opts.name, ...
    'safeName',     safeName, ...
    'sampleRange',  [i1 i2], ...
    'nSamples',     N, ...
    'Fs',           Fs, ...
    'durationSec',  N / Fs, ...
    'removedMean',  removedMean, ...
    'rawResolutionHz', Fs / N, ...
    'accelUnit',    opts.accelUnit);

savedFiles = {};

%% ========================================================================
%  4. Figure 1 -- periodogram, window comparison
%  ------------------------------------------------------------------------
%  All other parameters are held identical: same data, same NFFT = N (no
%  zero padding). Only the taper changes.
%
%  Tradeoff:
%    rectangular  narrowest main lobe (~2 bins) but -13 dB sidelobes with
%                 slow rolloff -> a strong tone leaks over a weak neighbour
%    Hann         ~1.5x wider lobe, -31 dB sidelobes, fast 18 dB/octave
%                 rolloff -> the usual default compromise
%    Chebyshev    flat sidelobe floor at the requested attenuation, widest
%                 useful lobe -> buy dynamic range, pay resolution
%    flat-top     very wide lobe (~4.7 bins), best amplitude accuracy for a
%                 tone -> use when you care about level, not separation
%
%  MATLAB normalises by the window's power, so the broadband noise FLOOR
%  sits at the same level for every window. Differences you see are lobe
%  shape, not scaling.
%  ========================================================================
nPg      = numel(pgWindows);
pgNfft   = N;                       % no zero padding here, on purpose
pgPxx    = [];
pgLabels = cell(1, nPg);
for k = 1:nPg
    w = localMakeWindow(pgWindows{k}, N, opts.periodogram.chebSidelobe);
    [Pk, fPg] = periodogram(x, w, pgNfft, Fs);
    if isempty(pgPxx)
        pgPxx = zeros(numel(Pk), nPg);   % preallocate once f is known
    end
    pgPxx(:, k) = Pk;                                            %#ok<AGROW>
    pgLabels{k} = localWindowLabel(pgWindows{k}, opts.periodogram.chebSidelobe);
end

result.periodogram.windows = struct( ...
    'f',             fPg, ...
    'Pxx',           pgPxx, ...        % linear, (unit)^2/Hz, one column per window
    'windowNames',   {pgWindows}, ...
    'labels',        {pgLabels}, ...
    'nfft',          pgNfft, ...
    'chebSidelobeDb', opts.periodogram.chebSidelobe);

[figH, files] = localComparisonFigure( ...
    repmat({fPg}, 1, nPg), num2cell(pgPxx, 1), pgLabels, ...
    'Periodogram - window comparison', 'periodogram_windows', ctx);
result.figures.periodogramWindows = figH;
savedFiles = [savedFiles, files];

%% ========================================================================
%  5. Figure 2 -- periodogram, NFFT comparison
%  ------------------------------------------------------------------------
%  One fixed window (Hann by default), only NFFT changes.
%
%  Increasing NFFT beyond N zero-pads the record. That evaluates the SAME
%  underlying continuous spectrum on a denser frequency grid, so the curve
%  looks smoother and peak locations can be read off more finely. It does
%  NOT improve the true frequency resolution, which is Fs/N and is fixed by
%  how long you recorded. Two tones closer than Fs/N stay unresolved no
%  matter how much you pad. Watch the peak WIDTH: it does not change.
%  ========================================================================
nNf      = numel(pgNfftValues);
nfFCell  = cell(1, nNf);
nfPCell  = cell(1, nNf);
nfLabels = cell(1, nNf);
wFixed   = localMakeWindow(pgNfftWindowName, N, opts.periodogram.chebSidelobe);  % built once
for k = 1:nNf
    [nfPCell{k}, nfFCell{k}] = periodogram(x, wFixed, pgNfftValues(k), Fs);
    nfLabels{k} = sprintf('NFFT = %d  (%.3g x N)', pgNfftValues(k), nfftFactors(k));
end

result.periodogram.nfft = struct( ...
    'f',            {nfFCell}, ...     % cell: grids differ between cases
    'Pxx',          {nfPCell}, ...     % cell of linear PSDs
    'nfftValues',   pgNfftValues, ...
    'nfftFactors',  nfftFactors, ...
    'windowName',   pgNfftWindowName, ...
    'labels',       {nfLabels}, ...
    'trueResolutionHz', Fs / N);       % identical for all cases -- the point

[figH, files] = localComparisonFigure(nfFCell, nfPCell, nfLabels, ...
    sprintf('Periodogram - NFFT comparison (%s window, true resolution %.4g Hz)', ...
            pgNfftWindowName, Fs/N), ...
    'periodogram_nfft', ctx);
result.figures.periodogramNfft = figH;
savedFiles = [savedFiles, files];

%% ========================================================================
%  6. Figure 3 -- Welch, window comparison
%  ------------------------------------------------------------------------
%  Fixed segment length and fixed overlap; only the taper changes.
%  Same window physics as Figure 1, but the segment averaging has removed
%  most of the variance, so the leakage differences are now the dominant
%  visible effect instead of being buried in noise.
%  ========================================================================
nWe        = numel(weWindows);
ovFixedSmp = localOverlapSamples(ovFixedPct, LFixed);
weNfft     = max(16, round(opts.welch.nfftFactor * LFixed));
weK        = localNumSegments(N, LFixed, ovFixedSmp);
wePxx      = [];
weLabels   = cell(1, nWe);
for k = 1:nWe
    w = localMakeWindow(weWindows{k}, LFixed, opts.welch.chebSidelobe);
    [Pk, fWe] = pwelch(x, w, ovFixedSmp, weNfft, Fs);
    if isempty(wePxx)
        wePxx = zeros(numel(Pk), nWe);
    end
    wePxx(:, k) = Pk;                                            %#ok<AGROW>
    weLabels{k} = localWindowLabel(weWindows{k}, opts.welch.chebSidelobe);
end

result.welch.windows = struct( ...
    'f',              fWe, ...
    'Pxx',            wePxx, ...       % linear, one column per window
    'windowNames',    {weWindows}, ...
    'labels',         {weLabels}, ...
    'segmentSamples', LFixed, ...
    'segmentSeconds', LFixed / Fs, ...
    'overlapPercent', ovFixedPct, ...
    'overlapSamples', ovFixedSmp, ...
    'nSegments',      weK, ...
    'nfft',           weNfft, ...
    'chebSidelobeDb', opts.welch.chebSidelobe);

[figH, files] = localComparisonFigure( ...
    repmat({fWe}, 1, nWe), num2cell(wePxx, 1), weLabels, ...
    sprintf('Welch - window comparison (L = %d samples = %.4g s, %g%% overlap, %d averages)', ...
            LFixed, LFixed/Fs, ovFixedPct, weK), ...
    'welch_windows', ctx);
result.figures.welchWindows = figH;
savedFiles = [savedFiles, files];

%% ========================================================================
%  7. Figure 4 -- Welch, segment-length comparison
%  ------------------------------------------------------------------------
%  Fixed Hann window, fixed overlap percentage, only the segment length L
%  changes. This is the central Welch tradeoff:
%
%      longer segments  -> better frequency resolution (Fs/L), fewer
%                          averages, noisier curve
%      shorter segments -> poorer frequency resolution, more averaging,
%                          smoother curve
%
%  The variance falls roughly as 1/K, so halving L roughly doubles K and
%  buys about 3 dB of smoothing while doubling the bin width. The number of
%  averages K is returned so the comparison can be made quantitative.
%  ========================================================================
nSeg      = numel(segLenList);
segFCell  = cell(1, nSeg);
segPCell  = cell(1, nSeg);
segLabels = cell(1, nSeg);
segK      = zeros(1, nSeg);
segOvSmp  = zeros(1, nSeg);
segNfft   = zeros(1, nSeg);
for k = 1:nSeg
    L            = segLenList(k);
    segOvSmp(k)  = localOverlapSamples(ovFixedPct, L);
    segNfft(k)   = max(16, round(opts.welch.nfftFactor * L));
    segK(k)      = localNumSegments(N, L, segOvSmp(k));
    w            = localMakeWindow('hann', L, opts.welch.chebSidelobe);
    [segPCell{k}, segFCell{k}] = pwelch(x, w, segOvSmp(k), segNfft(k), Fs);
    segLabels{k} = sprintf('L = %d (%.4g s), df = %.3g Hz, K = %d', ...
                           L, L/Fs, Fs/L, segK(k));
end

result.welch.segmentLength = struct( ...
    'f',               {segFCell}, ... % cell: grid depends on L
    'Pxx',             {segPCell}, ...
    'segmentSamples',  segLenList, ...
    'segmentSeconds',  segSecList, ...
    'resolutionHz',    Fs ./ segLenList, ...
    'overlapPercent',  ovFixedPct, ...
    'overlapSamples',  segOvSmp, ...
    'nSegments',       segK, ...
    'nfft',            segNfft, ...
    'windowName',      'hann', ...
    'labels',          {segLabels});

[figH, files] = localComparisonFigure(segFCell, segPCell, segLabels, ...
    sprintf('Welch - segment length comparison (Hann, %g%% overlap)', ovFixedPct), ...
    'welch_window_length', ctx);
result.figures.welchSegmentLength = figH;
savedFiles = [savedFiles, files];

%% ========================================================================
%  8. Figure 5 -- Welch, overlap comparison
%  ------------------------------------------------------------------------
%  Fixed Hann window, fixed segment length, only the overlap changes.
%
%  More overlap means more segments and more computation. But overlapping
%  segments share samples, so they are correlated and do not contribute
%  independent information. Going 0% -> 50% gives a real variance
%  reduction (a Hann window at 50% recovers essentially all the data);
%  beyond ~75% the extra segments are nearly redundant and the curve stops
%  improving while the cost keeps rising. Compare the K values in the
%  legend with how much the curves actually change.
%  ========================================================================
nOv       = numel(ovPctList);
ovPxx     = [];
ovLabels  = cell(1, nOv);
ovSmpList = zeros(1, nOv);
ovK       = zeros(1, nOv);
wHannFix  = localMakeWindow('hann', LFixed, opts.welch.chebSidelobe);   % built once
ovNfft    = max(16, round(opts.welch.nfftFactor * LFixed));
for k = 1:nOv
    ovSmpList(k) = localOverlapSamples(ovPctList(k), LFixed);
    ovK(k)       = localNumSegments(N, LFixed, ovSmpList(k));
    [Pk, fOv]    = pwelch(x, wHannFix, ovSmpList(k), ovNfft, Fs);
    if isempty(ovPxx)
        ovPxx = zeros(numel(Pk), nOv);
    end
    ovPxx(:, k)  = Pk;                                           %#ok<AGROW>
    ovLabels{k}  = sprintf('overlap = %g%% (%d samples), K = %d', ...
                           ovPctList(k), ovSmpList(k), ovK(k));
end

result.welch.overlap = struct( ...
    'f',              fOv, ...
    'Pxx',            ovPxx, ...       % linear, one column per overlap
    'overlapPercent', ovPctList, ...
    'overlapSamples', ovSmpList, ...
    'nSegments',      ovK, ...
    'segmentSamples', LFixed, ...
    'segmentSeconds', LFixed / Fs, ...
    'nfft',           ovNfft, ...
    'windowName',     'hann', ...
    'labels',         {ovLabels});

[figH, files] = localComparisonFigure( ...
    repmat({fOv}, 1, nOv), num2cell(ovPxx, 1), ovLabels, ...
    sprintf('Welch - overlap comparison (Hann, L = %d samples = %.4g s)', ...
            LFixed, LFixed/Fs), ...
    'welch_overlap', ctx);
result.figures.welchOverlap = figH;
savedFiles = [savedFiles, files];

%% ========================================================================
%  9. Figure 6 -- Burg, AR model-order comparison
%  ------------------------------------------------------------------------
%  NFFT is held fixed so that only the model order changes. Burg fits an
%  all-pole (AR) model of order p and evaluates its spectrum, so the output
%  is always smooth and confident-looking regardless of whether the model
%  is appropriate.
%
%    * low order        too few poles to represent the real resonances;
%                       close tones merge, peaks are broad and shifted
%    * higher order     sharper, better-separated peaks while p is still
%                       matched to the physics (~2 poles per resonance)
%    * excessive order  the extra poles start fitting the noise, producing
%                       narrow peaks that are artefacts, not signal
%
%  A sharper Burg spectrum is NOT automatically a more accurate spectrum.
%  The sharpness is a property of the model you imposed. Always cross-check
%  a Burg peak against the Welch estimate before believing it, and be
%  especially sceptical if the data is broadband or non-stationary, where
%  the AR assumption is a poor fit in the first place.
%
%  No additional Burg parameter sweeps are included: NFFT for Burg is pure
%  evaluation-grid density (the AR model is continuous in frequency), so
%  sweeping it would only repeat the lesson of Figure 2.
%  ========================================================================
nOrd      = numel(burgOrders);
burgPxx   = [];
burgLabels = cell(1, nOrd);
for k = 1:nOrd
    [Pk, fBurg] = pburg(x, burgOrders(k), burgNfft, Fs);
    if isempty(burgPxx)
        burgPxx = zeros(numel(Pk), nOrd);
    end
    burgPxx(:, k)  = Pk;                                         %#ok<AGROW>
    burgLabels{k}  = sprintf('AR order p = %d', burgOrders(k));
end

result.burg.order = struct( ...
    'f',      fBurg, ...
    'Pxx',    burgPxx, ...             % linear, one column per model order
    'orders', burgOrders, ...
    'nfft',   burgNfft, ...
    'labels', {burgLabels});

[figH, files] = localComparisonFigure( ...
    repmat({fBurg}, 1, nOrd), num2cell(burgPxx, 1), burgLabels, ...
    sprintf('Burg - AR model order comparison (NFFT = %d fixed)', burgNfft), ...
    'burg_order', ctx);
result.figures.burgOrder = figH;
savedFiles = [savedFiles, files];

%% ========================================================================
%  10. Wrap up
%  ========================================================================
result.files   = savedFiles;
result.options = opts;

if opts.closeAfterSave
    fn = fieldnames(result.figures);
    for k = 1:numel(fn)
        close(result.figures.(fn{k}));
    end
    result.figures = struct();   % handles are no longer valid
end

end % ======================= end of main function =========================


%% ========================================================================
%  Local helper functions
%  ========================================================================

function opts = localDefaultOptions()
%LOCALDEFAULTOPTIONS  Recommended defaults. Retrieve with ('defaults').

opts = struct();
opts.outputFolder   = pwd;        % used only via fullfile; never cd'd into
opts.name           = 'signal';   % sanitized before it reaches a filename
opts.accelUnit      = 'm/s^2';    % affects the y-axis label text only
opts.saveFig        = false;      % independent flag for .fig
opts.savePng        = true;       % independent flag for .png
opts.freqLimits     = [];         % [] -> [0 Fs/2]
opts.dbRange        = [];         % [] -> auto ylim; e.g. 120 clips to 120 dB
opts.maxPlotPoints  = 20000;      % display thinning only; struct keeps full data
opts.closeAfterSave = false;

% --- Periodogram --------------------------------------------------------
opts.periodogram.windows      = {'rectangular', 'hann', 'chebyshev', 'flattop'};
opts.periodogram.chebSidelobe = 100;      % dB of sidelobe attenuation
opts.periodogram.nfftFactors  = [1 2 4];  % nfft = factor * N
opts.periodogram.nfftWindow   = 'hann';   % fixed window for the NFFT sweep

% --- Welch --------------------------------------------------------------
opts.welch.windows             = {'rectangular', 'hann', 'chebyshev', 'flattop'};
opts.welch.chebSidelobe        = 100;
opts.welch.segmentSecondsFixed = 1.0;              % Figures 3 and 5
opts.welch.overlapPercentFixed = 50;               % Figures 3 and 4
opts.welch.segmentSecondsList  = [0.25 0.5 1 2];   % Figure 4
opts.welch.overlapPercentList  = [0 25 50 75];     % Figure 5
opts.welch.nfftFactor          = 1;                % 1 = no zero padding

% --- Burg ---------------------------------------------------------------
opts.burg.orders = [4 8 16 32 64];
opts.burg.nfft   = 4096;                           % fixed across all orders
end


function s = localMergeStruct(s, u, pathStr)
%LOCALMERGESTRUCT  Overlay user options on defaults; warn on unknown fields.
if ~isstruct(u)
    error('analyzeAccelerationPSD:badOptions', '%s must be a struct.', pathStr);
end
fn = fieldnames(u);
for k = 1:numel(fn)
    here = [pathStr '.' fn{k}];
    if ~isfield(s, fn{k})
        warning('analyzeAccelerationPSD:unknownOption', ...
            'Unknown option "%s" ignored (check the spelling).', here);
        continue
    end
    if isstruct(s.(fn{k})) && isstruct(u.(fn{k}))
        s.(fn{k}) = localMergeStruct(s.(fn{k}), u.(fn{k}), here);
    else
        s.(fn{k}) = u.(fn{k});
    end
end
end


function names = localCheckWindowList(list, pathStr)
%LOCALCHECKWINDOWLIST  Normalise and validate a list of window names.
if ischar(list) || isstring(list)
    list = cellstr(list);
end
if ~iscell(list) || isempty(list)
    error('analyzeAccelerationPSD:badWindowList', ...
        '%s must be a non-empty cell array of window names.', pathStr);
end
names = cell(1, numel(list));
for k = 1:numel(list)
    nm = lower(strtrim(char(list{k})));
    switch nm
        case {'rect', 'rectangular', 'boxcar', 'none'}
            names{k} = 'rectangular';
        case {'hann', 'hanning'}
            names{k} = 'hann';
        case {'cheb', 'chebwin', 'chebyshev'}
            names{k} = 'chebyshev';
        case {'flattop', 'flat-top', 'flattopwin'}
            names{k} = 'flattop';
        otherwise
            error('analyzeAccelerationPSD:badWindowName', ...
                ['Unsupported window "%s" in %s. Use rectangular, hann, ' ...
                 'chebyshev or flattop.'], nm, pathStr);
    end
end
end


function w = localMakeWindow(name, L, chebSidelobeDb)
%LOCALMAKEWINDOW  Build a window of length L by canonical name.
%   Hann and flat-top use the 'periodic' form, which is the correct choice
%   for spectral estimation of random signals. rectwin and chebwin have no
%   periodic variant; the difference is O(1/L) and negligible here.
switch name
    case 'rectangular'
        w = rectwin(L);
    case 'hann'
        w = hann(L, 'periodic');
    case 'chebyshev'
        w = chebwin(L, chebSidelobeDb);
    case 'flattop'
        w = flattopwin(L, 'periodic');
    otherwise
        error('analyzeAccelerationPSD:badWindowName', 'Unsupported window "%s".', name);
end
w = w(:);
end


function lbl = localWindowLabel(name, chebSidelobeDb)
%LOCALWINDOWLABEL  Human-readable legend entry for a window.
switch name
    case 'rectangular', lbl = 'rectangular (no taper)';
    case 'hann',        lbl = 'Hann';
    case 'chebyshev',   lbl = sprintf('Chebyshev (%g dB sidelobes)', chebSidelobeDb);
    case 'flattop',     lbl = 'flat-top';
    otherwise,          lbl = name;
end
end


function L = localSecondsToSamples(sec, Fs, N, pathStr)
%LOCALSECONDSTOSAMPLES  Convert a segment length in seconds to samples.
if ~(isscalar(sec) && isnumeric(sec) && isfinite(sec) && sec > 0)
    error('analyzeAccelerationPSD:badSegment', ...
        '%s must be a finite positive scalar [s].', pathStr);
end
L = round(sec * Fs);
if L < 8
    error('analyzeAccelerationPSD:badSegment', ...
        '%s = %g s gives only %d samples at Fs = %g Hz; too short.', pathStr, sec, L, Fs);
end
if L > N
    error('analyzeAccelerationPSD:badSegment', ...
        '%s = %g s gives %d samples, more than the %d samples selected.', pathStr, sec, L, N);
end
end


function pct = localCheckOverlapList(list, pathStr)
%LOCALCHECKOVERLAPLIST  Validate overlap percentages in [0,100).
pct = double(list(:)).';
if isempty(pct) || ~all(isfinite(pct)) || any(pct < 0) || any(pct >= 100)
    error('analyzeAccelerationPSD:badOverlap', ...
        ['%s must contain values in [0,100). 100%% is not valid: the ' ...
         'segments would never advance.'], pathStr);
end
end


function nov = localOverlapSamples(pct, L)
%LOCALOVERLAPSAMPLES  Overlap in samples, guaranteed strictly less than L.
nov = min(L - 1, max(0, round(pct / 100 * L)));
end


function K = localNumSegments(N, L, nov)
%LOCALNUMSEGMENTS  Number of Welch segments that fit in N samples.
%   This is the quantity that explains the variance in Figures 4 and 5.
K = max(0, floor((N - nov) / (L - nov)));
end


function safeName = localSanitizeName(nameIn)
%LOCALSANITIZENAME  Make an arbitrary name safe for a filename.
if isstring(nameIn) || ischar(nameIn)
    s = char(nameIn);
else
    s = '';
end
s = regexprep(s, '[^A-Za-z0-9_\-]', '_');   % keep only safe characters
s = regexprep(s, '_{2,}', '_');             % collapse runs of underscores
s = regexprep(s, '^_+|_+$', '');            % trim leading/trailing underscores
if isempty(s)
    s = 'signal';
end
if numel(s) > 64
    s = s(1:64);
end
safeName = s;
end


function [figH, files] = localComparisonFigure(fCell, pCell, labels, titleStr, tag, ctx)
%LOCALCOMPARISONFIGURE  One comparison plot, with explicit handles throughout.
%
%   fCell / pCell  cell arrays, one entry per compared case
%   pCell holds LINEAR PSD; the dB conversion happens here and only here.

opts = ctx.opts;

figH = figure('Name', titleStr, 'NumberTitle', 'off', 'Color', 'w', ...
              'Units', 'pixels', 'Position', [100 100 950 560]);
ax = axes('Parent', figH);
hold(ax, 'on');
grid(ax, 'on');
box(ax, 'on');

nCase = numel(fCell);
h     = gobjects(1, nCase);
peakDb = -Inf;
for k = 1:nCase
    % realmin guard: a zero bin would give -Inf and destroy the autoscale
    dB = 10 * log10(max(pCell{k}, realmin));
    peakDb = max(peakDb, max(dB));
    [fp, dp] = localThinForPlot(fCell{k}, dB, opts.maxPlotPoints);
    h(k) = plot(ax, fp, dp, 'LineWidth', 1.1);
end

xlabel(ax, 'Frequency [Hz]');
ylabel(ax, sprintf('PSD [dB/Hz], ref. 1 (%s)^2/Hz', opts.accelUnit), ...
       'Interpreter', 'none');
title(ax, {titleStr, ...
           sprintf('%s | samples %d-%d (N = %d, %.4g s, Fs = %g Hz)', ...
                   opts.name, ctx.i1, ctx.i2, ctx.N, ctx.N/ctx.Fs, ctx.Fs)}, ...
      'Interpreter', 'none');
legend(ax, h, labels, 'Location', 'best', 'Interpreter', 'none');

if isempty(opts.freqLimits)
    xlim(ax, [0 ctx.Fs/2]);
else
    xlim(ax, opts.freqLimits);
end
if ~isempty(opts.dbRange) && isfinite(peakDb)
    ylim(ax, [peakDb - opts.dbRange, peakDb + 5]);
end

baseName = sprintf('PSD_%s_%s_samples_%d_%d', tag, ctx.safeName, ctx.i1, ctx.i2);
files = localSaveFigure(figH, opts.outputFolder, baseName, opts.saveFig, opts.savePng);
end


function [fOut, yOut] = localThinForPlot(f, y, maxPts)
%LOCALTHINFORPLOT  Reduce a curve to at most ~maxPts points for DISPLAY only.
%   Block-maximum decimation: peaks survive, which matters for a PSD. The
%   visible broadband floor sits slightly high as a result. The returned
%   result struct always holds the full-resolution data.
n = numel(y);
if n <= maxPts
    fOut = f(:);
    yOut = y(:);
    return
end
blk = ceil(n / maxPts);
nb  = floor(n / blk);
Y   = reshape(y(1:nb*blk), blk, nb);
F   = reshape(f(1:nb*blk), blk, nb);
[ym, row] = max(Y, [], 1);
fm   = F(sub2ind([blk nb], row, 1:nb));
fOut = [fm(:); f(end)];     % keep the Nyquist end point
yOut = [ym(:); y(end)];
end


function files = localSaveFigure(figH, outFolder, baseName, saveFig, savePng)
%LOCALSAVEFIGURE  Write .fig and/or .png. Never changes the working directory.
files = {};
if ~saveFig && ~savePng
    return
end

if ~exist(outFolder, 'dir')
    [ok, msg] = mkdir(outFolder);
    if ~ok
        error('analyzeAccelerationPSD:mkdirFailed', ...
            'Could not create output folder "%s": %s', outFolder, msg);
    end
end

if saveFig
    figFile = fullfile(outFolder, [baseName '.fig']);
    savefig(figH, figFile);
    files{end+1} = figFile;
end

if savePng
    pngFile = fullfile(outFolder, [baseName '.png']);
    if ~isempty(which('exportgraphics'))   % R2020a and later
        exportgraphics(figH, pngFile, 'Resolution', 150);
    else
        print(figH, pngFile, '-dpng', '-r150');
    end
    files{end+1} = pngFile;
end
end


function localCheckPositiveScalar(v, pathStr)
%LOCALCHECKPOSITIVESCALAR  Small shared validator.
if ~(isscalar(v) && isnumeric(v) && isfinite(v) && v > 0)
    error('analyzeAccelerationPSD:badParameter', ...
        '%s must be a finite positive scalar.', pathStr);
end
end

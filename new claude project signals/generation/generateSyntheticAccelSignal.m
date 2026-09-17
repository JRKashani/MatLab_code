function [signals, cfg] = generateSyntheticAccelSignal(configFilePath, outputMatFilePath)
%GENERATESYNTHETICACCELSIGNAL Generate synthetic acceleration-vs-time data.
%
%   [SIGNALS, CFG] = GENERATESYNTHETICACCELSIGNAL(CONFIGFILEPATH)
%   parses CONFIGFILEPATH (see parseSignalConfig.m / example_config.txt)
%   and generates three synchronized acceleration signals.
%
%   [SIGNALS, CFG] = GENERATESYNTHETICACCELSIGNAL(CONFIGFILEPATH, OUTPUTMATFILEPATH)
%   additionally saves the result to OUTPUTMATFILEPATH. Omit or pass ''
%   to skip saving.
%
%   Inputs:
%       configFilePath    - path to a .txt configuration file
%       outputMatFilePath - (optional) path to write a .mat file
%
%   Output:
%       signals - struct with fields:
%           combinedSignal  - shifts + sines + noise      (1 x N double)
%           pureSineSignal  - decaying sines only          (1 x N double)
%           pureNoiseSignal - white+pink+brown noise only   (1 x N double)
%           shiftSignal     - shift components only         (1 x N double)
%       cfg - the parsed configuration struct returned by
%             parseSignalConfig (Fs, Duration, SampleCount, Seed, noise
%             RMS targets, SineComponents, ShiftComponents)
%
%   The .mat file (if requested) stores one top-level struct variable
%   (named DEFINE().MAT_ROOT_VARNAME) containing the four signals
%   above, Fs/Duration/SampleCount/Seed, and cfg for provenance. No
%   full time vector is stored; reconstruct it later, only if actually
%   needed, via (0:SampleCount-1)/Fs. Saved with '-v7': at ~1e6
%   samples per signal (a few MB per vector) the file stays far below
%   the 2 GB classic-format limit, and -v7 is faster to read/write
%   than -v7.3, which mainly earns its HDF5 overhead back when a file
%   exceeds 2 GB or you need partial/incremental access -- neither
%   applies here.

if nargin < 2
    outputMatFilePath = '';
end

D = DEFINE();
cfg = parseSignalConfig(configFilePath);

Fs = cfg.Fs;
N  = cfg.SampleCount;

% Seed AND fix the algorithm so "same seed -> same data" holds even if
% MATLAB's default generator algorithm ever changes between releases.
rng(cfg.Seed, D.RNG_ALGORITHM);

% ---- sines -----------------------------------------------------------
% Looping here is over the number of sine components (expected to be
% small -- tens, not millions), not over the ~1e6 samples, so it stays
% cheap; each iteration is itself a vectorized assignment over that
% component's active window. An alternative that avoids the loop
% entirely -- building an N-by-numComponents matrix and summing across
% columns -- would cost far more memory for no real speed benefit,
% since components can have very different, mostly non-overlapping
% active windows.
pureSineSignal = zeros(1, N);
for k = 1:numel(cfg.SineComponents)
    s = cfg.SineComponents(k);
    segmentLength = round(s.duration * Fs);
    idxStart = min(round(s.startTime * Fs) + 1, N); % clamp: rounding near the recording end can push this to N+1
    idxEnd   = min(idxStart + segmentLength - 1, N);

    localTime = (0:(idxEnd - idxStart)) / Fs; % time measured from this component's own start
    % tau = 0 or Inf means no decay; any positive finite value creates an
    % exponentially decaying envelope.
    decayFactor = ones(size(localTime));
    if isfinite(s.tau) && s.tau > 0
        decayFactor = exp(-localTime / s.tau);
    end
    pureSineSignal(idxStart:idxEnd) = pureSineSignal(idxStart:idxEnd) + ...
        s.amplitude * decayFactor .* sin(2*pi*s.freq*localTime + s.phase);
end

% ---- shifts ------------------------------------------------------------
shiftSignal = zeros(1, N);
for k = 1:numel(cfg.ShiftComponents)
    sh = cfg.ShiftComponents(k);
    segmentLength = round(sh.duration * Fs);
    idxStart = min(round(sh.startTime * Fs) + 1, N);
    idxEnd   = min(idxStart + segmentLength - 1, N);

    shiftSignal(idxStart:idxEnd) = shiftSignal(idxStart:idxEnd) + sh.offset;
end

% ---- noise -------------------------------------------------------------
% RMS of 0 disables a noise type by skipping generation entirely
% (rather than generating a realization and multiplying by zero,
% which would waste an FFT for the pink-noise case in particular).
pureNoiseSignal = zeros(1, N);
if cfg.NoiseWhiteRMS > 0
    pureNoiseSignal = pureNoiseSignal + generateColoredNoise(D.WHITE, N, cfg.NoiseWhiteRMS);
end
if cfg.NoisePinkRMS > 0
    pureNoiseSignal = pureNoiseSignal + generateColoredNoise(D.PINK, N, cfg.NoisePinkRMS);
end
if cfg.NoiseBrownRMS > 0
    pureNoiseSignal = pureNoiseSignal + generateColoredNoise(D.BROWN, N, cfg.NoiseBrownRMS);
end

combinedSignal = pureSineSignal + shiftSignal + pureNoiseSignal;

signals = struct( ...
    'combinedSignal',  combinedSignal, ...
    'pureSineSignal',  pureSineSignal, ...
    'pureNoiseSignal', pureNoiseSignal, ...
    'shiftSignal',     shiftSignal);

if ~isempty(outputMatFilePath)
    saveStruct = struct();
    saveStruct.combinedSignal  = combinedSignal;
    saveStruct.pureSineSignal  = pureSineSignal;
    saveStruct.pureNoiseSignal = pureNoiseSignal;
    saveStruct.shiftSignal     = shiftSignal;
    saveStruct.Fs          = Fs;
    saveStruct.Duration    = cfg.Duration;
    saveStruct.SampleCount = N;
    saveStruct.Seed        = cfg.Seed;
    saveStruct.Config      = cfg;

    % Wrap in a single named field so the .mat file contains exactly
    % one top-level variable (DEFINE().MAT_ROOT_VARNAME), avoiding
    % clutter/collisions from common names like Fs or Seed on load.
    fileVars = struct();
    fileVars.(D.MAT_ROOT_VARNAME) = saveStruct;
    save(outputMatFilePath, '-struct', 'fileVars', '-v7');
end

end

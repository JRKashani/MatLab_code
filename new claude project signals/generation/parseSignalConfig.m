function cfg = parseSignalConfig(configFilePath)
%PARSESIGNALCONFIG Read and validate a synthetic-acceleration config file.
%
%   CFG = PARSESIGNALCONFIG(CONFIGFILEPATH) reads the human-readable
%   text configuration file at CONFIGFILEPATH and returns a struct CFG
%   describing the signal to generate. See example_config.txt for the
%   exact text format.
%
%   Input:
%       configFilePath - path (char) to a .txt configuration file
%
%   Output:
%       cfg - struct with fields:
%           Fs               - sampling frequency [Hz]
%           Duration         - EFFECTIVE duration [s], i.e. SampleCount/Fs
%                               (may differ very slightly from the
%                               requested value, see warning below)
%           SampleCount      - number of samples, round(Fs*requestedDuration)
%           Seed             - RNG seed (nonnegative integer)
%           NoiseWhiteRMS    - target RMS of white noise (0 = disabled)
%           NoisePinkRMS     - target RMS of pink noise  (0 = disabled)
%           NoiseBrownRMS    - target RMS of brown noise (0 = disabled)
%           SineComponents   - struct array, fields: freq, amplitude,
%                               startTime, duration, phase, tau
%           ShiftComponents  - struct array, fields: startTime,
%                               duration, offset
%
%   Sine/shift components whose active interval extends past the
%   recording are clipped to end exactly at the recording boundary
%   (with a warning). Components that start at or after the recording
%   ends are rejected as a configuration error, since they would
%   generate nothing and are almost certainly a mistake.
%
%   Missing noise-RMS keys default to 0 (disabled) rather than raising
%   an error, since "not mentioned" and "explicitly disabled" are
%   reasonably treated the same way for this field.

D = DEFINE();

if ~isfile(configFilePath)
    error('parseSignalConfig:fileNotFound', ...
        'Config file not found: %s', configFilePath);
end

rawText = fileread(configFilePath);
lines = splitlines(rawText); % cell array of char row vectors

cfg = struct('Fs', [], 'Duration', [], 'Seed', [], ...
    'NoiseWhiteRMS', 0, 'NoisePinkRMS', 0, 'NoiseBrownRMS', 0);
sineList  = struct('freq', {}, 'amplitude', {}, 'startTime', {}, ...
                    'duration', {}, 'phase', {}, 'tau', {});
shiftList = struct('startTime', {}, 'duration', {}, 'offset', {});

for lineNum = 1:numel(lines)
    line = strtrim(lines{lineNum});
    if isempty(line) || startsWith(line, '#')
        continue
    end

    eqPos = strfind(line, '=');
    if isempty(eqPos)
        error('parseSignalConfig:malformedLine', ...
            'Line %d is not a comment and has no "=": "%s"', lineNum, line);
    end
    key   = strtrim(line(1:eqPos(1)-1));
    value = strtrim(line(eqPos(1)+1:end));

    switch key
        case 'Fs'
            cfg.Fs = str2double(value);
        case 'Duration'
            cfg.Duration = str2double(value);
        case 'Seed'
            cfg.Seed = str2double(value);
        case 'NoiseWhiteRMS'
            cfg.NoiseWhiteRMS = str2double(value);
        case 'NoisePinkRMS'
            cfg.NoisePinkRMS = str2double(value);
        case 'NoiseBrownRMS'
            cfg.NoiseBrownRMS = str2double(value);
        case D.SINE
            nums = str2double(strsplit(value, ','));
            if numel(nums) ~= 6 || any(isnan(nums))
                error('parseSignalConfig:malformedLine', ...
                    ['Line %d: expected "Sine = freq, amplitude, startTime, ' ...
                     'duration, phase, tau", got: "%s"'], lineNum, line);
            end
            sineList(end+1) = struct('freq', nums(1), 'amplitude', nums(2), ...
                'startTime', nums(3), 'duration', nums(4), ...
                'phase', nums(5), 'tau', nums(6)); %#ok<AGROW>
        case D.SHIFT
            nums = str2double(strsplit(value, ','));
            if numel(nums) ~= 3 || any(isnan(nums))
                error('parseSignalConfig:malformedLine', ...
                    'Line %d: expected "Shift = startTime, duration, offset", got: "%s"', ...
                    lineNum, line);
            end
            shiftList(end+1) = struct('startTime', nums(1), ...
                'duration', nums(2), 'offset', nums(3)); %#ok<AGROW>
        otherwise
            warning('parseSignalConfig:unknownKey', ...
                'Line %d: unknown key "%s" ignored.', lineNum, key);
    end
end

% ---- required scalar fields ----------------------------------------------
if isempty(cfg.Fs) || isnan(cfg.Fs) || cfg.Fs <= 0
    error('parseSignalConfig:invalidFs', 'Fs must be a positive number.');
end
if isempty(cfg.Duration) || isnan(cfg.Duration) || cfg.Duration <= 0
    error('parseSignalConfig:invalidDuration', 'Duration must be a positive number.');
end
if isempty(cfg.Seed) || isnan(cfg.Seed) || cfg.Seed < 0 || cfg.Seed ~= floor(cfg.Seed)
    error('parseSignalConfig:invalidSeed', 'Seed must be a nonnegative integer.');
end
if any([cfg.NoiseWhiteRMS, cfg.NoisePinkRMS, cfg.NoiseBrownRMS] < 0)
    error('parseSignalConfig:negativeRMS', 'Noise RMS targets cannot be negative.');
end

% ---- sample count / effective duration -----------------------------------
% N = round(Fs*Duration) samples cover the half-open interval [0, N/Fs),
% i.e. sample k (0-based) sits at t = k/Fs. This intentionally avoids
% the classic off-by-one bug of sampling both t=0 and t=Duration
% (which would give Duration*Fs + 1 samples instead of Duration*Fs).
rawCount = cfg.Fs * cfg.Duration;
cfg.SampleCount = round(rawCount);
if cfg.SampleCount < 1
    error('parseSignalConfig:tooFewSamples', ...
        'Fs and Duration combine to fewer than 1 sample.');
end
if abs(rawCount - cfg.SampleCount) > 1e-9 * max(1, rawCount)
    effectiveDurationPreview = cfg.SampleCount / cfg.Fs;
    warning('parseSignalConfig:durationRounded', ...
        ['Requested Duration (%.9g s) is not an exact multiple of 1/Fs. ', ...
         'Effective duration will be %.9g s (%d samples).'], ...
        cfg.Duration, effectiveDurationPreview, cfg.SampleCount);
end
effectiveDuration = cfg.SampleCount / cfg.Fs; % the duration actually representable on the sample grid

% ---- per-component validation & clipping ----------------------------------
nyquist = cfg.Fs / 2;
for k = 1:numel(sineList)
    sineList(k) = validateAndClipComponent(sineList(k), effectiveDuration, cfg.Fs, k, D.SINE);
    if sineList(k).freq <= 0 || sineList(k).freq >= nyquist
        error('parseSignalConfig:invalidFrequency', ...
            'Sine #%d: freq = %.9g Hz must satisfy 0 < freq < Fs/2 = %.9g Hz.', ...
            k, sineList(k).freq, nyquist);
    end
    if isnan(sineList(k).tau) || (isfinite(sineList(k).tau) && sineList(k).tau < 0)
        error('parseSignalConfig:invalidTau', 'Sine #%d: tau must be nonnegative or Inf for no decay.', k);
    end
end
for k = 1:numel(shiftList)
    shiftList(k) = validateAndClipComponent(shiftList(k), effectiveDuration, cfg.Fs, k, D.SHIFT);
end

cfg.Duration        = effectiveDuration;
cfg.SineComponents  = sineList;
cfg.ShiftComponents = shiftList;

end

% ----------------------------------------------------------------------------
function comp = validateAndClipComponent(comp, totalDuration, Fs, idx, label)
% Shared start-time/duration validation & clipping for Sine/Shift entries.
if comp.startTime < 0
    error('parseSignalConfig:invalidStartTime', ...
        '%s #%d: startTime cannot be negative.', label, idx);
end
if comp.duration <= 0
    error('parseSignalConfig:invalidComponentDuration', ...
        '%s #%d: duration must be positive.', label, idx);
end
if comp.startTime >= totalDuration
    error('parseSignalConfig:componentOutsideRecording', ...
        '%s #%d: startTime (%.9g s) is at/after the recording duration (%.9g s).', ...
        label, idx, comp.startTime, totalDuration);
end
if comp.startTime + comp.duration > totalDuration
    clippedDuration = totalDuration - comp.startTime;
    warning('parseSignalConfig:componentClipped', ...
        '%s #%d extends past the recording end; clipping duration from %.9g s to %.9g s.', ...
        label, idx, comp.duration, clippedDuration);
    comp.duration = clippedDuration;
end
if round(comp.duration * Fs) < 1
    error('parseSignalConfig:componentDurationTooShort', ...
        '%s #%d: duration is shorter than one sample at this Fs.', label, idx);
end
end

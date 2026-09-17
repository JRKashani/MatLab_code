function D = DEFINE()
%DEFINE Project-wide constants and named identifiers.
%
%   D = DEFINE() returns a struct holding constants shared across the
%   generation code (and, later, any analysis code), so values such as
%   noise-type names live in exactly one place instead of being
%   retyped as string literals throughout the project.
%
%   Output:
%       D - struct with the fields listed below.
%
%   Example:
%       D = DEFINE;
%       SINE = D.SINE;

D = struct();

% --- config-file component-block identifiers ----------------------------
% Match the "Sine = ..." / "Shift = ..." keys used in the .txt config.
D.SINE  = 'Sine';
D.SHIFT = 'Shift';

% --- noise-type identifiers ----------------------------------------------
% Used as switch-case labels in generateColoredNoise.m.
D.WHITE = 'white';
D.PINK  = 'pink';
D.BROWN = 'brown';

% --- RNG configuration ----------------------------------------------------
% Fixing the algorithm name (not just the seed) guarantees the same
% numeric stream even if MATLAB's default generator algorithm changes
% in a future release.
D.RNG_ALGORITHM = 'twister';

% --- output .mat file organization ----------------------------------------
% Name of the single top-level struct variable written into the
% generated .mat file (see generateSyntheticAccelSignal.m).
D.MAT_ROOT_VARNAME = 'syntheticAccelData';

% --- plotting settings ---------------------------------------------------
% Number of bins used for all acceleration histograms (see
% plotting/plotHistogram.m). Kept identical across signals so bar
% widths line up and the three histograms are visually comparable.
D.HISTOGRAM_BIN_COUNT = 100;

% Upper limit on how many points are drawn in the time-series plot.
% Downsampling here only ever affects the DISPLAYED line, never the
% underlying signal data or the histogram calculations.
D.MAX_PLOT_POINTS = 20000;

% Independent on/off switches: either can be toggled without touching
% the other, so you can save .png previews without cluttering the
% project with reloadable .fig files, or vice versa.
D.SAVE_FIG_FILES = false;
D.SAVE_PNG_FILES = true;

% Base filenames (without extension) for the two saved figures.
D.TIME_SERIES_BASE_FILENAME = 'signal_time_series';
D.HISTOGRAM_BASE_FILENAME   = 'signal_histograms';

% =========================
% WINDOWED MOMENTS SETTINGS
% =========================

D.WM_WINDOW_SIZES_SEC = [0.1 0.25 0.5 1 2];

% Leave empty or 0 for automatic step-size selection.
% Otherwise specify the desired step between evaluated centers in seconds.
D.WM_STEP_SEC = [];

% Advisory calculation-time target for windowed moments. Automatic stepping
% uses a timing pilot; figure rendering and file export are excluded.
D.WM_MAX_RUNTIME_SEC = 30;

% Reserve headroom because the timing pilot cannot predict runtime exactly.
D.WM_RUNTIME_SAFETY_FACTOR = 0.80;

% =========================
% FFT PEAK DETECTION SETTINGS
% =========================

% Toggle automatic FFT peak detection and annotation for the one-sided,
% positive-frequency amplitude spectrum. Setting this to false disables
% all peak detection without editing the FFT calculations themselves.
D.FFT_MARK_PEAKS = true;

% Minimum prominence, in FFT amplitude units, required for a peak to
% be considered meaningful. This applies only to the positive-frequency
% one-sided amplitude spectrum used for FFT analysis.
D.FFT_MIN_PEAK_PROMINENCE = 0.01;

% Maximum number of strong peaks to retain after sorting by amplitude.
D.FFT_MAX_PEAKS = 10;

end

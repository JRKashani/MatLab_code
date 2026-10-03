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

% Conversion to samples rounds each even result upward to the next odd value,
% so every window has one center sample and equal left/right sample counts.
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

% Minimum prominence, in FFT amplitude units, required for a peak to
% be considered meaningful. This applies only to the positive-frequency
% one-sided amplitude spectrum used for FFT analysis.
D.FFT_MIN_PEAK_PROMINENCE = 0.01;

% Future variable-resolution Welch: half-width on each side of an FFT peak.
% Use the larger of the fixed Hz value and this percentage of 0 ... Fs/2.
D.WELCH_PEAK_SURROUND_HZ = 5;
D.WELCH_PEAK_SURROUND_PERCENT = 0.1;

% --- Shared spectral annotations (FFT, periodogram and Burg) ---------------
% Periodogram controls are shared by all annotated spectral plots.
% Labels report Hz and values in the plotted physical units.
D.PSD_MARK_PEAKS = true;
D.PSD_MAX_PEAKS = 10;
% Minimum prominence in linear PSD units, relative to the largest positive-
% frequency PSD value, used for the periodogram and Welch plots.
D.PSD_MIN_PEAK_PROMINENCE_RATIO = 0.01;
% Burg spectra can have widely different peak heights. Detect prominence
% on an internal dB scale so a tall peak does not hide smaller clear peaks.
D.BURG_MIN_PEAK_PROMINENCE_DB = 6;

% --- Experimental tonal SNR (no generator configuration is used) -----------
% Short windows allow decay and gradual frequency drift. Longer windows
% separate closer tones but smear faster changes. Noise spans 0 ... Fs/2.
D.SNR_WINDOW_SEC = 0.5;
D.SNR_OVERLAP_FRACTION = 0.5;
% Candidate peaks must rise this far above the estimated white-noise PSD.
D.SNR_MIN_PEAK_ABOVE_NOISE_DB = 12;
D.SNR_MAX_TONES = 10;
D.SNR_MIN_TRACK_FRAMES = 3;
D.SNR_MAX_DRIFT_HZ_PER_SEC = 20;

end

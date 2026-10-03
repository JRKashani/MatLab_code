# Signal analysis project handoff

Reviewed: 2026-10-03. Scope: all MATLAB source files, configuration, regression tests, and existing text/CSV results. The initial review changed only this handoff. Subsequent changes are recorded below.

## Timing update (2026-10-04)

`runMission` now returns an optional third output, elapsed wall-clock seconds, and prints/logs it for successful and failed missions. `main` captures each enabled mission plus dataset loading and both numerical save steps. Timing includes plots and exports within each mission. Disabled missions have no timing entry.

`saveTimingSummary` appends timing entries to successfully written analysis TXT/CSV summaries and saves a top-level `missionSeconds` struct in both MAT bundles. It also writes `results/timing_summary.txt`, including when the analysis-summary save failed. Total time includes setup and saves but stops before timing-report persistence and final console/log reporting. The reporting step itself prints its duration through `runMission`.

A regression check covers console timing, failed-mission timing, summary/MAT persistence and avoiding stale-summary updates after an analysis-save failure. Runtime verification remains subject to MATLAB startup availability.

## Figure window update (2026-10-04)

All eight production figure-creation sites now explicitly use `WindowStyle='docked'`. Fixed figure `Position` values were removed from moments and tonal SNR because setting Position undocks figures in MATLAB R2025a and later. Plots therefore use tabs in the shared figure container in newer MATLAB; older releases use their docked Figures interface. FFT also respects the default visibility setting, allowing existing tests to keep figures hidden. Rerun `main` to recreate open figures and saved FIG files with the updated behavior.

Static inspection verified that every production figure-creation site specifies docked style and no production code sets a figure Position. Interactive tab grouping and export appearance still require verification in the user's newer MATLAB desktop; the installed R2024a batch launcher previously failed at startup.

`main` also temporarily sets the root `DefaultFigureWindowStyle` to `docked`, covering implicit figure creation during a mission. An `onCleanup` restores the user's prior default after success or failure.

## Moment and Welch comparison update (2026-10-04)

`main` now computes moments for combined, pure noise and pure sine signals before rendering their twelve docked figures. `plotMomentComparison` determines shared limits for each moment from all computed curves and global references, then exports with those limits already applied. Combined filenames remain `windowed_<moment>`; additional files use `windowed_noise_<moment>` and `windowed_sine_<moment>`. Results are retained in both MAT bundles under `windowedMoments`, `noiseMoments` and `sineMoments`. Each calculation and the shared plotting step have separate timings.

Welch now produces `welch_window_sizes` and `welch_overlap`, each with four curves. Window sizes are 256/1024/4096/16384 samples at 67% requested overlap (rounded down to whole overlap samples) (four smaller distinct sizes are selected for shorter records). Overlaps are 0/25/50/75% at up to 1024 samples. Resolution is Fs/windowLength, shown in each window legend and the overlap subtitle; zero-padding bin spacing is stored separately. `result.f` and `result.psd` retain the default up-to-1024-sample, 50% overlap estimate. Welch comparisons need at least eight selected samples. The previous `welch_psd.png` is no longer generated and may remain as an older artifact.

Regression checks were added for shared moment limits and preserved component results, plus four Welch curves, resolution metadata and overlap calculations. Interactive verification remains outstanding if the MATLAB launcher cannot start.

## Project purpose and entry points

The project generates synthetic acceleration data and analyzes time traces, histograms, windowed moments, FFT amplitude, periodogram/Welch/Burg PSD, and blind tonal SNR. `main.m` orchestrates independent missions, logs failures, and saves numerical results.

| Location | Responsibility |
| --- | --- |
| `main.m` | Path setup, mission switches, full-record selection, logging and final saves |
| `main_config.txt` | Sampling rate, duration, seed, noise targets, sine and shift components |
| `DEFINE.m` | Shared identifiers and analysis/display defaults; some plotting defaults currently bypass it |
| `generation/` | Parse config, generate sines/shifts and colored noise, save synthetic dataset |
| `utilities/selectSignalSegment.m` | Shared inclusive range validation for PSD, moments and SNR |
| `moments/` | Population mean/RMS/skewness/excess kurtosis; complete odd centered windows |
| `fft/` | Hann-windowed, coherent-gain-corrected one-sided amplitude spectrum |
| `psd/` | Calculation helpers, plot wrappers and PSD peak annotations |
| `snr/` | Measured-sample-only tone detection/tracking and full-band white-noise SNR |
| `plotting/` | Figure creation and export |
| `validation/` | Two regression suites, synthetic-data validator, and an unused placeholder wrapper |
| `utilities/save*.m` | Numerical MAT bundles and readable text/CSV summaries |

Current configuration: Fs = 10,000 Hz, 60 seconds (600,000 samples), seed 7, white-noise RMS 0.9, and sustained tones at 16/217/501 Hz with peak amplitudes 2.9/1.2/0.7. Pink/brown noise and shift offsets are zero.

## Running and interpreting results

In MATLAB, set the current folder to this project root:

```matlab
main
```

This regenerates data and overwrites fixed paths in `results/`. Back up any results that must be retained first. Edit mission switches in `main.m`; disabling generation currently raises an error rather than loading an existing dataset.

Run the existing regression suites separately:

```matlab
r = runtests('validation');
disp(table(r));
assertSuccess(r);
```

The calculation code largely implements spectral algorithms without Signal Processing Toolbox. FFT peak detection tries toolbox `findpeaks` and falls back to a different local detector. The synthetic validator optionally calls toolbox `periodogram`, `hann` and `pburg`. Graphics export also requires a working MATLAB graphics environment. MATLAB R2024a is installed here; the minimum supported release has not been established.

Important conventions:

- Sample ranges are one-based inclusive endpoints. Shared segment helpers accept `[]` for the full record; the FFT function currently requires explicit endpoints.
- FFT amplitudes use signal units; PSD values use signal units squared per Hz. Integrate PSD to obtain mean-square power; do not compare PSD bin heights directly to FFT amplitudes.
- Moments include DC in mean/RMS. Spectral analyses remove DC. Shape statistics are population central moments; kurtosis is excess kurtosis and constant windows yield NaN.
- SNR is detected tonal power divided by estimated noise power across 0 to Fs/2. It is not a general signal-versus-noise separation. See [Tonal SNR for measured signals](#tonal-snr-for-measured-signals) below for assumptions and options.

Main artifacts:

- `synthetic_accel_data.mat`: top-level `syntheticAccelData` struct with four component/combined vectors, Fs and config provenance.
- `final_results.mat`: numerical `results`, `missionStatus`, and mission `flags`.
- `analysis_results.mat`: analysis subset and metadata; no live graphics objects.
- `analysis_summary.txt` / `.csv`: selected human-readable values.
- `mission_log.txt`: exception reports and mission statuses. Inspect this and `missionStatus`, especially after partial failures.
- PNG/FIG files: plots. Existing files may be from older runs.

## Verification performed

Static inspection found useful existing protections: mission exception isolation, log cleanup, shared finite/range checks, odd/even one-sided PSD scaling, stable moment shift/scale calculations with direct recomputation of suspect windows, and removal of graphics from MAT result bundles.

There are 21 test functions across `testSignalAnalysis.m` and `testTonalSNR.m`. They cover range isolation, moment formulas and constant/offset cases, plotting limits and extremes, failure reporting, numerical persistence, PSD normalization/Burg reference behavior, and representative tonal SNR cases.

Attempted this fresh execution:

```powershell
& 'C:\Program Files\MATLAB\R2024a\bin\matlab.exe' -batch "r = runtests('validation'); disp(table(r)); assertSuccess(r);"
```

MATLAB exited before executing tests with `Fatal Startup Error` and `failed to load settings errors_warnings plugin` (exit status 1). Therefore no fresh test pass or numerical reproduction is claimed. Resolve the local startup issue and rerun the command.

The existing `results/mission_log.txt` records a successful run dated 2026-09-22. Its summary reports FFT peaks near 16/217/501 Hz, tonal SNR 8.0566 dB and estimated white-noise RMS 0.899899. This is historical evidence, not verification of the reviewed source today.

## Potential weaknesses, ordered by priority

The code paths below are confirmed by static inspection. Example triggers and numerical outcomes still need MATLAB reproduction unless explicitly described as an existing artifact.

### P1 — Config validation can accept invalid values or silently disable requested noise

**Source:** `generation/parseSignalConfig.m:107`, `:113`, `:116`, `:149`; `generation/generateSyntheticAccelSignal.m` noise branches.

Fs/Duration reject NaN and nonpositive values but not positive infinity. Noise RMS fields reject only negatives: `NoiseWhiteRMS = abc` becomes NaN, survives parsing, and the `> 0` branch skips white-noise generation. Infinity can produce nonfinite data. Seed validation lacks a finite/rng-supported upper bound. Sine amplitude/phase and shift offset can be infinite, and tau = negative infinity survives the finite-negative check and is treated as no decay.

**Impact:** A typo can change the generated experiment silently; other bad inputs fail late during allocation, RNG setup or analysis.

**Next step:** Require finite values for ordinary scalar/component fields; constrain seed to the supported generator range; permit positive Inf only for explicitly documented sentinel fields. Add parser tests for malformed noise RMS, Inf, unsupported seeds and negative-infinite tau. Also impose or document practical sample-count/memory limits.

### P1 — Synthetic validation can report more coverage than it actually performed

**Source:** `validation/validateSyntheticAnalysis.m:138`, `:150`, `:163`, `:209`.

Toolbox-dependent checks are skipped when functions are unavailable, but the printed summary labels every check absent from `failedTests` as PASS. Moment values are calculated without comparing them to production moment results. The SNR section checks pure-noise RMS rather than `estimateTonalSNR`. PSD/Burg checks invoke toolbox estimators rather than the project's implementation, and the check named WELCH POWER invokes periodogram.

**Impact:** `Validation: PASS` is not evidence that all production missions or all named checks were validated. The separate regression suites provide some of that coverage but are not run by `main`.

**Next step:** Track PASS/FAIL/SKIPPED/NOT_APPLICABLE explicitly. Compare production numerical outputs with independent ground truth, and keep synthetic dataset integrity separate from algorithm regression testing. Add tests proving skipped checks cannot be printed as PASS.

### P1 — Valid synthetic configurations can fail the validator

**Source:** `validation/validateSyntheticAnalysis.m:78`, `:127`, `:155`.

Sustained component amplitudes are checked using a rectangular FFT of the entire summed pure-sine record and an expectation of amplitude times N/2. This assumes full-record activity and a bin-centered, individually resolvable sine. Partial-duration tones, off-bin tones and same-frequency components violate it. Dominant FFT/Burg frequency is compared to the first configured tone even if a later tone is stronger. Noise-only configurations also fail the configured-sine check.

**Example triggers:** Put a weaker tone first and a stronger tone second; shorten a sustained tone to half the recording; or use 16.01 Hz in the current 60-second record.

**Next step:** Build ground truth from actual component intervals and envelopes; choose the expected dominant tone by generated contribution, handle leakage/overlap explicitly, and make absent-tone checks not applicable. Add regression fixtures for these configurations and rapid decay (the current decay-amplitude threshold is weak and not normalized by record length).

### P2 — Fixed output paths can mix results from different runs

**Source:** `main.m:52`; `utilities/projectPaths.m`; fixed filenames in PSD and plotting wrappers.

The log is truncated at startup, but previous output files remain. A disabled/failed mission can leave its old PNG; a generation failure can leave an old `final_results.mat` beside a new failure log. Writes across MAT, TXT, CSV and plots are not atomic.

**Impact:** Someone browsing `results/` can mistake old artifacts for current successful outputs.

**Next step:** Use a separate directory and run identifier for each execution, record artifacts and completion state in a manifest, and publish bundles via temporary files followed by a final move. Test a successful run followed by a failed/disabled mission.

### P2 — Mission success does not necessarily mean a usable analysis result

**Source:** `utilities/runMission.m`; `main.m:183`; `snr/estimateTonalSNR.m` status handling.

`runMission` treats returned values as success unless `allPassed=false` or `status='not_implemented'`. An SNR result with `insufficient_noise_bins` and NaN powers is therefore a successful mission. Other mission failures print a message but `main` returns normally, so batch automation may see a successful process exit.

**Next step:** Distinguish execution success from numerical validity. Define which result statuses are acceptable and provide a strict batch option or returned aggregate status, preserving partial results before raising a failure. Do not treat legitimate no-tone/constant cases as unconditional errors.

### P2 — Central save/display settings are not consistently honored

**Source:** `main.m:118`; default helpers in `plotting/plotSignalVsTime.m` and `plotting/plotHistogram.m`; `psd/run*PSD.m`.

FFT is called with both save switches hardcoded true. Time/histogram plotting uses its own defaults instead of DEFINE, and PSD wrappers always export PNG. Thus `SAVE_FIG_FILES=false` does not suppress all FIG exports; `SAVE_PNG_FILES=false` does not suppress all PNG exports. `TIME_SERIES_BASE_FILENAME` is also bypassed.

**Next step:** Pass common defaults through all wrappers while retaining per-call overrides. Test that switching exports off produces no new export files.

### P2 — Tonal SNR assumptions exclude some supported generator configurations

**Source:** `snr/estimateTonalSNR.m`; [SNR documentation below](#tonal-snr-for-measured-signals); `main_config.txt`.

The generator supports pink/brown noise and shifts, while tonal SNR assumes sparse resolved tones over approximately white noise. Colored backgrounds, transients, unresolved/crossing tones and invisible below-threshold intervals can bias the estimate. Defaults exclude frequencies within four window bins of DC/Nyquist (about 8 Hz from either edge at a 0.5-second window). A model-fit note does not make the estimate valid.

**Next step:** Carry assumptions/status/notes into downstream decisions. Add colored-noise, shifts, close/crossing tones, burst tones and near-edge cases to establish expected limitations. Select another estimator when white-noise extrapolation is unsuitable.

### P2 — FFT input validation differs from other analysis APIs

**Source:** `fft/analyzeAccelFFT.m:81`; `utilities/selectSignalSegment.m`.

FFT does not explicitly require real samples or finite real Fs and does not convert integer vectors to double before mean removal. Complex samples can enter a one-sided algorithm intended for real signals; integer input can alter subtraction semantics. PSD, moments and SNR use the stricter shared helper.

**Next step:** Reuse shared extraction/validation with FFT's eight-sample minimum, preserving documented error behavior as needed. Add integer, complex and infinite-Fs fixtures. The existing regression suite has no direct FFT algorithm tests.

### P3 — Spectral settings and summaries are incomplete

**Source:** `psd/runWelchPSD.m`; `psd/runBurgPSD.m`; `utilities/saveAnalysisResults.m:93`.

Welch fixes segment length at at most 1024 samples (about 9.77 Hz bin spacing at the current Fs), and Burg caps model order at 40. These may hide close tones or misfit a different experiment. Summary code expects fields `windows`, `segmentSecondsList` and `orders` that wrappers do not return; Burg returns singular `order`. Existing text/CSV summaries consequently omit these settings.

**Next step:** Expose estimator options and record actual window/overlap/nfft/order in result structs and summaries. Add fixtures where close-tone resolution and model order matter.

### P3 — Scaling, reproducibility and public-helper robustness need limits

**Source:** `moments/analyzeWindowedMoments.m:63`; `snr/estimateTonalSNR.m` spectra/owners allocation; `generation/generateColoredNoise.m`; `psd/computePeriodogramPSD.m`; `psd/computeWelchPSD.m`.

Moment prefix sums and SNR frequency-by-frame matrices scale with recording length; runtime budgeting does not bound memory. Automatic moment spacing depends on a timing pilot, so evaluated centers and detected extremes can differ between machines/runs. Generation resets global RNG state. Brown-noise normalization depends on duration (already documented in code). Low-level periodogram/Welch helpers lack full argument validation; an nfft shorter than the windowed signal truncates samples while retaining full-window normalization.

**Next step:** Use explicit `stepSec` for comparable moment runs, document resource limits, consider streamed processing for large data, restore RNG state for library calls, and validate/document helper preconditions. Test short nfft, mismatched windows and invalid overlap before exposing helpers as public APIs.

## Recommended continuation

1. Restore MATLAB startup and run both regression suites; retain the actual test report.
2. Add targeted parser/validator regression fixtures and address P1 findings first.
3. Add run-specific output folders and clear execution-versus-validity status handling.
4. Unify export controls, FFT validation and estimator provenance in summaries.
5. Validate broader experiments before extending to measured-data workflows. `runSignalGeneration.m` is not used by main, and `runSignalValidation.m` remains a placeholder; choose one supported entry path instead of maintaining parallel incomplete workflows.

No fixes are claimed by this handoff. Reproduce the listed triggers and rerun relevant tests after each change.

## Linear PSD display update (2026-10-04)

Periodogram, Burg and both Welch comparison graphs now plot raw PSD on a linear y-axis, labeled acceleration squared per Hz (`(m/s^2)^2/Hz`). Peak markers, leader lines and annotations use the same linear values. The spectrum/noise-floor panel in the SNR figure also uses linear PSD in input units squared per Hz; the actual SNR panel remains a dB ratio. Numerical estimators are unchanged. Burg may still use dB prominence internally for detection, and diagnostic `levelDbHz` metadata is retained. Rerun `main` to regenerate the plots; interactive verification remains outstanding because the available batch launcher fails during startup.

## Shared peak flag update (2026-10-04)

FFT, periodogram and Burg now call `utilities/annotateSpectralPeaks.m` for the periodogram's red triangles, leader lines and spaced white labels. FFT labels retain acceleration amplitude units; PSD labels retain acceleration squared per Hz. Annotation enable/disable and maximum peak count use the periodogram's `PSD_MARK_PEAKS` and `PSD_MAX_PEAKS` in DEFINE throughout; redundant FFT-specific switches were removed. Detection thresholds remain estimator-specific. Welch comparison figures retain four clean comparison curves without peak flags. Static review passed; interactive rendering still needs verification in MATLAB.

## FFT peak vector and surrounding bands (2026-10-04)

FFT now saves an ascending column vector `allPeakFrequenciesHz` and matching `allPeakAmplitudes` for all positive-frequency peaks passing `FFT_MIN_PEAK_PROMINENCE`. This vector is independent of the annotation toggle and ten-flag display cap; it is not every noise ripple below the configured threshold. Existing capped `peakFrequenciesHz`/`peakAmplitudes` fields remain for display compatibility.

DEFINE adds `WELCH_PEAK_SURROUND_HZ = 5` and `WELCH_PEAK_SURROUND_PERCENT = 0.1`. `peakFrequencyBands` selects a half-width of `max(fixedHz, percent/100 * Fs/2)` on each side of each peak, clipping bounds to 0-Fs/2. `peakNeighborhoods.rangesHz` contains one row per peak, with both parameters and the selected width preserved as metadata. Overlapping bands remain separate for the future Welch implementation. Text/CSV and both MAT bundles retain the peak vector and parameter values. Variable-resolution Welch itself is intentionally deferred as requested.

Physical units in graph labels, peak flags and subtitles use square brackets. PSD is labeled `[m^2/s^4/Hz]`; FFT acceleration uses `[m/s^2]`. Regression fixtures cover more peaks than the flag cap, both width-selection cases, edge clipping and an empty vector. Fresh MATLAB execution remains blocked by the known launcher startup error.

## Variable-resolution Welch implemented (2026-10-04)

`RUN_VARIABLE_WELCH` enables a separately timed mission after the existing Welch comparisons. It consumes the FFT's uncapped peak vector for the same selected samples and sampling rate. Results are available as `results.variableWelch`, retained in both MAT bundles, and summarized in TXT/CSV. The new tab and export are named `Variable-resolution Welch` and `welch_variable_resolution.png` (FIG is also supported by the existing save flag).

`computeVariableWelchPSD` uses 1024-sample Hann windows for the background and 131072-sample windows inside merged FFT peak bands, both at 50% overlap. Following the power-of-two preference, window length and frequency-bin spacing differ by exactly 128:1 without zero-padding. For Fs=16384, resolution is 16 [Hz] outside and 0.125 [Hz] inside peak bands. Short records round both window lengths down together to powers of two; fewer than 512 samples are rejected because the coarse Hann window must retain at least four samples. A custom resolution ratio must be a power of two. No peaks yields a coarse-only curve.

The figure has one PSD curve on a linear scale and orange dashed lines at all internal band boundaries, with alternating top/bottom frequency labels to keep nearby boundaries legible. Overlapping/touching bands are merged; zero-width bands are omitted. Endpoints at DC/Nyquist are not labeled as resolution changes. Saved metadata contains merged bands, transitions, resolution at each returned frequency, and both underlying Welch estimates. Exact boundaries are inserted by interpolation; the curve intentionally switches estimators there and can have jumps. Its total integrated power need not equal a uniform Welch estimate, and coarse tone leakage can extend outside narrow requested bands.

Validation: all four tests in `validation/testVariableWelch.m` passed under MATLAB R2024a after the power-of-two update, covering close tones/power, background variance, exact ratio, merged/clipped bands, empty bands, short records, selected-range isolation, one curve/boundary markers, FFT dependency checks, saved metadata, power-of-two lengths for limited records and invalid ratio rejection. The settings-plugin startup error was specific to sandboxed launching; the authorized outside-sandbox test run succeeded. Other older suites were not rerun in this update.

## Tonal SNR for measured signals

Moved in full from `snr/README.md` on 2026-10-04; the separate file was removed so this handoff is the documentation reference.

`runSNRAnalysis` needs only the measured samples, sample range and sampling
frequency. It does not read the synthetic signal configuration. `main` calls
it when `RUN_SNR` is true; results go to `results.snr` and the existing MAT,
text and CSV summaries. The diagnostic figure is `results/snr_analysis.png`.

```matlab
addpath(genpath(projectRoot));
options = struct('windowSec', 0.5, 'minPeakAboveNoiseDb', 12);
r = runSNRAnalysis(measuredSignal, [], Fs, 'experiment', 'results', options);
```

The defaults in `DEFINE.m` use overlapping 0.5-second Hann windows. Peaks
must exceed the initial white-noise floor by 12 dB and persist for three
frames (or all available frames for shorter recordings). Peaks are linked
between frames to follow gradual frequency changes. The default drift limit
is 20 Hz/s plus a frequency-resolution allowance; adjust it to the experiment.
At most ten candidate tones are retained per frame. A resolved tone can start,
decay and disappear. Below-threshold intervals contribute zero detected tone
power; the algorithm does not extrapolate an invisible tone's amplitude.

The initial floor uses a median periodogram statistic appropriate for
approximately Gaussian white-noise Fourier coefficients. Final noise PSD is
the arithmetic mean outside confirmed tone bands, extrapolated across the
entire **0 to Fs/2** band, including the noise underneath the tones. Integrating
each tone band and subtracting its estimated noise gives its mean-square
power. SNR is `10*log10(tonePower/noisePower)`, using the full noise band for
both combined and individual tone SNR. DC is removed, not treated as a tone.

Useful outputs:

- `noiseRMS`, `signalRMS`, `overallSNRdB`: time-weighted estimates over the
  selected segment. They use mean powers, not averages of frame SNR in dB.
- `tracks(k).frequencyHz`, `.amplitude`, `.time`: tone history. Amplitude is
  the local equivalent sine peak amplitude `sqrt(2*power)`, in input units.
  Missing detections are `NaN` in the frequency/amplitude traces.
- `tracks(k).overallSNRdB`: per-tone SNR averaged over the whole selected
  duration, including intervals without detections.
- `frames`: local signal/noise powers, noise RMS, SNR and original-record times.
- `status`, `notes`: no detections, constant data or insufficient noise bins;
  a broad-band background check also flags a questionable white-noise model.

Use `makePlots=false` to return numbers only. `savePng` and `saveFig` override
the project save flags. `estimateTonalSNR` is the calculation-only entry point.

Limitations: assumes sparse resolved tones over a flat noise background.
Tone identity is ambiguous at crossings or when nearby components merge.
Faster frequency changes need shorter windows, at the cost of frequency
resolution. Tones within four window bins of DC or Nyquist are not resolved;
the full-band noise estimate still includes those frequencies. Colored noise,
transients and dense spectral content are outside this model. No detected
tones yields `-Inf` SNR; an entirely constant signal yields undefined (`NaN`)
SNR. At least 64 samples are required.

Validation: `runtests('validation/testTonalSNR.m')` covers known multitone SNR,
decaying chirps, pure noise, DC/range handling and saved summaries.

## Commented MATLAB alternatives (2026-10-04)

The custom implementations remain active. Commented reference calls sit beside each custom kernel and its main analysis call sites. Reference outputs use a `Matlab` suffix so uncommenting a call allows comparison without overwriting the active result. They are examples, not automatic switches; to replace a kernel, explicitly route the desired reference output onward.

| Custom code | Commented MATLAB reference |
| --- | --- |
| Manual periodogram, including SNR frames | `periodogram(x, window, nfft, Fs, 'onesided')` |
| Welch averaging, including each variable-resolution branch | `pwelch(x, window, overlap, nfft, Fs, 'onesided')` |
| Burg PSD and AR coefficient recursion | `pburg(x, order, nfft, Fs, 'onesided')`, `arburg(x, order)` |
| Manual Hann, including the FFT's inline window | `hann(N, 'symmetric')` |
| FFT peak fallback and PSD peak selection | `findpeaks(...)` with matching prominence settings |
| Windowed/global moments and noise RMS | `movmean`, `rms`, `skewness(...,1)`, `kurtosis(...,1)-3` |
| Tonal SNR | `snr(x, Fs)` as a related single-tone benchmark only |
| Colored-noise generation | `dsp.ColoredNoise(...)` plus target-RMS scaling as a related generator |

The spectral estimators use Signal Processing Toolbox. `movmean` is base MATLAB; `rms` moved from Signal Processing Toolbox to base MATLAB in R2022a. `skewness` and `kurtosis` use Statistics and Machine Learning Toolbox, and `dsp.ColoredNoise` uses DSP System Toolbox. The comments identify these dependencies rather than implying every reference belongs to the same toolbox.

Equivalence notes: the window vector, one-sided PSD scaling, sampling rate and overlap must match. FFT fallback prominence differs from toolbox valley-based prominence. The validator's N-1 moment normalization differs from population moment references. `snr` uses fundamental/harmonic assumptions and does not replace the multitone tracker. Variable-resolution Welch still needs two estimates and custom band selection. The colored-noise generator uses a different realization/filtering method. Native calls were checked against the documentation; numerical equality is not claimed for these explicitly related alternatives.

Official references: [periodogram](https://www.mathworks.com/help/signal/ref/periodogram.html), [pwelch](https://www.mathworks.com/help/signal/ref/pwelch.html), [pburg](https://www.mathworks.com/help/signal/ref/pburg.html), [hann](https://www.mathworks.com/help/signal/ref/hann.html), [rms](https://www.mathworks.com/help/matlab/ref/rms.html), [skewness](https://www.mathworks.com/help/stats/skewness.html), [kurtosis](https://www.mathworks.com/help/stats/kurtosis.html), [snr](https://www.mathworks.com/help/signal/ref/snr.html), [dsp.ColoredNoise](https://www.mathworks.com/help/dsp/ref/dsp.colorednoise-system-object.html).

Verification for this documentation-only update: hashes of every nonblank, noncomment MATLAB source line matched before and after the edits. All executable code is unchanged; no new runtime test was needed.

## PSD integrals displayed (2026-10-04)

The periodogram subtitle shows the integrated PSD. Each curve in both Welch comparison figures has an additional text-only legend entry with its integral; the variable-resolution Welch legend also includes its whole-curve integral. The extra legend entries do not create data curves. Units are acceleration squared, `[m^2/s^4]`.

Integration uses `trapz(f, psd)` to measure the area under the plotted samples, including the nonuniform frequency grid in variable Welch. `integratedPower` is saved with each result and each Welch comparison curve. This trapezoidal area can differ from the discrete FFT-bin power sum at DC/Nyquist and does not add back the removed DC component. The variable-resolution value integrates the displayed composite, including its connections at method boundaries.

Verification: six targeted tests passed in MATLAB R2024a, including known sine power after DC removal, all Welch curve integrals, legend entry counts, the variable frequency grid, and MAT persistence.

## Wider variable-Welch bands (2026-10-04)

Both peak-surround defaults were doubled: `WELCH_PEAK_SURROUND_HZ = 10` and `WELCH_PEAK_SURROUND_PERCENT = 0.2`. The selected half-width remains the larger value. At Fs=16384, each peak now receives +/-16.384 [Hz] of fine resolution (32.768 [Hz] total before merging/clipping). Window lengths and the 128:1 resolution ratio are unchanged. This supersedes the initial 5 [Hz]/0.1% defaults documented above.

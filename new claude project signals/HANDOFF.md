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

Welch now produces `welch_window_sizes` and `welch_overlap`, each with four curves. Window sizes are 256/1024/4096/16384 samples at 50% overlap (four smaller distinct sizes are selected for shorter records). Overlaps are 0/25/50/75% at up to 1024 samples. Resolution is Fs/windowLength, shown in each window legend and the overlap subtitle; zero-padding bin spacing is stored separately. `result.f` and `result.psd` retain the default up-to-1024-sample, 50% overlap estimate. Welch comparisons need at least eight selected samples. The previous `welch_psd.png` is no longer generated and may remain as an older artifact.

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
- SNR is detected tonal power divided by estimated noise power across 0 to Fs/2. It is not a general signal-versus-noise separation. See `snr/README.md` for assumptions and options.

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

**Source:** `snr/estimateTonalSNR.m`; `snr/README.md`; `main_config.txt`.

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

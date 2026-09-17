# Redundancy / Consolidation Report

This project already has the intended modular skeleton in place:

- generation/
- moments/
- fft/
- psd/
- snr/
- validation/
- plotting/
- utilities/
- results/

The active orchestration in `main.m` already uses the modular entry points, so the remaining root-level files are not part of the active execution path unless they are legacy copies left behind during the refactor.

## Canonical implementations that should remain active

The following are the current canonical implementations for the project responsibilities:

- Generation entry point: `generation/runSignalGeneration.m`
- Signal generation logic: `generateSyntheticAccelSignal.m`
- Windowed moments: `moments/analyzeWindowedMoments.m`
- FFT analysis: `fft/analyzeAccelFFT.m`
- PSD orchestration: `psd/runPeriodogramPSD.m`, `psd/runWelchPSD.m`, `psd/runBurgPSD.m`
- PSD implementation core: `analyzeAccelerationPSD.m`
- SNR orchestration: `snr/runSNRAnalysis.m`
- Validation orchestration: `validation/runSignalValidation.m`
- Plotting helpers: `plotting/plotSignalVsTime.m`, `plotting/plotHistogram.m`
- Shared project paths: `utilities/projectPaths.m`, `utilities/runMission.m`, `utilities/saveFinalResults.m`

These files match the chosen module layout and are the ones that should stay as the active codebase.

## Legacy / redundant files left in the project root

These files should be treated as redundant candidates for manual removal once the remaining cleanup is approved. They are either duplicates of the modular implementations or older alternatives that are not used by the active `main.m` flow.

### 1) Duplicate FFT / moments copies

- `analyzeAccelFFT.m`  
  Reason: duplicate of `fft/analyzeAccelFFT.m`. Same responsibility, same analysis logic; the module copy is the canonical implementation.

- `analyzeWindowedMoments.m`  
  Reason: duplicate of `moments/analyzeWindowedMoments.m`. Same responsibility; module version is the canonical implementation.

Confidence: High

### 2) Alternative PSD implementations kept only as older comparison paths

- `analyzePeriodogram.m`  
  Reason: older standalone periodogram-style implementation; the active flow uses the modular PSD wrappers in `psd/` and the shared core `analyzeAccelerationPSD.m`.

- `analyzeWelchPSD.m`  
  Reason: older standalone Welch implementation; redundant with the modular wrapper and shared PSD engine.

- `analyzeBurgPSD.m`  
  Reason: older standalone Burg implementation; redundant with the modular wrapper and shared PSD engine.

- `analyzeAccelerationPSD.m`  
  Reason: the core PSD engine is still kept in the root, but it is already consumed by the module wrappers. This file is a keep-or-move decision rather than a duplicate by name; the project is already using the modular entry points.

Confidence: High

### 3) Legacy helper / analysis files not used by the active orchestrator

These are not necessarily wrong, but they are not part of the active modular flow and should be reviewed manually before removal:

- `computeBandPowers.m`
- `computeGroundTruthComparison.m`
- `computeHannWindow.m`
- `computeOneSidedPSD.m`
- `computeRegionPeakFrequency.m`
- `detectTonalRegions.m`
- `estimateLocalNoiseFloor.m`
- `estimateTonalSNR.m`
- `estimateTonalSNR .m` (note the space before the extension)
- `estimateTonalSNRWrapper.m`
- `evaluateGroundTruth.m`
- `groupContiguousBins.m`
- `hannWindowManual.m`
- `mergeOverlappingRegions.m`
- `plotAccelerationSignals.m`
- `plotSNRDiagnostic.m`
- `plotTonalSNR.m`
- `plotWindowedMoments.m`
- `sanitizeFileName.m`
- `saveAnalysisResults.m`
- `validateSyntheticAnalysis.m`

Reason: these are older or alternate analysis utilities that may still be useful for experimentation, validation, or future refactors, but they are not necessary to the current modular execution path.

Confidence: Medium

## Decision summary

The project is already in a mostly-consolidated state:

- A single canonical moments implementation remains: `moments/analyzeWindowedMoments.m`
- A single canonical FFT implementation remains: `fft/analyzeAccelFFT.m`
- The active orchestration uses the modular folder layout rather than the older root-level implementations
- The remaining root-level files are legacy copies or alternate utilities and should be removed only after manual review

Do not delete these files automatically. The correct next step is manual cleanup once the user confirms which old files should become permanent references or be fully retired.

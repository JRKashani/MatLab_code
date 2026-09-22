# Tonal SNR for measured signals

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

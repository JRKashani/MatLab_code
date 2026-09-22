function result = runSNRAnalysis(signal, sampleRange, Fs, signalName, outputFolder, options)
%RUNSNRANALYSIS Estimate drifting/decaying tones against full-band white noise.
%   Uses only measured samples and Fs, never synthetic component settings.
%   Optional options fields are documented in estimateTonalSNR. makePlots,
%   savePng and saveFig control output. Default settings live in DEFINE.m.
%   Amplitudes are equivalent local sine peak amplitudes sqrt(2*tonePower),
%   not FFT-bin heights. Each tone's SNR uses the same full-band noise power.

    if nargin < 5 || isempty(outputFolder)
        outputFolder = fullfile(pwd, 'results');
    end
    if nargin < 4 || isempty(signalName)
        signalName = 'signal';
    end
    if nargin < 6 || isempty(options), options = struct(); end
    result = estimateTonalSNR(signal, sampleRange, Fs, options);
    result.signalName = signalName;
    result.outputFolder = outputFolder;
    result.figureHandle = [];
    result.files = {};
    if ~isfield(options, 'makePlots') || options.makePlots
        [result.figureHandle, result.files] = plotTonalSNR(result, outputFolder, options);
    end
end

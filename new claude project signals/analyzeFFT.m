function result = analyzeFFT(signal, sampleRange, Fs, options)
%ANALYZEFFT Independent FFT entry function for a selected signal range.
%
%   result = analyzeFFT(signal, sampleRange, Fs, options)
%
%   This is the normalized public FFT interface expected by the project.
%   It delegates to the existing FFT implementation but keeps the public API
%   independent from the orchestrator and from PSD modules.

    if nargin < 4 || isempty(options)
        options = struct();
    end
    if nargin < 3 || isempty(Fs)
        error('analyzeFFT:invalidFs', 'Fs is required and must be positive.');
    end
    if nargin < 2 || isempty(sampleRange)
        sampleRange = [1, numel(signal)];
    end

    if ~isnumeric(signal) || ~isvector(signal)
        error('analyzeFFT:invalidSignal', 'signal must be a numeric vector.');
    end
    if ~(isnumeric(Fs) && isscalar(Fs) && isfinite(Fs) && Fs > 0)
        error('analyzeFFT:invalidFs', 'Fs must be a positive finite scalar.');
    end

    signalName = getOption(options, 'signalName', 'signal');
    outputFolder = getOption(options, 'outputFolder', fullfile(pwd, 'results'));
    unitsLabel = getOption(options, 'unitsLabel', 'm/s^2');
    savePng = getOption(options, 'savePng', true);
    saveFig = getOption(options, 'saveFig', true);

    result = analyzeAccelFFT(signal, sampleRange, Fs, signalName, outputFolder, unitsLabel, savePng, saveFig);
    result.method = 'FFT';
end

function value = getOption(options, fieldName, defaultValue)
    if isfield(options, fieldName) && ~isempty(options.(fieldName))
        value = options.(fieldName);
    else
        value = defaultValue;
    end
end

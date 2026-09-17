function result = runFFTAnalysis(signal, sampleRange, Fs, signalName, outputFolder, unitsLabel, savePng, saveFig)
%RUNFFTANALYSIS Wrapper around the existing FFT implementation.
%   TODO: replace with a dedicated FFT module once more structure is needed.

    if nargin < 7 || isempty(savePng)
        savePng = true;
    end
    if nargin < 8 || isempty(saveFig)
        saveFig = true;
    end
    if nargin < 6 || isempty(unitsLabel)
        unitsLabel = 'm/s^2';
    end
    if nargin < 5 || isempty(outputFolder)
        outputFolder = fullfile(pwd, 'results');
    end

    result = analyzeAccelFFT(signal, sampleRange, Fs, signalName, outputFolder, unitsLabel, savePng, saveFig);
end

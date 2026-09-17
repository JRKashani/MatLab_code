function [timeSeriesFigure, histogramFigure] = plotAccelerationSignals(signalData, outputFolder, options)
%PLOTACCELERATIONSIGNALS Plot time-series and histogram diagnostics.
%
%   [TIMESERIESFIGURE, HISTOGRAMFIGURE] = PLOTACCELERATIONSIGNALS(SIGNALDATA)
%   [TIMESERIESFIGURE, HISTOGRAMFIGURE] = PLOTACCELERATIONSIGNALS(SIGNALDATA, OUTPUTFOLDER)
%   [TIMESERIESFIGURE, HISTOGRAMFIGURE] = PLOTACCELERATIONSIGNALS(SIGNALDATA, OUTPUTFOLDER, OPTIONS)
%   creates two figures from a generated acceleration-signal data set:
%   a 3-tile acceleration-vs-time overview, and a 3-tile histogram
%   comparison, and optionally saves each as .fig and/or .png.
%
%   Inputs:
%       signalData   - struct with the fields produced by
%                      generateSyntheticAccelSignal (in memory, or
%                      loaded back from its saved .mat file):
%                          .combinedSignal  - 1 x N double
%                          .pureSineSignal  - 1 x N double
%                          .pureNoiseSignal - 1 x N double
%                          .Fs              - sampling frequency [Hz]
%                          .SampleCount     - N
%       outputFolder - (optional) folder to save figures into; created
%                      if it does not exist. Defaults to
%                      fullfile(pwd, 'figures'). Unused, and never
%                      created, if both save flags in DEFINE are false.
%                      The current folder (pwd) itself is never
%                      changed.
%
%   Outputs:
%       timeSeriesFigure - figure handle for the acceleration-vs-time figure
%       histogramFigure  - figure handle for the histogram figure
%
%   Interface note: this function takes the already-loaded data struct
%   rather than a .mat file path, since the typical workflow is
%   "generate, then immediately plot" within the same session, and
%   forcing a save-then-reload round trip just to plot would be
%   wasted I/O. Loading from a previously saved .mat file is a
%   one-liner for the caller:
%       D = DEFINE();
%       loaded = load('output.mat');
%       plotAccelerationSignals(loaded.(D.MAT_ROOT_VARNAME));
%
%   This function assumes MATLAB R2020a or later (uses tiledlayout and
%   exportgraphics, both core graphics features, no toolbox required).

if nargin < 3 || isempty(options)
    options = struct();
end

options = defaultPlotOptions(options);

if nargin < 2 || isempty(outputFolder)
    outputFolder = options.outputFolder;
else
    % Guard against passing a file path (for example a saved .mat file) as
    % the output folder. In that case, use the parent directory instead.
    [outputFolder, ~, ext] = fileparts(outputFolder);
    if isempty(outputFolder)
        outputFolder = pwd;
    end
    if ~isempty(ext)
        % Keep only the directory and ignore any file-like input.
        outputFolder = outputFolder;
    end
end

requiredFields = {'combinedSignal', 'pureSineSignal', 'pureNoiseSignal', 'Fs', 'SampleCount'};
for k = 1:numel(requiredFields)
    if ~isfield(signalData, requiredFields{k})
        error('plotAccelerationSignals:missingField', ...
            'signalData is missing required field "%s".', requiredFields{k});
    end
end

maxPlotPoints     = options.maxPlotPoints;
histogramBinCount = options.histogramBinCount;
saveFigFiles      = options.saveFig;
savePngFiles      = options.savePng;

Fs = signalData.Fs;
N  = signalData.SampleCount;

signalsToPlot = {signalData.combinedSignal, signalData.pureSineSignal, signalData.pureNoiseSignal};
signalTitles  = {'Combined Signal', 'Pure Sine Signal', 'Pure Noise Signal'};

if (saveFigFiles || savePngFiles) && ~isfolder(outputFolder)
    mkdir(outputFolder);
end

% ---- Figure 1: acceleration vs time (downsampled for display only) ------
% Simple index decimation is adequate for this diagnostic overview: it
% is essentially free to compute and enough to judge overall
% shape/scale/timing. round(linspace(1,N,plotPointCount)) is used
% instead of plain 1:step:N so the very first AND last samples are
% always included exactly, regardless of whether N divides evenly by
% the step (plain 1:step:N only guarantees the first one). The real
% limitation either way: a narrow, isolated high-frequency transient
% or single-sample spike that falls between two kept indices can be
% skipped entirely and simply won't appear here. This plot is for a
% fast visual overview, not for detecting brief transients -- use the
% full-resolution data (or a min/max-envelope decimation) for that.
plotPointCount = min(N, maxPlotPoints);
plotIndices = unique(round(linspace(1, N, plotPointCount)));
plotTime = (plotIndices - 1) / Fs; % only as long as plotIndices, never a full N-sample vector

timeSeriesFigure = figure('Name', 'Acceleration vs Time');
tl1 = tiledlayout(timeSeriesFigure, 3, 1, 'TileSpacing', 'compact');
for k = 1:numel(signalsToPlot)
    nexttile(tl1);
    plot(plotTime, signalsToPlot{k}(plotIndices));
    title(signalTitles{k});
    ylabel('Acceleration [m/s^2]');
    grid on;
end
xlabel(tl1, 'Time [s]');

saveFigureInFormats(timeSeriesFigure, outputFolder, options.timeSeriesFileBase, saveFigFiles, savePngFiles);

% ---- Figure 2: histograms (full-resolution data, shared bin edges) -------
% Same bin COUNT with independently auto-chosen bin EDGES per signal is
% not sufficient for a fair comparison: combinedSignal, pureSineSignal
% and pureNoiseSignal generally have very different amplitude ranges,
% so auto-edges would give each histogram a different bin width and a
% different x-axis extent, making bar heights/shapes visually
% incomparable. Using one shared set of edges, sized to the combined
% range of all three, keeps bin width and axis limits identical, so
% shapes and heights across the three subplots are directly
% comparable. All three signals have equal length, so raw counts (the
% histogram default) are already comparable too -- no normalization
% needed. Min/max are computed per-signal first (three small 1-element
% results) rather than concatenating all three signals into one
% temporary 3N-element array, to avoid an unnecessary ~24 MB copy.
lowerBound = min([min(signalsToPlot{1}), min(signalsToPlot{2}), min(signalsToPlot{3})]);
upperBound = max([max(signalsToPlot{1}), max(signalsToPlot{2}), max(signalsToPlot{3})]);
if lowerBound == upperBound
    % Degenerate case (e.g. an all-zero signal): widen the range so
    % linspace can still produce valid, non-zero-width bin edges.
    lowerBound = lowerBound - 0.5;
    upperBound = upperBound + 0.5;
end
sharedEdges = linspace(lowerBound, upperBound, histogramBinCount + 1);

histogramFigure = figure('Name', 'Acceleration Histograms');
tl2 = tiledlayout(histogramFigure, 3, 1, 'TileSpacing', 'compact');
for k = 1:numel(signalsToPlot)
    nexttile(tl2);
    histogram(signalsToPlot{k}, 'BinEdges', sharedEdges);
    title(signalTitles{k});
    ylabel('Count');
    grid on;
end
xlabel(tl2, 'Acceleration [m/s^2]');

saveFigureInFormats(histogramFigure, outputFolder, options.histogramFileBase, saveFigFiles, savePngFiles);

end

function options = defaultPlotOptions(options)
    if nargin < 1 || isempty(options)
        options = struct();
    end

    defaults = struct();
    defaults.outputFolder = fullfile(pwd, 'figures');
    defaults.maxPlotPoints = 20000;
    defaults.histogramBinCount = 100;
    defaults.saveFig = true;
    defaults.savePng = true;
    defaults.timeSeriesFileBase = 'signal_time_series';
    defaults.histogramFileBase = 'signal_histograms';

    optionNames = fieldnames(defaults);
    for i = 1:numel(optionNames)
        name = optionNames{i};
        if ~isfield(options, name) || isempty(options.(name))
            options.(name) = defaults.(name);
        end
    end
end

% ----------------------------------------------------------------------------
function saveFigureInFormats(figHandle, outputFolder, baseFilename, saveFig, savePng)
% Local helper, intentionally not its own file: only ever called from
% within this file, once per figure, purely to avoid duplicating the
% same few lines of save logic twice. Uses the explicit figHandle
% passed in rather than gcf, so this works correctly regardless of
% what other figures are open or in focus.
if saveFig
    savefig(figHandle, fullfile(outputFolder, [baseFilename '.fig']));
end
if savePng
    exportgraphics(figHandle, fullfile(outputFolder, [baseFilename '.png']));
end
end

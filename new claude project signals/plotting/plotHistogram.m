function fig = plotHistogram(signalData, outputFolder, options)
%PLOTHISTOGRAM Plot combined/sine/noise histograms with shared edges.
%
%   fig = plotHistogram(signalData, outputFolder, options)
%
%   Inputs:
%       signalData - struct with combinedSignal, pureSineSignal,
%                    pureNoiseSignal fields
%       outputFolder - optional output directory; defaults to ./results
%       options - struct with histogramBinCount, saveFig, savePng, fileBase
%
%   Histogram edges are shared across all three signals so the distributions
%   are directly comparable.

    if nargin < 2 || isempty(outputFolder)
        outputFolder = fullfile(pwd, 'results');
    end
    if nargin < 3 || isempty(options)
        options = struct();
    end
    options = defaultHistogramOptions(options);

    if ~isstruct(signalData) || ~isfield(signalData, 'combinedSignal') || ...
       ~isfield(signalData, 'pureSineSignal') || ~isfield(signalData, 'pureNoiseSignal')
        error('plotHistogram:invalidSignalData', ...
            'signalData must include combinedSignal, pureSineSignal, and pureNoiseSignal fields.');
    end

    combined = signalData.combinedSignal(:);
    sine     = signalData.pureSineSignal(:);
    noise    = signalData.pureNoiseSignal(:);

    allValues = [combined; sine; noise];
    lowerBound = min(allValues);
    upperBound = max(allValues);
    if lowerBound == upperBound
        lowerBound = lowerBound - 0.5;
        upperBound = upperBound + 0.5;
    end
    edges = linspace(lowerBound, upperBound, options.histogramBinCount + 1);

    fig = figure('Name', 'Signal histograms', 'Color', 'w');
    tiledlayout(fig, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

    signalSet = {combined, sine, noise};
    titles = {'Combined signal', 'Pure sine signal', 'Pure noise signal'};
    for k = 1:3
        nexttile;
        histogram(signalSet{k}, edges, 'Normalization', 'count');
        title(titles{k});
        xlabel('Amplitude');
        ylabel('Count');
        grid on;
    end

    if ~exist(outputFolder, 'dir')
        mkdir(outputFolder);
    end

    if options.saveFig
        savefig(fig, fullfile(outputFolder, [options.fileBase '.fig']));
    end
    if options.savePng
        exportgraphics(fig, fullfile(outputFolder, [options.fileBase '.png']), 'Resolution', 300);
    end
end

function options = defaultHistogramOptions(options)
    defaults = struct();
    defaults.histogramBinCount = 100;
    defaults.saveFig = true;
    defaults.savePng = true;
    defaults.fileBase = 'signal_histograms';

    names = fieldnames(defaults);
    for i = 1:numel(names)
        name = names{i};
        if ~isfield(options, name) || isempty(options.(name))
            options.(name) = defaults.(name);
        end
    end
end

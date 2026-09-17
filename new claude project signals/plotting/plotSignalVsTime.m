function fig = plotSignalVsTime(signalData, outputFolder, options)
%PLOTSIGNALVSTIME Plot combined/sine/noise signals vs time in a tiled layout.
%
%   fig = plotSignalVsTime(signalData, outputFolder, options)
%
%   Inputs:
%       signalData - struct with fields:
%                    combinedSignal, pureSineSignal, pureNoiseSignal, Fs
%       outputFolder - optional output directory; defaults to ./results
%       options - optional struct with fields:
%                 maxPlotPoints, saveFig, savePng, fileBase
%
%   The original data are never modified; for very long signals, only the
%   displayed samples are downsampled for plotting.

    if nargin < 2 || isempty(outputFolder)
        outputFolder = fullfile(pwd, 'results');
    end
    if nargin < 3 || isempty(options)
        options = struct();
    end
    options = defaultSignalPlotOptions(options);

    if ~isstruct(signalData) || ~isfield(signalData, 'combinedSignal') || ...
       ~isfield(signalData, 'pureSineSignal') || ~isfield(signalData, 'pureNoiseSignal')
        error('plotSignalVsTime:invalidSignalData', ...
            'signalData must include combinedSignal, pureSineSignal, and pureNoiseSignal fields.');
    end

    if ~isfield(signalData, 'Fs') || isempty(signalData.Fs) || ~isscalar(signalData.Fs) || signalData.Fs <= 0
        error('plotSignalVsTime:invalidFs', 'signalData.Fs must be a positive scalar.');
    end

    combined = signalData.combinedSignal(:);
    sine     = signalData.pureSineSignal(:);
    noise    = signalData.pureNoiseSignal(:);
    N        = max([numel(combined), numel(sine), numel(noise)]);

    if ~isfield(signalData, 'time') || isempty(signalData.time)
        time = (0:N-1)' / signalData.Fs;
    else
        time = signalData.time(:);
    end

    if numel(time) < N
        time = (0:N-1)' / signalData.Fs;
    end

    signalSet = {combined, sine, noise};
    titles = {'Combined signal', 'Pure sine signal', 'Pure noise signal'};
    colors = {'b', 'r', 'k'};

    if numel(time) > options.maxPlotPoints
        idx = unique(round(linspace(1, numel(time), options.maxPlotPoints)));
        timePlot = time(idx);
    else
        idx = 1:numel(time);
        timePlot = time;
    end

    fig = figure('Name', 'Signal vs time', 'Color', 'w');
    tiledlayout(fig, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

    for k = 1:3
        nexttile;
        plot(timePlot, signalSet{k}(idx), colors{k}, 'LineWidth', 1.1);
        title(titles{k});
        xlabel('Time [s]');
        ylabel('Amplitude');
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

function options = defaultSignalPlotOptions(options)
    defaults = struct();
    defaults.maxPlotPoints = 20000;
    defaults.saveFig = true;
    defaults.savePng = true;
    defaults.fileBase = 'signal_vs_time';

    names = fieldnames(defaults);
    for i = 1:numel(names)
        name = names{i};
        if ~isfield(options, name) || isempty(options.(name))
            options.(name) = defaults.(name);
        end
    end
end

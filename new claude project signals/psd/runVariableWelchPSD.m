function result = runVariableWelchPSD(signal, sampleRange, Fs, fftResult, signalName, outputFolder, options)
%RUNVARIABLEWELCHPSD One linear PSD curve with marked resolution boundaries.
    if nargin < 7, options = struct(); end
    if nargin < 6 || isempty(outputFolder), outputFolder = fullfile(pwd, 'results'); end
    if nargin < 5 || isempty(signalName), signalName = 'signal'; end
    if ~isstruct(fftResult) || ~isscalar(fftResult) || ~isfield(fftResult, 'allPeakFrequenciesHz')
        error('runVariableWelchPSD:missingFFT', ...
            'Variable Welch requires successful FFT peak detection. Enable RUN_FFT.');
    end
    if isempty(sampleRange), sampleRange = [1 numel(signal)]; end
    if ~isequal(sampleRange(:).', fftResult.sampleRange(:).') || ...
            abs(fftResult.frequencyResolutionHz*fftResult.sampleCount-Fs) > 1e-10*Fs
        error('runVariableWelchPSD:incompatibleFFT', 'FFT must use the same sample range and sampling rate.');
    end
    result = computeVariableWelchPSD(signal, sampleRange, Fs, fftResult.allPeakFrequenciesHz, options);
    result.figureHandle = [];
    result.files = {};
    if isfield(options, 'makePlots') && ~options.makePlots, return; end
    fig = figure('Name', ['Variable-resolution Welch - ' signalName], 'WindowStyle', 'docked');
    ax = axes('Parent', fig);
    plot(ax, result.f, result.psd, 'b-', 'LineWidth', 1.2, ...
        'DisplayName', 'Variable-resolution Welch PSD', 'Tag', 'variableWelchCurve');
    set(ax, 'YScale', 'linear');
    xlabel(ax, 'Frequency [Hz]');
    ylabel(ax, 'Power spectral density [m^2/s^4/Hz]');
    title(ax, ['Variable-resolution Welch: ' signalName], 'Interpreter', 'none');
    if isempty(result.fineBandsHz)
        subtitle(ax, sprintf('No nonzero peak bands | Background resolution %.5g [Hz]', result.coarseResolutionHz));
    else
        subtitle(ax, sprintf('Background %.5g [Hz] | Peak bands %.5g [Hz] (%g times finer) | Dashed lines: resolution changes', ...
            result.coarseResolutionHz, result.fineResolutionHz, result.resolutionRatio));
    end
    grid(ax, 'on');
    xlim(ax, [0 Fs/2]);
    for k = 1:numel(result.transitionFrequenciesHz)
        boundary = result.transitionFrequenciesHz(k);
        alignment = 'top';
        if mod(k,2) == 0, alignment = 'bottom'; end
        xline(ax, boundary, '--', sprintf('%.4g [Hz]', boundary), ...
            'Color', [0.8 0.3 0], 'LineWidth', 1.2, ...
            'LabelVerticalAlignment', alignment, 'HandleVisibility', 'off', ...
            'Tag', 'welchResolutionBoundary');
    end
    addPSDIntegralLegendEntry(ax, result.integratedPower, 'whole curve');
    legend(ax, 'show', 'Location', 'best', 'Interpreter', 'none');
    result.figureHandle = fig;
    D = DEFINE();
    savePng = D.SAVE_PNG_FILES; saveFig = D.SAVE_FIG_FILES;
    if isfield(options, 'savePng'), savePng = options.savePng; end
    if isfield(options, 'saveFig'), saveFig = options.saveFig; end
    if savePng || saveFig
        if ~exist(outputFolder, 'dir'), mkdir(outputFolder); end
        base = fullfile(outputFolder, 'welch_variable_resolution');
        if savePng
            result.files{end+1} = [base '.png'];
            exportgraphics(fig, result.files{end}, 'Resolution', 300);
        end
        if saveFig
            result.files{end+1} = [base '.fig'];
            savefig(fig, result.files{end});
        end
    end
end

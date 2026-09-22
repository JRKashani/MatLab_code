function [fig, files] = plotTonalSNR(result, outputFolder, options)
%PLOTTONALSNR Noise floor, detected frequency/amplitude tracks and local SNR.
    D = DEFINE();
    if ~isfield(options,'savePng'), options.savePng = D.SAVE_PNG_FILES; end
    if ~isfield(options,'saveFig'), options.saveFig = D.SAVE_FIG_FILES; end
    fig = figure('Name', ['Tonal SNR - ' result.signalName], 'Color', 'w', ...
        'Position', [80 80 1200 800]);
    layout = tiledlayout(fig,2,2,'TileSpacing','compact','Padding','compact');
    title(layout,sprintf('%s | Tonal SNR %.3g dB | White-noise RMS %.4g | Band 0-%.4g Hz', ...
        result.signalName,result.overallSNRdB,result.noiseRMS,result.Fs/2),'Interpreter','none');
    colors = lines(max(1,numel(result.tracks)));
    ax = nexttile(layout);
    plot(ax,result.frequencyHz,10*log10(max(result.meanPSD,realmin)), 'DisplayName','Mean PSD');
    hold(ax,'on');
    if result.whiteNoisePSD > 0
        yline(ax,10*log10(result.whiteNoisePSD),'--r','DisplayName','Estimated white noise');
    end
    xlabel(ax,'Frequency [Hz]'); ylabel(ax,'PSD [dB/Hz]');
    title(ax,'Measured spectrum and estimated noise floor'); grid(ax,'on'); legend(ax,'show');
    xlim(ax,[0 result.Fs/2]);

    ax = nexttile(layout); hold(ax,'on');
    for k = 1:numel(result.tracks)
        plot(ax,result.frames.time,result.tracks(k).frequencyHz,'.-', ...
            'Color',colors(k,:),'DisplayName',sprintf('Tone %d',k));
    end
    xlabel(ax,'Time in recording [s]'); ylabel(ax,'Frequency [Hz]');
    title(ax,'Detected frequency tracks'); grid(ax,'on');
    if ~isempty(result.tracks), legend(ax,'show','Location','best'); end

    ax = nexttile(layout); hold(ax,'on');
    for k = 1:numel(result.tracks)
        plot(ax,result.frames.time,result.tracks(k).amplitude,'Color',colors(k,:), ...
            'DisplayName',sprintf('Tone %d amplitude',k));
    end
    plot(ax,result.frames.time,result.frames.noiseRMS,'--k','DisplayName','White-noise RMS');
    xlabel(ax,'Time in recording [s]'); ylabel(ax,'Signal units');
    title(ax,'Equivalent sine peak amplitude and noise RMS'); grid(ax,'on'); legend(ax,'show');

    ax = nexttile(layout);
    values = result.frames.snrDb;
    values(~isfinite(values)) = NaN;
    plot(ax,result.frames.time,values,'LineWidth',1.2);
    xlabel(ax,'Time in recording [s]'); ylabel(ax,'SNR [dB]');
    title(ax,'Combined detected tones / full-band noise'); grid(ax,'on');
    if ~strcmp(result.status,'ok') || ~isempty(result.notes)
        subtitle(layout,strjoin([{strrep(result.status,'_',' ')}, result.notes], ' | '), ...
            'Interpreter','none');
    end
    files = {};
    if options.savePng || options.saveFig
        if ~exist(outputFolder,'dir'), mkdir(outputFolder); end
        base = fullfile(outputFolder,'snr_analysis');
        if options.savePng
            files{end+1} = [base '.png'];
            exportgraphics(fig,files{end},'Resolution',200);
        end
        if options.saveFig
            files{end+1} = [base '.fig'];
            savefig(fig,files{end});
        end
    end
end

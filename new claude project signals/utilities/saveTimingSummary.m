function result = saveTimingSummary(missionSeconds, outputFolder, analysisSaved)
%SAVETIMINGSUMMARY Persist wall-clock seconds after the numerical saves finish.
%   Timings include plotting/export within each mission and failed missions.
%   Total stops before this reporting step; setup overhead is included in total.
%   Append to analysis summaries only when this run wrote them successfully.

    names = fieldnames(missionSeconds);
    txtPath = fullfile(outputFolder, 'timing_summary.txt');
    fid = fopen(txtPath, 'w');
    if fid == -1
        error('saveTimingSummary:cannotWrite', 'Could not write %s.', txtPath);
    end
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, 'Elapsed wall time in seconds (includes plots and exports)\n');
    for k = 1:numel(names)
        fprintf(fid, '%s: %.3f s\n', names{k}, missionSeconds.(names{k}));
    end
    fprintf(fid, 'Total measured before timing-report persistence.\n');
    clear cleanup;

    save(fullfile(outputFolder, 'final_results.mat'), 'missionSeconds', '-append');
    if analysisSaved
        save(fullfile(outputFolder, 'analysis_results.mat'), 'missionSeconds', '-append');
        fid = fopen(fullfile(outputFolder, 'analysis_summary.txt'), 'a');
        if fid == -1
            error('saveTimingSummary:cannotAppend', 'Could not append timing to text summary.');
        end
        cleanup = onCleanup(@() fclose(fid));
        fprintf(fid, '\nElapsed wall time (seconds, includes plots and exports):\n');
        for k = 1:numel(names)
            fprintf(fid, '  %s: %.3f s\n', names{k}, missionSeconds.(names{k}));
        end
        fprintf(fid, 'Total measured before timing-report persistence.\n');
        clear cleanup;

        fid = fopen(fullfile(outputFolder, 'analysis_summary.csv'), 'a');
        if fid == -1
            error('saveTimingSummary:cannotAppend', 'Could not append timing to CSV summary.');
        end
        cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
        for k = 1:numel(names)
            fprintf(fid, '%s_seconds,%.9g\n', names{k}, missionSeconds.(names{k}));
        end
    end
    result = struct('missionSeconds', missionSeconds, 'outputFile', txtPath);
end

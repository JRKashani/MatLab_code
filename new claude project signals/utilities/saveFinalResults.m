function saveFinalResults(outputPath, results, missionStatus, flags)
%SAVEFINALRESULTS Persist final numerical results and mission status.
%   This is the single place that writes the end-of-run summary file.

    if nargin < 4 || isempty(flags)
        flags = struct();
    end

    if nargin < 3 || isempty(missionStatus)
        missionStatus = struct();
    end

    if nargin < 2 || isempty(results)
        results = struct();
    end

    save(outputPath, 'results', 'missionStatus', 'flags');
end

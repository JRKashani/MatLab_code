function [status, result] = runMission(fid, missionName, missionFn)
%RUNMISSION Isolate a mission failure, retaining its diagnostics and results.
%   Exceptions are logged with a stack trace and printed briefly to stderr.
%   A returned allPassed=false or status='not_implemented' is also a failure:
%   executing a validator successfully is different from passing its checks.
%   Pass [] for fid to use console reporting without a log file.

    status = false;
    result = [];
    try
        if nargin < 3 || ~isa(missionFn, 'function_handle')
            error('runMission:missingFunction', 'A mission function handle is required.');
        end
        result = missionFn();
        status = true;
        reason = '';
        if isstruct(result) && isscalar(result)
            if isfield(result, 'allPassed') && ~result.allPassed
                status = false;
                reason = 'Validation checks failed.';
                if isfield(result, 'failedTests') && ~isempty(result.failedTests)
                    reason = ['Failed checks: ' strjoin(cellstr(result.failedTests), ', ')];
                end
            elseif isfield(result, 'status') && strcmp(result.status, 'not_implemented')
                status = false;
                reason = 'This mission is not implemented.';
            end
        end
        if status
            fprintf('SUCCESS: %s\n', missionName);
            if ~isempty(fid), fprintf(fid, 'SUCCESS: %s\n', missionName); end
        else
            fprintf(2, 'FAILURE: %s - %s\n', missionName, reason);
            if ~isempty(fid), fprintf(fid, 'FAILURE: %s - %s\n', missionName, reason); end
        end
    catch ME
        status = false;
        fprintf(2, 'FAILURE: %s - %s\n', missionName, ME.message);
        if ~isempty(fid)
            fprintf(fid, 'FAILURE: %s\n%s\n', missionName, getReport(ME, 'extended', 'hyperlinks', 'off'));
        end
    end
end

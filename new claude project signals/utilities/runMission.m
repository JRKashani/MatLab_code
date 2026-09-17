function [status, result] = runMission(fid, missionName, missionFn)
%RUNMISSION Execute one mission and log success or failure without aborting the run.
%   Returns both the boolean status and the mission result object.

    status = false;
    result = [];
    try
        if nargin >= 3 && ~isempty(missionFn)
            result = missionFn();
        end
        status = true;
        if nargin >= 2 && ~isempty(fid)
            fprintf(fid, 'SUCCESS: %s\n', missionName);
        end
    catch ME
        if nargin >= 2 && ~isempty(fid)
            fprintf(fid, 'FAILURE: %s\n%s\n', missionName, getReport(ME));
        end
    end
end

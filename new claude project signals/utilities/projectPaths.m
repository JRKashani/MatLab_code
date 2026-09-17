function paths = projectPaths(projectRoot)
%PROJECTPATHS Return canonical project paths used by the orchestrator.
%   This keeps path setup in one place and gives each mission a stable
%   set of directories to read and write from.

    if nargin < 1 || isempty(projectRoot)
        projectRoot = fileparts(fileparts(mfilename('fullpath')));
    end

    paths = struct();
    paths.projectRoot = projectRoot;
    paths.resultsDir = fullfile(projectRoot, 'results');
    paths.generationDir = fullfile(projectRoot, 'generation');
    paths.configPath = fullfile(paths.generationDir, 'main_config.txt');
    paths.signalMatPath = fullfile(paths.resultsDir, 'synthetic_accel_data.mat');
    paths.logFile = fullfile(paths.resultsDir, 'mission_log.txt');
    paths.finalResultsPath = fullfile(paths.resultsDir, 'final_results.mat');
    paths.plottingDir = fullfile(projectRoot, 'plotting');
    paths.momentsDir = fullfile(projectRoot, 'moments');
    paths.fftDir = fullfile(projectRoot, 'fft');
    paths.psdDir = fullfile(projectRoot, 'psd');
    paths.snrDir = fullfile(projectRoot, 'snr');
    paths.validationDir = fullfile(projectRoot, 'validation');
    paths.utilitiesDir = fullfile(projectRoot, 'utilities');
end

function result = runSignalGeneration(configPath, outputMatPath)
%RUNSIGNALGENERATION Generate or reload the synthetic signal dataset.
%   This is intentionally thin and keeps the underlying algorithm in the
%   dedicated generation implementation.

    if nargin < 2 || isempty(outputMatPath)
        outputMatPath = '';
    end

    [signals, cfg] = generateSyntheticAccelSignal(configPath, outputMatPath);
    signal = signals.combinedSignal(:);
    time = (0:numel(signal)-1)' / cfg.Fs;

    result = struct();
    result.signals = signals;
    result.cfg = cfg;
    result.signal = signal;
    result.time = time;
    result.sampleRange = [1, numel(signal)];
end

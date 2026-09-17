function saveAnalysisResults(results, metadata, outputFolder)
%SAVEANALYSISRESULTS Save compact analysis outputs and a readable summary.
%
%   saveAnalysisResults(results, metadata, outputFolder)
%
%   The MAT file keeps the full numerical result structs for later reuse.
%   The text/CSV summary keeps only useful scalar information and deliberately
%   avoids dumping raw signal arrays or full FFT/PSD spectra to CSV.

    if nargin < 3 || isempty(outputFolder)
        outputFolder = fullfile(pwd, 'results');
    end
    if nargin < 2 || isempty(metadata)
        metadata = struct();
    end
    if nargin < 1 || isempty(results)
        results = struct();
    end

    if ~exist(outputFolder, 'dir')
        mkdir(outputFolder);
    end

    allowedFields = {'windowedMoments', 'fft', 'periodogram', 'welch', 'burg', 'snr', 'validation'};
    analysisSubset = struct();
    for k = 1:numel(allowedFields)
        fieldName = allowedFields{k};
        if isfield(results, fieldName)
            analysisSubset.(fieldName) = results.(fieldName);
        end
    end

    matPath = fullfile(outputFolder, 'analysis_results.mat');
    save(matPath, 'analysisSubset', 'metadata', '-v7');

    summaryText = buildAnalysisSummary(analysisSubset, metadata);
    txtPath = fullfile(outputFolder, 'analysis_summary.txt');
    fid = fopen(txtPath, 'w');
    if fid == -1
        error('saveAnalysisResults:cannotWriteSummary', 'Could not write summary file at %s.', txtPath);
    end
    fprintf(fid, '%s', summaryText);
    fclose(fid);

    csvPath = fullfile(outputFolder, 'analysis_summary.csv');
    csvStruct = collectScalarSummary(analysisSubset, metadata);
    writeScalarCsv(csvPath, csvStruct);
end

function summaryText = buildAnalysisSummary(analysisSubset, metadata)
    lines = {};
    lines{end+1} = 'Synthetic analysis summary';
    lines{end+1} = '=========================';

    if ~isempty(metadata)
        if isfield(metadata, 'sampleRange')
            lines{end+1} = sprintf('Sample range: [%d %d]', metadata.sampleRange(1), metadata.sampleRange(2));
        end
        if isfield(metadata, 'Fs')
            lines{end+1} = sprintf('Fs: %.6g Hz', metadata.Fs);
        end
        if isfield(metadata, 'meanDc')
            lines{end+1} = sprintf('DC mean: %.6g', metadata.meanDc);
        end
    end

    if isfield(analysisSubset, 'windowedMoments')
        moments = analysisSubset.windowedMoments;
        if isfield(moments, 'summary') && ~isempty(moments.summary)
            w = moments.windowLengths;
            if ~isempty(w)
                lines{end+1} = sprintf('Moment windows: %s', mat2str(w(:).')); 
            end
        end
    end

    if isfield(analysisSubset, 'fft')
        fftRes = analysisSubset.fft;
        if isfield(fftRes, 'peakFrequenciesHz') && ~isempty(fftRes.peakFrequenciesHz)
            freqs = fftRes.peakFrequenciesHz(:).';
            amps = fftRes.peakAmplitudes(:).';
            peakList = sprintf('%.3fHz@%.3g; ', [freqs; amps]);
            lines{end+1} = sprintf('FFT dominant peaks: %s', peakList(1:end-2));
        end
        if isfield(fftRes, 'meanAcceleration')
            lines{end+1} = sprintf('FFT DC mean: %.6g', fftRes.meanAcceleration);
        end
    end

    if isfield(analysisSubset, 'periodogram')
        per = analysisSubset.periodogram;
        if isfield(per, 'windows')
            lines{end+1} = sprintf('Periodogram windows: %s', strjoin(cellstr(per.windows), ', '));
        end
        if isfield(per, 'nfftFactors')
            lines{end+1} = sprintf('Periodogram NFFT factors: %s', mat2str(per.nfftFactors));
        end
    end

    if isfield(analysisSubset, 'welch')
        wel = analysisSubset.welch;
        if isfield(wel, 'windows')
            lines{end+1} = sprintf('Welch windows: %s', strjoin(cellstr(wel.windows), ', '));
        end
        if isfield(wel, 'segmentSecondsList')
            lines{end+1} = sprintf('Welch segment lengths: %s', mat2str(wel.segmentSecondsList));
        end
    end

    if isfield(analysisSubset, 'burg')
        burg = analysisSubset.burg;
        if isfield(burg, 'orders')
            lines{end+1} = sprintf('Burg orders: %s', mat2str(burg.orders));
        end
    end

    if isfield(analysisSubset, 'snr')
        snrRes = analysisSubset.snr;
        if isfield(snrRes, 'overallSNRdB')
            lines{end+1} = sprintf('Overall tonal SNR: %.4f dB', snrRes.overallSNRdB);
        end
        if isfield(snrRes, 'peakSNRdB') && ~isempty(snrRes.peakSNRdB)
            lines{end+1} = sprintf('Per-tone SNR dB: %s', mat2str(snrRes.peakSNRdB(:).')); 
        end
    end

    if isfield(analysisSubset, 'validation')
        val = analysisSubset.validation;
        if isfield(val, 'allPassed')
            lines{end+1} = sprintf('Validation: %s', bool2Str(val.allPassed));
        end
        if isfield(val, 'failedTests') && ~isempty(val.failedTests)
            lines{end+1} = sprintf('Failed tests: %d', numel(val.failedTests));
        end
    end

    lines{end+1} = '';
    summaryText = strjoin(lines, sprintf('\n'));
end

function csvStruct = collectScalarSummary(analysisSubset, metadata)
    csvStruct = struct();
    csvStruct.sampleRange = '';
    csvStruct.Fs = '';
    csvStruct.DC_mean = '';
    csvStruct.FFT_dominant_peaks = '';
    csvStruct.Overall_SNR_dB = '';
    csvStruct.Periodogram_windows = '';
    csvStruct.Welch_windows = '';
    csvStruct.Burg_orders = '';
    csvStruct.Validation = '';

    if ~isempty(metadata)
        if isfield(metadata, 'sampleRange')
            csvStruct.sampleRange = sprintf('[%d %d]', metadata.sampleRange(1), metadata.sampleRange(2));
        end
        if isfield(metadata, 'Fs')
            csvStruct.Fs = sprintf('%.6g', metadata.Fs);
        end
        if isfield(metadata, 'meanDc')
            csvStruct.DC_mean = sprintf('%.6g', metadata.meanDc);
        end
    end

    if isfield(analysisSubset, 'fft')
        fftRes = analysisSubset.fft;
        if isfield(fftRes, 'peakFrequenciesHz') && ~isempty(fftRes.peakFrequenciesHz)
            csvStruct.FFT_dominant_peaks = sprintf('%s', mat2str(fftRes.peakFrequenciesHz(:).'));
        end
        if isfield(fftRes, 'meanAcceleration')
            csvStruct.DC_mean = sprintf('%.6g', fftRes.meanAcceleration);
        end
    end

    if isfield(analysisSubset, 'snr')
        snrRes = analysisSubset.snr;
        if isfield(snrRes, 'overallSNRdB')
            csvStruct.Overall_SNR_dB = sprintf('%.6g', snrRes.overallSNRdB);
        end
    end

    if isfield(analysisSubset, 'periodogram') && isfield(analysisSubset.periodogram, 'windows')
        csvStruct.Periodogram_windows = strjoin(cellstr(analysisSubset.periodogram.windows), ';');
    end
    if isfield(analysisSubset, 'welch') && isfield(analysisSubset.welch, 'windows')
        csvStruct.Welch_windows = strjoin(cellstr(analysisSubset.welch.windows), ';');
    end
    if isfield(analysisSubset, 'burg') && isfield(analysisSubset.burg, 'orders')
        csvStruct.Burg_orders = mat2str(analysisSubset.burg.orders(:).');
    end
    if isfield(analysisSubset, 'validation') && isfield(analysisSubset.validation, 'allPassed')
        csvStruct.Validation = bool2Str(analysisSubset.validation.allPassed);
    end
end

function writeScalarCsv(csvPath, csvStruct)
    fieldNames = fieldnames(csvStruct);
    fid = fopen(csvPath, 'w');
    if fid == -1
        error('saveAnalysisResults:cannotWriteCsv', 'Could not write CSV summary at %s.', csvPath);
    end
    fprintf(fid, 'key,value\n');
    for k = 1:numel(fieldNames)
        key = fieldNames{k};
        val = csvStruct.(key);
        if ~ischar(val)
            val = mat2str(val);
        end
        fprintf(fid, '%s,%s\n', key, strrep(val, ',', ';'));
    end
    fclose(fid);
end

function text = bool2Str(flag)
    if flag
        text = 'PASS';
    else
        text = 'FAIL';
    end
end

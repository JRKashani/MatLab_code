function cleanName = sanitizeFileName(rawName)
%SANITIZEFILENAME Make a string safe to use as a filename on Windows/macOS/Linux.
%
%   cleanName = SANITIZEFILENAME(rawName) replaces characters that are
%   invalid or awkward in filenames with underscores, collapses repeated
%   underscores/whitespace, and falls back to a default name if the
%   result would otherwise be empty.
%
%   Input:
%       rawName - char or string
%   Output:
%       cleanName - char row vector, safe to use as a filename (without
%                   extension)

    rawName = char(rawName);

    invalidChars = '[<>:"/\\|?*\x00-\x1F]';
    cleanName = regexprep(rawName, invalidChars, '_');
    cleanName = regexprep(cleanName, '\s+', '_');
    cleanName = regexprep(cleanName, '_+', '_');
    cleanName = strtrim(cleanName);

    if isempty(cleanName)
        cleanName = 'signal';
    end
end

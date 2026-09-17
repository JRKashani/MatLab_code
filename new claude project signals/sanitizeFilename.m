function cleanName = sanitizeFilename(rawName)
%SANITIZEFILENAME Make a string safe to use as (part of) a file name.
%
% cleanName = sanitizeFilename(rawName)
%
% Replaces any character that is not a letter, digit, underscore, or
% hyphen with an underscore, collapses repeated underscores, and trims
% leading/trailing underscores. Falls back to 'signal' if the result
% would otherwise be empty.

cleanName = regexprep(rawName, '[^a-zA-Z0-9_\-]', '_');
cleanName = regexprep(cleanName, '_+', '_');
cleanName = regexprep(cleanName, '(^_|_$)', '');

if isempty(cleanName)
    cleanName = 'signal';
end
end

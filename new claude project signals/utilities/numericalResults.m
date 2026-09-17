function value = numericalResults(value)
%NUMERICALRESULTS Remove live graphics from a copy of a result bundle.
%   Saving a figure handle serializes its plotted data and graphics tree.
%   Numerical MAT files already contain the traces; FIG files store graphics
%   separately. Keep all numerical fields while clearing graphics objects.
    if isstruct(value)
        for k = 1:numel(value)
            names = fieldnames(value(k));
            for j = 1:numel(names)
                value(k).(names{j}) = numericalResults(value(k).(names{j}));
            end
        end
    elseif iscell(value)
        for k = 1:numel(value)
            value{k} = numericalResults(value{k});
        end
    elseif isa(value, 'matlab.graphics.Graphics')
        value = [];
    end
end

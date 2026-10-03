function entry = addPSDIntegralLegendEntry(ax, integratedPower, description)
%ADDPSDINTEGRALLEGENDENTRY Text-only legend row; no additional data curve.
    label = sprintf('Integral (%s): %.6g [m^2/s^4]', description, integratedPower);
    entry = patch('Parent', ax, 'XData', NaN, 'YData', NaN, ...
        'FaceColor', 'none', 'EdgeColor', 'none', ...
        'DisplayName', label, 'Tag', 'psdIntegralLegend');
end

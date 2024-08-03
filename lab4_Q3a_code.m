%%clc;
month = input("Please enter a month number, an integer between 1 to 12: ");
year = input("Please enter a year later than 2015: ");
if ~isnumeric(month) || ~isnumeric(year)
    fprintf("At least one value is not numeric\n");
    return;
elseif ~(month == fix(month)) || ~(year == fix(year))
    fprintf("At least one value is not an integer\n");
    return
elseif month < 1 || month > 12 || year < 2015
    fprintf("At least one value is outside the allowed perimeters\n");
    return
else
    if month == 4 ||  month == 6 || month == 9 || month == 11
        fprintf("The month have 30 days!\n");
    elseif month == 2
        if mod(year, 4) == 0
            fprintf("The month have 29 days!\n");
        else
            fprintf("The month have 28 days!\n");
        end
    else
        fprintf("The month have 31 days!");
    end
end

%%clc;
first_battary_stat = logical(input('Please enter the status of the first battary ("0" if it doesn''t work anymore, "1" if it does): '));
second_battary_stat = logical(input('Please enter the status of the second battary: '));
third_battary_stat = logical(input('Please enter the status of the third battary: '));
fourth_battary_stat = logical(input('Please enter the status of the fourth battary: '));
fifth_battary_stat = logical(input('Please enter the status of the fifth battary: '));
first_battary_voltage = 3;
second_battary_voltage = 3;
third_battary_voltage = 4;
fourth_battary_voltage = 4;
fifth_battary_voltage = 5;
voltage_sum = first_battary_stat*first_battary_voltage +...
    second_battary_stat*second_battary_voltage + third_battary_stat*...
    third_battary_voltage + fourth_battary_voltage*fourth_battary_stat +...
    fifth_battary_voltage*fifth_battary_stat;
warning_light = false;
if voltage_sum < 8
    warning_light = true;
end
disp(warning_light);
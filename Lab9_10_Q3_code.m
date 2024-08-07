function [] = Lab9_10_Q3_code(num_of_rows)

clc;
for i = 1:num_of_rows
    for j = 1:i
        fprintf("%d", j);
    end
    fprintf("\n");
end
function [] = triang(num_of_rows) %The function gets a number, and
%print a triangle of integers, with the number being the number of rows


for i = 1:num_of_rows
    for j = 1:i
        fprintf("%d", j); %print each number in the row, the number of...
        %digits limited by the row number
    end
    fprintf("\n"); %in the end of each iteration, open a new row
end
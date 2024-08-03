clc;
matIN = input("Please enter a squre matrix with odd number of rows (greater than 2):  ");
num_of_rows = size(matIN,1);
if num_of_rows ~= size(matIN,2) || ~mod(num_of_rows,2) || num_of_rows < 3 || ~isnumeric(matIN)
    fprintf("The matrix you entered doesn't cut it, farewell!\n");
    return;
end
fprintf("The original matrix is: \n");
disp(matIN);
matTEMP = zeros(num_of_rows);
center = ceil(num_of_rows/2);
matOUT = matIN;
matOUT(:,center) = matTEMP(:,center);
matOUT(center, :) = matTEMP(center, :);
fprintf("The matrix with the zeros-cross is: \n");
disp(matOUT);
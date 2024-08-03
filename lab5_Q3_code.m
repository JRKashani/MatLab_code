clc;
m = input("Enter the number (greater than 4) of rows of the desired matrix: ");
n = input("Enter the number (greater than 4) of columns of the desired matrix: ");
if ~(isnumeric(m)) || m < 5 || ~(isnumeric(n)) || n < 5 || n~=fix(n) || m~=fix(m)
    disp("The input isn't suitable for the function.");
    return;
end
matrixA = randi([10,99], m, n);
fprintf("The original matrix is:\n");
disp(matrixA);
frameNUM = 11;
fprintf('The matrix with a "frame" of %d''s:\n', frameNUM);
matrixB = ones(m+2,n+2) * frameNUM;
matrixB(2:end-1,2:end-1) = matrixA;
disp(matrixB);
matrixC = matrixA(2:end-1,2:end-1);
fprintf('The matrix without its original "frame":\n');
disp(matrixC);
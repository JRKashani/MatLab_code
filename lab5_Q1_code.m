clc;
m = input('Enter a matrix of at least 5 row: ');
if size(m,1) < 5 || size(m,2) < 2
    disp('The matrix must be with at least 5 rows and more then a column!');
else
    disp('The input matrix is:');
    disp(m);
    m([2,2],:) = [];
    fprintf("The matrix after removing the second and fourth rows:\n");
    disp(m);
end

clc;
vecIN = input("Enter a vector with 6 elements, please: ");
if ~isvector(vecIN) || ~isnumeric(vecIN(1)) || length(vecIN) ~= 6
    fprintf("The input wasn't according to perimeters.\n");
    return;
end
fprintf("The vector you entered is:\n");
disp(vecIN);
vecMAN = vecIN(1:end-1) + vecIN(2:end);
fprintf("The vector of sums-of-each-two-neighbouring-elements in the input vector is:\n");
disp(vecMAN);
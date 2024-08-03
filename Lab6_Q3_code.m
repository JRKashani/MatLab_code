%Fibonacci sequence: The function will recieve 3 integers - two numbers to
%initialize the sequnce, and a third, the number of elements in the
%sequnce.
clear;
%clc;
%user input, and input checks
st_element = input("Enter the first element of the sequnce: ");
nd_element = input("Enter the second element of the sequnce: ");
num_of_elements = input("Enter the length of the desired sequnce. Positive integers only: ");
while num_of_elements <= 0 || ~(num_of_elements==fix(num_of_elements))
    num_of_elements = input("Try again. Positive integers only! ");
end
fibVEC = zeros(1,num_of_elements); %initializing the vector;
fibVEC(1) = st_element;
fibVEC(2) = nd_element;
for i = 3:num_of_elements
    fibVEC(i) = fibVEC(i-1) + fibVEC(i-2); %adding two previous elements to make the third.
end
disp(fibVEC);
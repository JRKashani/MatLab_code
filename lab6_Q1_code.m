%integerCounter.m - asks for 5 numbers from the user, count how many are
%integers and print the number.
clear;
%clc;
num_order = ["first", "second", "third", "fourth", "fifth"];
% vector to use for the printing order
numVEC = zeros(1,5);
% initalizing the vector
int_counter = 0;
%initializing the integer counter
for i=1:length(numVEC) %loop for each element in the vector
    fprintf("Enter the %s number of the sequence, valued between 1 and 15 please:\n", num_order(i));
    numVEC(i) = input(""); %to use the number name vector, fprintf must be used
    while ~(numVEC(i) >= 1 && numVEC(i) <= 15) %checking if the input is in the right range
        %if it's not, asking to re-enter the same element, but with proper
        %value.
        numVEC(i) = input("It seems the number is not in the desired range (1-15), try again please: ");
    end
    if numVEC(i) == fix(numVEC(i)) %checking if the element is an integer
        int_counter = int_counter + 1; %adding to the couner.
    end
end
fprintf("The number of integers you entered is %d\n", int_counter); %printing results

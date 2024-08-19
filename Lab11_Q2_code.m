clc; clear;
%The script receive a number and print a sequnce of letters, with a single
%'a', double 'b' and so forth up to the letter of the chosen number.

num_of_letters = input("How many different letters would you like to see? ");

%input tests
num_of_letters = valid_input(num_of_letters);

first_letter = double('a') - 1; %to make the math parts make sense.
o_str = []; %initialize the string

for current_letter = 1:num_of_letters
    for j = 1:current_letter
        o_str = [o_str, char(first_letter + current_letter)];
        %the string will increase its size with each iteration, but it
        %won't be longer the 26*26 iterations, so not too bad.
    end
end

%printing the results
fprintf("The output string is:\n");
disp(o_str);


function verified_input = valid_input(sus_input) %a function to reduce
%wasteage of code
     invalid_input = true;
     while invalid_input
         if ~isnumeric(sus_input)
             sus_input = input("It seems not to be a numeric value at all! Try again: ");
         elseif ~isscalar(sus_input)
             sus_input = input("It seems not to be a scalar value. Try again: ");
         elseif fix(sus_input) ~= sus_input
             sus_input = input("It seems not to be a positive integer. Try again: ");
         elseif sus_input > 26
              sus_input = input("It seems to be to large of a number. Try again. not smaller than 0, not larger than 26: ");
         elseif sus_input < 1
             sus_input = input("It seems to be to small of a number. Try again. not smaller than 0, not larger than 26: ");
         else
             verified_input = sus_input;
             return;
         end
     end
end
clc; clear;


num_of_letters = input("How many different letters would you like to see? ");
%input tests
first_letter = double('a');
%num_of_letters = num_of_letters + first_letter - 1;
o_str = [];
for i = 1:num_of_letters
    for j = 1:i
        o_str = [o_str, char(first_letter - 1 + i)];
    end
end


fprintf("The output string is: ");
disp(o_str);



%for current_letter = first_letter:num_of_letters
%    for number_of_occurences = 1:current_letter-first_letter + 1
%        fprintf("%c", current_letter);
%    end
%end

%fprintf("\n");
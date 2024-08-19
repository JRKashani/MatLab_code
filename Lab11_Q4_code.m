clc; clear;

inStr = input("Enter the string you want to encrypt: \n", 's');
shift = input("Enter the shift you'd like to apply: \n");
outStr = zeros(length(inStr));

first_letter = double('a');
last_letter = double('z');

for i = 1:length(inStr)
    current_letter = double(inStr(i));
    if current_letter >= first_letter && current_letter <= last_letter
        outStr(i) = char(mod(current_letter + first_letter - 1 + shift, 26) + first_letter - 1);
    end
end

fprintf("The sentence before encryption: \n");
disp(inStr);

fprintf("The sentence after encryption: \n");
disp(outStr);
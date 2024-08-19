clc; clear;

%the function impliment Ceaser cypher by shifting letters in a given
%sentence. As requseted, only lowercase letters are handeled.

inStr = input("Enter the string you want to encrypt: \n", 's');
shift = input("Enter the shift you'd like to apply: \n");
%outStr = char(zeros(1, length(inStr)));
outStr = inStr;
%no input tests as requested

%inizilise the comparing variables
first_letter = double('a') - 1;
last_letter = double('z');

%loop through each letter in the input
for i = 1:length(inStr)
    current_letter = double(inStr(i));
    if current_letter >= first_letter && current_letter <= last_letter
        %making sure the current letter is a lowercase letter.
        aft_shift = mod(current_letter - first_letter + shift, 26);
        %returning the letter to the desired range after the shift
        if aft_shift == 0 %handeling edge cases
            aft_shift = 26;
        end
        outStr(i) = char(aft_shift + first_letter);
    end
end

%displaying results
fprintf("The sentence before encryption: \n");
disp(inStr);

fprintf("The sentence after encryption: \n");
disp(outStr);
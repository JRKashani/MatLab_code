clc; clear;
%The function will receive a sentence and capitalize each first letter in a
%word

in_str = input("Enter a sentence you'd like to capitolize: ", 's');

%input test
while isempty(in_str)
    in_str = input("It seems you haven't entered any characters, try again please: ", 's');
end

out_str = lower(in_str); %initialize the string
out_str(1) = upper(in_str(1)); %capitalize the first word in the sentence,
%because it won't be caught by the if statement

%looking for the first letter in each word, as to define a word by the fact
%it's a letter  with a non-letter before it.
for i = 2:length(in_str)
    if (~isletter(in_str(i-1)) && in_str(i-1) ~= char(39)) && isletter(in_str(i))
        out_str(i) = upper(in_str(i));
    end
end

%displaying the results.
fprintf("Your sentence is: \n%s\n", in_str);
fprintf("Your sentence after capitolization is: \n%s\n", out_str);

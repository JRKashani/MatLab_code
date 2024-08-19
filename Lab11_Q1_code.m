קבלת %clc; clear;
%The program will receive a string from the user, and print out two
%seperated strings - the letters string, and the non-letter chararchters
%string


in_str = input("Enter your string, please: ", 's');

%input tests
while isempty(in_str)
    in_str = input("It seems you haven't entered any characters, try again please: ", 's');
end

letters_str = in_str(isletter(in_str)); %letters string
non_letters_str = in_str(~isletter(in_str)); %non-letters string

%displaying the two strings
fprintf("The letters in the string you entered are: %s\n", letters_str);
fprintf("The characters which aren't letters in the string you entered are: %s\n", non_letters_str);

clc; clear;
%The program will recieve a string from the user, and print out two
%seperated strings - the letters string, and the non-letter chararchters
%string


in_str = input("Enter your string, please: ", 's');
%no input tests required for strings

letters_str = in_str(isletter(in_str)); %letters string
non_letters_str = in_str(~isletter(in_str)); %non-letters string

fprintf("The letters in the string you entered are: \n");
disp(letters_str);

fprintf("The characters which aren't letters in the string you entered are: \n");
disp(non_letters_str);
%Function name: Palindrom_detector.m.
%The function will check if a number is a palindrom.
clear;
%clc;
subject = num2str(input("Enter a number to check if it is a palindrome: "));
%the input needs no checking, any numeric value is relevant. immidietly
%being inverted to string class
tcejbus = subject(end:-1:1);
%using simple charachters vector
if tcejbus == subject %comparing the two strings, which are a proxy to the numbers
    disp("It's a Palindrome!");
else
    disp("Not a palindrome, sorry!");
end
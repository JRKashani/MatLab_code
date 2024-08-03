%function: change_counter_loop_version.m
% the function will return the minimal number of coins and bank-notes you
% can use to pay a certain amount.
%clc;
clear;
coins_and_notes = [200, 100, 50, 20, 10, 5, 2, 1, 0.5, 0.1];
% defining the relevant coins and notes
price = input("Enter the price you want to check? ");
while price < 0 || ~(price*10 == fix(price*10))
    disp("The price must be positive and as precise as 0.1, not more.");
    price = input("Try again, please: ");
end
%recieving and checking user input
temp = price;
vecINDX = 1;
coin_counter = 0; %initializing the aid parameters
while temp >= coins_and_notes(end) %break condition is in the code below
    if temp >= coins_and_notes(vecINDX) %comparing the current change with the next available coin
        temp = temp - coins_and_notes(vecINDX); %changing the money left value
        coin_counter = coin_counter + 1;
    else
        vecINDX = vecINDX + 1; %progressing the INDX counter
    end
end
fprintf("The minimal number of coins and notes one might use to pay this price is %d.\n", coin_counter); %printing the result

function neighbouring_pixels()
%The function will recieve from the user the dimensions of a...
%matrix, initialize a random-number matrix of this size, calculate
%each occurance of a certain range of elements and print the results

exp_input = input("Enter the numer of rows, an integer between 5 and 10: ");
num_of_rows = valid_input(exp_input);

exp_input = input("Enter the numer of coloumns, an integer between 5 and 10: ");
num_of_cols = valid_input(exp_input);



function verefied_input = valid_input(sus_input) %a funtion to reduce wasteage
%of code



function neighbouring_pixels()
%The function will recieve from the user the dimensions of a...
%matrix, initialize a random-number matrix of this size, calculate
%each occurance of a certain range of elements and print the results

    exp_input = input("Enter the numer of rows, an integer between 5 and 10: ");
    num_of_rows = valid_input(exp_input);
    
    exp_input = input("Enter the numer of coloumns, an integer between 5 and 10: ");
    num_of_cols = valid_input(exp_input);
    
    pixles_value = 5*rand(num_of_rows, num_of_cols);
    steel = [0, 1.5];
    copper = [1.5, 3.4];
    iron = [3.4, 4.1];
    carbon = [4.1, 5];

    pixles_value(pixles_value < steel(2)) = 1;
    pixles_value(pixles_value < copper(2) & (pixles_value > copper(1))) = 2;
    pixles_value(pixles_value < iron(2) & (pixles_value > iron(1))) = 3;
    pixles_value(pixles_value < carbon(2) & (pixles_value > carbon(1))) = 4;
    total_amount = zeros(1,4);

    for row = 2:num_of_rows-1
        for col = 2:num_of_cols-1
            if similar_neighbours(pixles_value(row-1:row+1, col-1:col+1), 1)
                pixles_value(row-1:row+1col-1:col+1) = ...
                    pixles_value(row-1:row+1col-1:col+1) + 1;
            end
        end
    end




function verefied_input = valid_input(sus_input) %a funtion to reduce wasteage
%of code
     invalid_input = true;
     while invalid_input
         if ~isnumeric(sus_input)
             sus_input = input("It seems not to be a numeric value at all! Try again: ");
         elseif ~isscalar(sus_input)
             sus_input = input("It seems not to be a scalar value. Try again: ");
         elseif mod(sus_input,1) == 0
             sus_input = input("It seems not to be a positive integer. Try again: ");
         elseif sus_input > 10
              sus_input = input("It seems to be to large of a number. Try again. not smaller than 5, not larger than 10: ");
         elseif sus_input < 5
             sus_input = input("It seems to be to small of a number. Try again. not smaller than 5, not larger than 10: ");
         else
             invalid_input = false;
         end
     end
     verefied_input = sus_input;
end

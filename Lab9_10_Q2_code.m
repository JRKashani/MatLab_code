function neighbouring_pixels()
%The function will recieve from the user the dimensions of a...
%matrix, initialize a random-number matrix of this size, calculate
%each occurance of a certain range of elements and print the results
    
%clc; clear;
    %recieving input from the user and testing it
    exp_input = input("Enter the number of rows, an integer between 5 and 10: ");
    num_of_rows = valid_input(exp_input);
    
    exp_input = input("Enter the number of coloumns, an integer between 5 and 10: ");
    num_of_cols = valid_input(exp_input);
    
    %initiallizing the variables and vectors I will use
    pixels_value_raw = 5*rand(num_of_rows, num_of_cols);
    pixels_value = zeros(num_of_rows, num_of_cols);
    steel = [0, 1.5];
    copper = [1.5, 3.4];
    iron = [3.4, 4.1];
    carbon = [4.1, 5];
    total_amount = zeros(1,4);
    metal_names = ["steel", "copper", "iron", "carbon"];
    
    %making a range of values into a single one, for 4 different ranges
    for row = 1:num_of_rows
        for col = 1:num_of_cols
            temp = pixels_value_raw(row, col);
            if (temp < steel(2) && (temp >= steel(1)))
                pixels_value(row, col) = 1;
            elseif (temp < copper(2) && (temp >= copper(1)))
                pixels_value(row, col) = 2;
            elseif (temp < iron(2) && (temp >= iron(1)))
                pixels_value(row, col) = 3;
            elseif (temp < carbon(2) && (temp >= carbon(1)))
                pixels_value(row, col) = 4;
            end
        end
    end

    %pixels_value(pixels_value < steel(2) & (pixels_value >= steel(1)))= 1;
    %pixels_value(pixels_value < copper(2) & (pixels_value >= copper(1))) = 2;
    %pixels_value(pixels_value < iron(2) & (pixels_value >= iron(1))) = 3;
    %pixels_value(pixels_value < carbon(2) & (pixels_value >= carbon(1))) = 4;
    
    %testing each pixle in the center biggest square for similar neighbors
    %and summing up the results
    for row = 2:num_of_rows-1
        for col = 2:num_of_cols-1
            if similar_neighbours(pixels_value(row-1:row+1, col-1:col+1), 1)
                total_amount(pixels_value(row,col)) = ...
                    total_amount(pixels_value(row,col)) + 1;
            end
        end
    end

    %printing the results
    fprintf("This is the original matrix: \n");
    disp(pixels_value_raw);
    fprintf("This is the matrix after the rounding: \n");
    disp(pixels_value);
    for metal = 1:length(total_amount)
        fprintf("The amount of %s (%d) is %d.\n", metal_names(metal),...
            metal, total_amount(metal));
    end
end

function verified_input = valid_input(sus_input) %a funtion to reduce
%wasteage of code
     invalid_input = true;
     while invalid_input
         if ~isnumeric(sus_input)
             sus_input = input("It seems not to be a numeric value at all! Try again: ");
         elseif ~isscalar(sus_input)
             sus_input = input("It seems not to be a scalar value. Try again: ");
         elseif fix(sus_input) ~= sus_input
             sus_input = input("It seems not to be a positive integer. Try again: ");
         elseif sus_input > 10
              sus_input = input("It seems to be to large of a number. Try again. not smaller than 5, not larger than 10: ");
         elseif sus_input < 5
             sus_input = input("It seems to be to small of a number. Try again. not smaller than 5, not larger than 10: ");
         else
             invalid_input = false;
         end
     end
     verified_input = sus_input;
end
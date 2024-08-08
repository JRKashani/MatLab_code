
function does_have_a_neighbour = similar_neighbours(mat, no_diagonals)
    
    flex_mat = mat;
    [num_of_rows, num_of_cols] = size(flex_mat);

    if num_rows ~= num_of_cols || ~rem(num_of_rows, 2)
        disp("Wrong matrix, bro, needs to have a center.");
        return;
    end

    

    if no_diagonals
        for row = 1:num_of_rows
            for col = 1:num_of_cols
                if col == row || col == num_of_rows - row + 1
                    flex_mat(row, col) = -inf;
                end
            end
        end
        flex_mat(fix(num_of_rows/2), fix(num_of_cols/2)) = ...
            mat(fix(num_of_rows/2), fix(num_of_cols/2));
    end
    if 

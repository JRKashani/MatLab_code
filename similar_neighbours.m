
function does_have_a_neighbour = similar_neighbours(mat, no_diagonals) %the
%function check if the center of a matrix is equal to one of its
%surrounding elements. the second input is to determine if to take into
%account the diagonals.
    
    [num_of_row, num_of_col] = size(mat);
    does_have_a_neighbour = false;

    if num_of_row ~= num_of_col || ~rem(num_of_row, 2) %input tests, have
        %to have a center and be a square matrix
        disp("Wrong matrix, bro, needs to have a center.");
        return;
    end
    
    center_value = mat((num_of_row+1)/2, (num_of_col+1)/2); %isolating the
    %element which will compare everything to.

    if no_diagonals %taking the main cross, without any elements outside
        %the center row or center coloumn
        hor_vec = mat((num_of_row+1)/2, :); 
        ver_vec = mat(:, (num_of_col+1)/2);
        %initializing the center of the vectors to an unused value
        hor_vec((num_of_row+1)/2) = NaN;
        ver_vec((num_of_col+1)/2) = NaN;
        does_have_a_neighbour = any(center_value == hor_vec) || ...
            any(center_value == ver_vec);
    else
        test_mat = (mat == center_value); %the operation will return
        %a logical matrix of comparing the center value with each element
        %of the matrix, thus determine if there is another element of this
        %value
        test_mat((num_of_row+1)/2, (num_of_col+1)/2) = false;
        does_have_a_neighbour = any(test_mat(:));
    end
end
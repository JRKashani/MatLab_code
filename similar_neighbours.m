
function does_have_a_neighbour = similar_neighbours(mat, no_diagonals) %the
%function check if the center of a matrix is equal to one of its
%surrounding elements. the second input is to determine if to take into
%account the diagonals.
    
    [num_of_row, num_of_col] = size(mat);

    if num_of_row ~= num_of_col || ~rem(num_of_row, 2) %input tests, have
        %to have a center and be a square
        disp("Wrong matrix, bro, needs to have a center.");
        return;
    end
    
    flex_mat = mat;
    center_value = mat((num_of_row+1)/2, (num_of_col+1)/2);

    if no_diagonals
        hor_vec = mat((num_of_row+1)/2, :);
        ver_vec = mat(:, (num_of_col+1)/2);
        hor_vec((num_of_row+1)/2) = -inf;
        ver_vec((num_of_col+1)/2) = -inf;
    else
        
    end

    temp_bin_mat = ismember(flex_mat, center_value);
    if any(center_value == hor_vec) || any(center_value == ver_vec) ||...
            any(temp_bin_mat(:))
            does_have_a_neighbour = true;
    elseif
            does_have_a_neighbour = flase;
    end

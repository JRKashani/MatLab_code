function zeros_above %the function gets a matrix of numbers from the user,
%and rearrnge each column so the zeros will be the leading elements.

%%clc; clear;

%Accept a matrix from the user
inMAT = input("Enter a matrix of numbers, please: ");

%testing the matrix
inappropriate_input = true;
while inappropriate_input

    %test if the input is a matrix at all
    if ~ismatrix(inMAT) || ~isnumeric(inMAT)
        inMAT = input("It seems your input isn't a numeric matrix. Can you change it, please? ");
        continue; %start the test while again
    end
    
    %test for NaN and inf value
    if any(isnan(inMAT(:))) || any(isinf(inMAT(:)))
        inMAT = input('It seems there is a "NaN" or "inf" in your input. Can you change it?');
        continue; %start the test while again
    end
    %if the two conditions failed, the input is valid
    inappropriate_input = false;   
end  

    
%initalizing the output matrix and getting its size
    [numRows, numCols] = size(inMAT);
    outMAT = zeros([numRows, numCols]);


%Moving through each column
for colIdx = 1:numCols
    col = inMAT(:,colIdx); 
    nonZeroCol = col(col ~= 0); %removing the zeroes from the column
    numNonZeros = length(nonZeroCol);
    index_range = (numRows - numNonZeros + 1 : numRows); % calculating...
    %...the relevant index range for the replacement
    outMAT(index_range, colIdx) = nonZeroCol; %replace...
    %...the corresponding zeroes matrix with the non-zeroes column
end

% Displaying the results
fprintf("The matrix you entered: \n");
disp(inMAT);

fprintf("The matrix after re-arranging: \n");
disp(outMAT);

end
function zeros_above

%Accept a matrix from the user
inMAT = input("Enter a matrix of numbers, please: ");

%test the matrix
while isequal(inMAT, NaN)
    inMAT = input('It seems there is a "NaN" or "inf" in your input. Can you change it?');
end

%initalizing the output matrix and getting its size
[numRows, numCols] = size(inMAT);
outMAT = zeros([numRows, numCols]);

%Moving through each coloumn
for colIdx = 1:numCols
    col = inMAT(:,colIdx); 
    nonZeroCol = col(col ~= 0); %removing the zeroes from the coloumn
    numNonZeros = length(nonZeroCol);
    index_range = (numRows - numNonZeros + 1 : numRows); % calculating...
    %...the relevant index range for the replacement
    outMAT(index_range, colIdx) = nonZeroCol; %replace...
    %...the corresponding zeroes matrix with the non-zeroes coloumn
end

% Displaying the results
fprintf("The matrix you entered: \n");
disp(inMAT);

fprintf("The matrix after re-arranging: \n");
disp(outMAT);

end

%clc; clear;

%receiving user input and verifing it
N = input("Enter the length of the x-axis of the desired graph: ");
highset_number_to_check = valid_input(N);

%initilizing the vector and counter
Collatz_Sequences = zeros(1, highset_number_to_check);
prime_initlizers = primes(highset_number_to_check);

%assuming prime numbers will accure more than others
for i = 1:length(prime_initlizers)
    Collatz_Sequences(prime_initlizers(i)) = CoLngth(prime_initlizers(i), Collatz_Sequences);
end

%loop through each number smaller than the input and find its sequnce
%length. insert it to the vector
for i = 1:highset_number_to_check
    if Collatz_Sequences(i) == 0
        Collatz_Sequences(i) = CoLngth(i, Collatz_Sequences);
    end
end

%graph
scatter(1:highset_number_to_check, Collatz_Sequences, '.')
xlabel('number')
ylabel('sequence length')
title("Collatz sequences' length")


%displaying the results
[maximum_length, Idx] = max(Collatz_Sequences);
fprintf("The number with the longest Collatz sequence is %d, and its sequnce length is %d\n", Idx, maximum_length);
%disp(Collatz_Sequences(highset_number_to_check));

function verified_input = valid_input(sus_input) %a function to reduce
%wasteage of code
     invalid_input = true;
     while invalid_input
         if ~isnumeric(sus_input)
             sus_input = input("It seems not to be a numeric value at all! Try again:\n");
         elseif ~isscalar(sus_input)
             sus_input = input("It seems not to be a scalar value. Try again:\n");
         elseif fix(sus_input) ~= sus_input
             sus_input = input("It seems not to be a positive integer. Try again:\n");
         elseif sus_input > ((2^32)-1)
              sus_input = input("It seems to be to large of a number. Try again. not smaller than 0, not larger than (2^32)-1:\n");
         elseif sus_input < 1
             sus_input = input("It seems to be to small of a number. Try again. not smaller than 0, not larger than (2^32)-1:\n");
         else
             verified_input = sus_input;
             return;
         end
     end
end

function SeqLnght = CoLngth(seed_number, Collatz_Sequences) %The function
% receive an integer and a vector of Collatz sequnces' lengths and return 
%the sequnce length
    
    SeqLnght = 0;

    %checking before the while
    if seed_number == 1
        return;
    end

    %using a vail number to not change the seed
    changing_number = seed_number;

    %legal break term (reached 1) and prog break term (to prevent overflow)
    while (changing_number > 1) && (SeqLnght < 10000)
        if rem(changing_number, 2) %odd number
            changing_number = 3 * changing_number + 1;
        else %even number           
            changing_number = changing_number * 0.5;
        end
        
        SeqLnght = SeqLnght + 1; %another step to the counter

        %a little helper to shorten the time for producing large graphs
        if changing_number < length(Collatz_Sequences) && Collatz_Sequences(changing_number) ~= 0
            SeqLnght = SeqLnght + Collatz_Sequences(changing_number);
            changing_number = 1;
        end       
    end
end


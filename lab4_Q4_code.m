%%clc;
sum = 0;
first_card = randi([1 13],1);
if first_card > 10
    sum = 10 + sum;
elseif first_card == 1
    sum = 11 + sum;
else
    sum = first_card + sum;
end
second_card = randi([1 13],1);
if second_card > 10
    sum = 10 + sum;
elseif second_card == 1
    sum = 11 + sum;
else
    sum = second_card + sum;
end
fprintf("Your cards are %d and %d, which sums up to %d.\n", first_card,...
    second_card, sum);
if sum ~= 21
    hit_me = input('Would you like another card ("0" for "no", "1" for "yes)? ');
    if ~isnumeric(hit_me) || hit_me > 1 || hit_me < 0 || ~(hit_me == fix(hit_me))
        disp("You entered an illegal answer, terminating the program.");
        return;
    end
    if hit_me == 1
        third_card = randi([1 13],1);
        if third_card > 10
          sum = 10 + sum;
        elseif third_card == 1
            sum = 11 + sum;
        else
            sum = third_card + sum;
        end
        fprintf("Your cards are %d, %d and %d, which sums up to %d. Cheers!\n",...
            first_card, second_card, third_card, sum);
        return;
    elseif hit_me == 0
        fprintf("Cheers!\n");
        return;
    end
elseif sum == 21
    fprintf("Natural Blackjack! you win.\n");
end
    
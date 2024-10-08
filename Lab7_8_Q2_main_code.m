clear; %clc;
%%initilaizing the deck of cards vector with the value of each card
deck_of_cards = zeros(1,52);
for i = 1:4
    for j = 1:13
        deck_of_cards((13*(i-1)+j)) = j;
    end
end

%recieving input from the user and checking it
total_money = input("How much money are you risking tonight, sire? ");
total_money = input_test(total_money);

%recieving values for the cards in the hands of the players
comp_hand = [0,0]; player_hand = [0,0];

while total_money > 0 && length(deck_of_cards) > 10 %the game should end if the player's money run out or the deck runs out
    for i = 1:length(comp_hand) %attribute random cards to the player and dealer, while erasing them from the deck.
        [comp_hand(i), deck_of_cards] = draw(deck_of_cards);
        [player_hand(i), deck_of_cards] = draw(deck_of_cards);
    end

    %showing the player his hand and one of the dealers cards
    fprintf("This is your current hand: %d and %d.\n", player_hand(1), player_hand(2));
    fprintf("And this is one of the cards in the dealer's current hand: %d.\n", comp_hand(1));

    %bet function asks for the current bet size
    current_bet = bet(total_money);

    %oneround function is the main action function - it asks the player if
    %they want another card and check winnings and losings
    [gains, deck_of_cards] = oneround(current_bet, comp_hand, player_hand, deck_of_cards);

    %announcing the winning or losing of the specific amount
    if gains > 0
        fprintf("You won! %d dollars to be precise. \n", gains);
    elseif gains == 0
        fprintf("A tie, so not money movment. Thanks for playing.\n");
    else
        fprintf("It seems you lost, sire. %d dollars.\n", (-1)*gains);
    end

    %divulging the hand of the dealer
    fprintf("The dealer hand was %d and %d.\n", comp_hand(1), comp_hand(2));

    total_money = total_money + gains;
    fprintf("Your current sum of money is %d.\n\n", total_money);
    if total_money == 0
        fprintf("It seems you run out of money, sir. Have a good day!\n")
    end
end
if length(deck_of_cards) < 10 %message for an involuntry end to the game
    fprintf("I made myself a rule, never to play more than a deck, so we would call that a night, sire. You have %d dollars, see you again!\n", total_money);
end

function [card, deck_of_cards] = draw(deck_of_cards) %the function recieve
    % a deck of cards, and return a random card and the deck after removing
    %this card from it

    %getting a random number withing the limits of the deck size
    index = randi(length(deck_of_cards));

    %returning the card of the index we got
    card = deck_of_cards(index);

    %erasing the card we took out from the deck
    deck_of_cards(index) = [];
end

function hand_value = hand(hand_vec) %the function recieve a "hand" and 
%calculate its value (according to the rules) and returns it
    hand_value = 0; %initilizing the sum
    for i = 1:length(hand_vec)
        switch hand_vec(i)
            case 1 %ace worth 11
                hand_value = hand_value + 11;
            case {11,12,13} %royalty worth 10
                hand_value = hand_value + 10;
            otherwise %the others worth their number
                hand_value = hand_value + hand_vec(i);
        end
    end
end

function current_bet = bet(total_money) %the function bet request a bet size 
% smaller than the current amount of money the player have.s

%recieving the bet size
    current_bet = input("How much do you wish to bet this round, sir? ");
    %checking if the input is valid
    current_bet = input_test(current_bet);
    %checking if the funds are suffiecient
    while current_bet > total_money ||  current_bet <= 0
        error_message = "The bet must be smaller than your current sum of money, " + total_money + " dollars, and still positive.";
        current_bet = input(error_message + '\n');
    end
end

function [gains, deck_of_cards] = oneround(current_bet, comp_hand, player_hand, deck_of_cards)
%the funtion oneround will "play" a hand with the player and will return
%the deck of cards after reducing the played ones, and the bet results.
    player_value = hand(player_hand); %assesing the player's current hand value

    while player_value < 21% || sum(player_hand) == 2 %2 cards won't be above 21 in a real black-jack game but because aces were defined weirdly, i added an exeption.
        another_round = input('Would you like another card (1 for "Yes" and 0 for "No")? \n'); 
        while ~(another_round == 1 || another_round == 0) %given the input should be binary, I prefered positive input tests
            another_round = input('Saying again, 1 for "Yes" and 0 for "No", no other input is relevant.\n');
        end
        if another_round
            [card, deck_of_cards] = draw(deck_of_cards);
            player_hand = [player_hand, card]; %given the longest game will be 7 rounds, the growing vector won't be an issue
            
            %displaying the hand of the player
            strVec = num2str(player_hand);
            otptStr = join(split(strVec), ', ');
            fprintf("Your current hand is ");
            disp(otptStr);
            fprintf("\n");
            player_value = hand(player_hand);
        elseif ~another_round
                break;
        end
    end
    comp_value = hand(comp_hand); player_value = hand(player_hand); %assesing the actual hands values
    if comp_value == player_value %a tie
        gains = 0; %no mpney change hands
    elseif comp_value > player_value || player_value > 21 %losing the game
        gains = (-1)*current_bet; %losing the bet sum
    else
        gains = current_bet; %winning the bet sum
    end
end

function valid_input = input_test(suspicious_input)
    while ~isnumeric(suspicious_input) || suspicious_input <= 0 || ...
            ~isscalar(suspicious_input) || isnan(suspicious_input) ||...
            isinf(suspicious_input)
        suspicious_input = input("It seems your input wasn't quite making sense, can you please try again? ");
    end
    valid_input = suspicious_input;
end
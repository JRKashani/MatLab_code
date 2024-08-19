clc; clear;

in_str = input("Enter a sentence you'd like to capitolize: ", 's');

out_str = lower(in_str);
out_str(1) = upper(in_str(1));

for i = 2:length(in_str)-1
    if all((isletter(in_str(i-1:i+1))) == [0,1,1])
        out_str(i) = upper(in_str(i));
    end
end

fprintf("Your sentence is: \n");
disp(in_str);
fprintf("Your sentence after capitolization is: \n");
disp(out_str);
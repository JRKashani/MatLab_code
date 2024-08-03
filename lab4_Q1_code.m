clc;
distance_above_four = false;
v = input("Please enter the velocity in which the canon-ball leaves the canon:");
theta = input("Please enter the angle above the horizon in radians: ");
x = (2*sin(theta)*v/9.8)*v*cos(theta);
if x > 4
    distance_above_four = true;
end
disp(distance_above_four);
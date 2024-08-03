clc;
a = input("Please enter the base of the triangle: ");
b = input("Please enter the perpendicular side of the triangle: ");
fprintf("The area of the triangle is %.2f\n", a*b/2);
fprintf("The circumference of the triangle is %.2f\n",a+b+sqrt(a^2 + b^2));
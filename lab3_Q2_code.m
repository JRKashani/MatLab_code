clc;
cmplx = input("Enter your complex number ");
fprintf("\nThe number is %.4f + %.4fi", real(cmplx), imag(cmplx));
fprintf("\nThe real part of your number is %.1f", real(cmplx));
fprintf("\nThe imag part is %.1f", imag(cmplx));
fprintf("\nThe radius is %.1f", abs(cmplx));
fprintf("\nThe angle is %.2f rads or %.2f degrees", angle(cmplx), ...
    (angle(cmplx)*180)/pi);
fprintf("\nThe conjugate number is ");
disp(conj(cmplx));
clc; 
a = input("Enter the base:"); 
b = input("Enter the value:"); 
c = int64(log(b)/log(a)); 
fprintf("Log%d(%d)=%d\n",a,b,c); 
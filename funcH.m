%% funcH.m recieve 3 triangles edges and return the area and crcumfernce of the triangle
function [area, crfm] = funcH(a, b, c)

%%initilizing the output parameters
area = zeros(1, length(a)); crfm = zeros(1, length(a));

%% input checks
if ~isnumeric(a) || ~isnumeric(b) || ~isnumeric(c)
    error("At least one of the parmeters aren't numeric.");
elseif ~(length(a) == length(b) && length(a) == length(c))
    error("The input parameters aren't the same size.");
elseif ~(isscalar(a) || length(a) == 3)
    error("The only valid input vectors are of length 1 or 3")
elseif any(a <= 0 | b <= 0 | c <= 0 | isnan(a) |isnan(b) | isnan(c) |isinf(a) | isinf(b) | isinf(c))
    error("At least one of the input parameters is 0, NaN, inf or negative.")
end

%putting the input vectors in  martix to unify their prossecing
trianglesMAT = transpose([reshape(a,1, []); reshape(b, 1, []); reshape(c, 1, [])]);

%calculating the area with Heron's formula and circumfernce
if isscalar(a)
    crfm = a + b +c;
    p = crfm/2;
    area = sqrt(p*(p-a)*(p-b)*(p-c));
else
    for i = 1:length(a)
        crfm(i) = sum(trianglesMAT(:,i));
        area(i) = sqrt((crfm(i)/2)*((crfm(i)/2)...
            -trianglesMAT(1,i))*((crfm(i)/2)-trianglesMAT(2,i))...
            *((crfm(i)/2)-trianglesMAT(3,i)));
    end
end

%last check - if the input edges cannot be a triangle, an error will be
%thrown

if ~isreal(area) || any(area == 0)
    area = 0; crfm = 0;
    error("These edges can not form a triangle!")
else
    return
end
function U_num = class_to_num(U)
% CLASS_TO_NUM  Convert packet class letter to number
%   'A' -> 1,  'B' -> 2,  'C' -> 3

switch U
    case 'A'
        U_num = 1;
    case 'B'
        U_num = 2;
    case 'C'
        U_num = 3;
    otherwise
        warning('class_to_num: unknown class "%s", defaulting to 3', U);
        U_num = 3;
end

end
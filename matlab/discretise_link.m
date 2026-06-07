function Ls_level = discretise_link(L_s)
% DISCRETISE_LINK  Map continuous L_s (0-1) to 2 discrete levels
%   L_s < 0.7  -> 1 (unstable)
%   L_s >= 0.7 -> 2 (stable)

if L_s < 0.7
    Ls_level = 1;
else
    Ls_level = 2;
end

end
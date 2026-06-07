function idx = state_index(U_num, Er_level, Ls_level)
% STATE_INDEX  Map (U, E_r_level, L_s_level) to linear index 1..18
%
%   Encoding scheme:
%     U_num:    1=A, 2=B, 3=C
%     Er_level: 1=low, 2=mid, 3=high
%     Ls_level: 1=unstable, 2=stable
%
%   Formula: (U-1)*6 + (Er-1)*2 + Ls
%
%   Examples:
%     (A, low, unstable)  = (1-1)*6 + (1-1)*2 + 1 = 1
%     (A, low, stable)    = (1-1)*6 + (1-1)*2 + 2 = 2
%     (A, high, stable)   = (1-1)*6 + (3-1)*2 + 2 = 6
%     (B, low, unstable)  = (2-1)*6 + (1-1)*2 + 1 = 7
%     (C, high, stable)   = (3-1)*6 + (3-1)*2 + 2 = 18

idx = (U_num - 1) * 6 + (Er_level - 1) * 2 + Ls_level;

end
function Er_level = discretise_energy(E_r)
% DISCRETISE_ENERGY  Map continuous E_r (0-1) to 3 discrete levels
%   E_r < 0.3        -> 1 (low / critical)
%   0.3 <= E_r < 0.7 -> 2 (mid / moderate)
%   E_r >= 0.7       -> 3 (high / healthy)

if E_r < 0.3
    Er_level = 1;
elseif E_r < 0.7
    Er_level = 2;
else
    Er_level = 3;
end

end
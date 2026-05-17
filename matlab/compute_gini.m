function G = compute_gini(energy_consumed)
% COMPUTE_GINI  Gini coefficient for energy consumption inequality
%   G = 0 means perfectly equal consumption (ideal)
%   G = 1 means one node consumed everything (worst case)
x = sort(energy_consumed(:));
n = length(x);
if n == 0 || sum(x) == 0
    G = 0;
    return;
end
idx = (1:n)';
G = (2 * sum(idx .* x)) / (n * sum(x)) - (n+1)/n;
G = max(0, min(1, G));   % clamp to [0,1]
end
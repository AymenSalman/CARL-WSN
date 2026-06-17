function p = link_prr(d, params)
% Packet reception ratio vs distance (transitional-region model,
% Zuniga & Krishnamachari). Reliable at short range, falls through
% the transitional zone, ~0 beyond comm range.
    p = 1 ./ (1 + exp(params.ch_alpha .* (d - params.ch_beta)));
end
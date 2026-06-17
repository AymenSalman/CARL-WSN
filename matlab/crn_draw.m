function u = crn_draw(seed, r, i, j, attempt)
% Deterministic per-link uniform draw -> identical channel realization
% across all protocols for the same (seed, round, link, attempt).
% Gives common-random-numbers (paired comparison) on the channel.
    v = sin(seed*1e4 + r*131.1 + i*17.3 + j*101.7 + attempt*53.7) * 43758.5453;
    u = v - floor(v);
end
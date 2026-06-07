function R = compute_reward(packet_class, latency, ctrl_pkts, n_nb, E_r_before, E_r_after)
% COMPUTE_REWARD  Calculate reward for Q-Learning update
%
%   The reward is a weighted combination of three objectives:
%     1. Latency performance (did we meet the deadline?)
%     2. Routing overhead (did we use few control packets?)
%     3. Energy preservation (did we save energy?)
%
%   Weights depend on packet class:
%     Class A: latency matters most  (w1=0.7, w2=0.15, w3=0.15)
%     Class B: energy matters most   (w1=0.2, w2=0.3,  w3=0.5)
%     Class C: energy matters most   (w1=0.1, w2=0.3,  w3=0.6)
%
%   Inputs:
%     packet_class - 'A', 'B', or 'C'
%     latency      - observed end-to-end latency (ms)
%     ctrl_pkts    - control packets generated for this transmission
%     n_nb         - number of neighbours within range
%     E_r_before   - residual energy ratio before transmission
%     E_r_after    - residual energy ratio after transmission
%
%   Output:
%     R            - scalar reward value

%% ── Latency reward ────────────────────────────────────────────────────
switch packet_class
    case 'A'
        lat_max = 100;  % ms — hard deadline
        if latency > 100
            R_lat = -1;  % severe penalty for missing emergency deadline
        else
            R_lat = 1 - (latency / lat_max);
        end
        
    case 'B'
        lat_max = 30000;  % 30 seconds tolerance
        R_lat = 1 - (latency / lat_max);
        
    case 'C'
        R_lat = 1;  % best-effort, no latency penalty
        
    otherwise
        R_lat = 0;
end

%% ── Overhead reward ───────────────────────────────────────────────────
% Normalise against DSDV worst case: n_nb * 0.20 per packet
max_ctrl = max(n_nb * 0.20, 1);
R_oh = 1 - min(ctrl_pkts / max_ctrl, 1);

%% ── Energy reward ─────────────────────────────────────────────────────
% How much energy was preserved during this transmission
if E_r_before > 0.001
    R_en = min(E_r_after / E_r_before, 1.0);
else
    R_en = 0;
end

% Clamp to [0, 1]
R_en = min(max(R_en, 0), 1);

%% ── Weighted combination (class-dependent) ────────────────────────────
switch packet_class
    case 'A'
        w1 = 0.7;  w2 = 0.15; w3 = 0.15;  % latency dominates
    case 'B'
        w1 = 0.2;  w2 = 0.3;  w3 = 0.5;   % energy dominates
    case 'C'
        w1 = 0.1;  w2 = 0.3;  w3 = 0.6;   % energy dominates
    otherwise
        w1 = 0.33; w2 = 0.33; w3 = 0.34;
end

R = w1 * R_lat + w2 * R_oh + w3 * R_en;

% Final NaN safety check
if isnan(R) || isinf(R)
    R = 0;
end

end
function R = compute_reward(packet_class, latency, ctrl_pkts, energy_consumed, params)
% COMPUTE_REWARD  Class-dependent multi-objective reward for the Q-Learning update.
%   R = w1*R_lat + w2*R_oh + w3*R_en  (weights depend on packet class)

    % ── Latency reward ──
    switch packet_class
        case 'A'
            if latency > 100, R_lat = -1; else, R_lat = 1 - latency/100; end
        case 'B', R_lat = 1 - latency/30000;
        case 'C', R_lat = 1;
        otherwise, R_lat = 0;
    end

    % ── Overhead reward (normalised to a full network flood) ──
    R_oh = 1 - min(ctrl_pkts / params.N, 1);

    % ── Energy reward (reformulated: rewards cheaper per-packet cost) ──
    E_ref = params.max_hops * ...
            (params.L*params.E_elec + params.L*params.epsilon_mp*params.comm_range^4);
    R_en = 1 - min(energy_consumed / E_ref, 1);

    % ── Class-dependent weights ──
    switch packet_class
        case 'A', w1=0.7; w2=0.15; w3=0.15;
        case 'B', w1=0.2; w2=0.3;  w3=0.5;
        case 'C', w1=0.1; w2=0.3;  w3=0.6;
        otherwise, w1=0.33; w2=0.33; w3=0.34;
    end

    R = w1*R_lat + w2*R_oh + w3*R_en;
    if isnan(R) || isinf(R), R = 0; end
end
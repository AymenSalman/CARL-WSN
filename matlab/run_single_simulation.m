function metrics = run_single_simulation(params, protocol_name, scenario)
% RUN_SINGLE_SIMULATION  Runs one complete simulation
%   Returns all 8 metrics for one protocol/scenario/seed combination

%% ── Initialise ────────────────────────────────────────────────────────────
net       = init_network(params);
R         = params.rounds;
N         = params.N;
ctrl_pkts = 0;   % routing control packet counter
data_pkts = 0;   % data packet counter

% ── RL initialisation (only used for CARHy_RL) ────────────────────────
if strcmp(protocol_name, 'CARHy_RL')
    Q = init_qtable();           % 18x3 zeros
    alpha_lr = 0.1;              % learning rate
    gamma_df = 0.9;              % discount factor
    epsilon = 0.1;               % exploration rate
    epsilon_decay = 0.998;       % decay per round
    epsilon_min = 0.01;          % minimum exploration
    Q_history = zeros(R, 1);     % track convergence: max delta per round
    max_delta_this_round = 0;    % temp variable for convergence tracking
end

%% ── Per-round simulation loop ─────────────────────────────────────────────
for r = 1:R
    net.round = r;

    % Skip round if less than 10% nodes alive
    if sum(net.alive) < floor(N * 0.10)
        break;
    end

    alive_idx = find(net.alive);

    % Each alive node generates and sends one packet per round
    for i = 1:length(alive_idx)
        node_id = alive_idx(i);

        % Generate packet class based on scenario
        pkt_class = generate_packet(scenario, params);
        data_pkts = data_pkts + 1;

        % Route packet using the specified protocol
        switch protocol_name
            case 'CARHy'
                [net, ~] = run_carhy(node_id, pkt_class, net, params);
                ctrl_pkts = ctrl_pkts + estimate_ctrl_overhead('CARHy', pkt_class, net, node_id, params);

            case 'AODV'
                [net, ~] = routing_reactive(node_id, pkt_class, net, params);
                ctrl_pkts = ctrl_pkts + estimate_ctrl_overhead('AODV', pkt_class, net, node_id, params);

            case 'DSDV'
                [net, ~] = routing_proactive(node_id, pkt_class, net, params);
                ctrl_pkts = ctrl_pkts + estimate_ctrl_overhead('DSDV', pkt_class, net, node_id, params);

            case 'ZRP'
                [net, ~] = routing_hybrid(node_id, pkt_class, net, params);
                ctrl_pkts = ctrl_pkts + estimate_ctrl_overhead('ZRP', pkt_class, net, node_id, params);

            case 'EH_Routing'
                % Energy-harvesting aware routing (your IJEECS 2021 baseline)
                [net, ~] = routing_eh(node_id, pkt_class, net, params);
                ctrl_pkts = ctrl_pkts + estimate_ctrl_overhead('EH_Routing', pkt_class, net, node_id, params);

            case 'MSLBA'
                % Multi-sink load balancing (your IJSER 2023 baseline)
                [net, ~] = routing_mslba(node_id, pkt_class, net, params);
                ctrl_pkts = ctrl_pkts + estimate_ctrl_overhead('MSLBA', pkt_class, net, node_id, params);
       
       case 'CARHy_RL'
                % CARL-WSN: RL-based context-aware routing
                E_r_before = net.energy(node_id) / net.E0(node_id);
                
                % Step A: RL agent selects routing mode
                [mode_selected, action_idx, s] = context_classifier_rl(...
                    node_id, pkt_class, net, params, Q, epsilon);
                
                % Step B: Route using the selected mode
                switch mode_selected
                    case 'proactive'
                        [net, lat] = routing_proactive(node_id, pkt_class, net, params);
                    case 'reactive'
                        [net, lat] = routing_reactive(node_id, pkt_class, net, params);
                    case 'hybrid'
                        [net, lat] = routing_hybrid(node_id, pkt_class, net, params);
                end
                
                % Step C: Count overhead
                ctrl = estimate_ctrl_overhead('CARHy', pkt_class, net, node_id, params);
                ctrl_pkts = ctrl_pkts + ctrl;
                
                % Step D: Compute reward
                E_r_after = net.energy(node_id) / net.E0(node_id);
                n_nb = 0;
for nb = 1:length(net.alive)
    if net.alive(nb) && nb ~= node_id
        d = sqrt((net.x(nb)-net.x(node_id))^2 + (net.y(nb)-net.y(node_id))^2);
        if d <= 100
            n_nb = n_nb + 1;
        end
    end
end
                R_reward = compute_reward(pkt_class, lat, ctrl, n_nb, ...
                           E_r_before, E_r_after);
                
                % Step E: Compute next state
                E_r_new = net.energy(node_id) / net.E0(node_id);
                alpha_ewma = 0.3;
                ack_col = net.ack_history(:, node_id);
                w_ewma = alpha_ewma * (1 - alpha_ewma).^(0:9)';
                w_ewma = w_ewma / sum(w_ewma);
                L_s_new = dot(w_ewma, ack_col);
                s_next = state_index(class_to_num(pkt_class), ...
                         discretise_energy(E_r_new), ...
                         discretise_link(L_s_new));
                
               % Step F: Q-Learning update (with NaN guard)
                if ~isnan(R_reward) && ~isnan(max(Q(s_next, :)))
                    old_Q = Q(s, action_idx);
                    Q(s, action_idx) = old_Q + alpha_lr * ...
                        (R_reward + gamma_df * max(Q(s_next, :)) - old_Q);
                    
                    % Track convergence
                    delta = abs(Q(s, action_idx) - old_Q);
                    if delta > max_delta_this_round
                        max_delta_this_round = delta;
                    end
                end
        end
    end

    % Record per-round metrics
    net.metrics.alive_per_round(r)  = sum(net.alive);
    net.metrics.energy_per_round(r) = sum(net.energy(net.alive));
    % RL: decay epsilon and record convergence
    if strcmp(protocol_name, 'CARHy_RL')
        epsilon = max(epsilon * epsilon_decay, epsilon_min);
        Q_history(r) = max_delta_this_round;
        max_delta_this_round = 0;
    end

end

%% ── Compute final metrics ─────────────────────────────────────────────────

% FND: first node death round
metrics.FND = net.FND;
if metrics.FND == 0
    metrics.FND = R;   % no node died = full lifetime
end

% HND: half node death round
metrics.HND = net.HND;
if metrics.HND == 0
    metrics.HND = R;
end

% PDR: packet delivery ratio
if net.metrics.total_sent > 0
    metrics.PDR = net.metrics.delivered / net.metrics.total_sent;
else
    metrics.PDR = 0;
end

% Class A latency (mean)
if ~isempty(net.metrics.latency_A)
    metrics.LatA = mean(net.metrics.latency_A);
else
    metrics.LatA = 0;
end

% Average energy consumed per round (across alive rounds)
alive_rounds = find(net.metrics.energy_per_round > 0);
if ~isempty(alive_rounds)
    % Energy consumed = initial total - remaining total
    E_initial = sum(net.E0);
    E_remaining = sum(net.energy);
    metrics.AvgEnergy = (E_initial - E_remaining) / length(alive_rounds);
else
    metrics.AvgEnergy = 0;
end

% Gini coefficient (energy balance — lower is better)
metrics.Gini = compute_gini(net.E0 - net.energy);

% Alive nodes per round (for lifetime figure)
metrics.alive_per_round = net.metrics.alive_per_round;

% Routing overhead (control packets per data packet)
if data_pkts > 0
    metrics.Overhead = ctrl_pkts / data_pkts;
else
    metrics.Overhead = 0;
end

% Throughput (delivered packets per round)
metrics.Throughput = net.metrics.delivered / R;

% Throughput (delivered packets per round)
metrics.Throughput = net.metrics.delivered / R;

% Alive nodes per round (for lifetime figure)
metrics.alive_per_round = net.metrics.alive_per_round;

% RL-specific outputs
if strcmp(protocol_name, 'CARHy_RL')
    metrics.Q_table = Q;              % final learned Q-table
    metrics.Q_history = Q_history;    % convergence trace
    metrics.final_epsilon = epsilon;  % final exploration rate
end

end
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
end_round = R; cap_hit = true;
for r = 1:R
    net.round = r;

    % Skip round if less than 10% nodes alive
   if sum(net.alive) < floor(N * 0.10)
        end_round = max(r-1,1); cap_hit = false; break;
    end

   alive_idx = find(net.alive);

   % ── Per-round routing overhead + route-cache aging ──
    net.route_age = max(net.route_age - 1, 0);
    n_alive = sum(net.alive);
    switch protocol_name
        case 'DSDV'
            % Full-dump: each node broadcasts its entire table (n_alive
            % entries), fragmented across packets.
            frags = ceil(n_alive * params.dsdv_entry_bits / params.L);
            ctrl_pkts = ctrl_pkts + n_alive * frags / params.T_update;
        case {'EH_Routing','MSLBA'}
            % Single small state value (energy / nearest-sink id): one packet.
            ctrl_pkts = ctrl_pkts + n_alive / params.T_update;
        case 'ZRP'
            for ii = alive_idx(:)'
                E_r = net.energy(ii)/net.E0(ii);
                if E_r>=0.7, zr=120; elseif E_r>=0.3, zr=80; else, zr=40; end
                if hypot(net.x(ii)-net.BS(1),net.y(ii)-net.BS(2)) <= zr
                    ctrl_pkts = ctrl_pkts + 1/params.T_update;
                end
            end
    end

    % Each alive node generates and sends one packet per round
    for i = 1:length(alive_idx)
        node_id = alive_idx(i);

        % Generate packet class based on scenario
        pkt_class = generate_packet(scenario, params);
        data_pkts = data_pkts + 1;

        % Route packet using the specified protocol
        switch protocol_name
           case {'AODV','DSDV','ZRP','EH_Routing','MSLBA'}
                [net, c_od] = route_baseline(node_id, pkt_class, net, params, protocol_name);
                ctrl_pkts = ctrl_pkts + c_od;

            case 'CARHy_RL'
                % CARL-WSN: RL paradigm selection on the shared realistic engine
                [mode_selected, action_idx, s] = ...
                    context_classifier_rl(node_id, pkt_class, net, params, Q, epsilon);

                % --- critical-node deferral: counts as generated, not delivered ---
                if strcmp(mode_selected, 'defer')
                    net.defer_count(node_id) = net.defer_count(node_id) + 1;
                    net.energy(node_id) = max(net.energy(node_id) ...
                        - params.L*params.E_elec*0.1, 0);     % listening cost only
                    net = check_node_death(net, node_id, params);
                    net.metrics.total_sent = net.metrics.total_sent + 1;
                    continue;                                  % no action -> no Q-update
                end

                % --- data-plane delivery (energy-aware geographic relay) ---
                net.defer_count(node_id) = 0;   % reset on actual transmission
                [net, delivered, lat_data, n_hops, ~, e_used] = ...
                    forward_to_dest(node_id, net, params, net.BS, 'carl');

                % --- paradigm-dependent latency + Option-C overhead ---
                lat = lat_data; ctrl = 0;
                switch mode_selected
                    case 'proactive'                           % maintained table, no discovery
                        ctrl = 1;
                    case 'reactive'                            % on-demand discovery (energy piggybacked), cached
                        if net.route_age(node_id) <= 0
                            ctrl = 1; net.route_age(node_id) = params.T_route;
                            lat = lat + n_hops*(params.L/params.datarate*1000);
                        end
                    case 'hybrid'                              % zone-scoped discovery, cached
                        if net.route_age(node_id) <= 0
                            ctrl = 1; net.route_age(node_id) = params.T_route;
                        end
                end
                ctrl_pkts = ctrl_pkts + ctrl;

                % --- metrics ---
                net.metrics.total_sent = net.metrics.total_sent + 1;
                if delivered
                    net.metrics.delivered = net.metrics.delivered + 1;
                    if strcmp(pkt_class,'A'), net.metrics.latency_A(end+1) = lat; end
                end

                % --- reward + Q-update (Class A is safety-forced: never learned) ---
                if ~strcmp(pkt_class,'A')
                    R_reward = compute_reward(pkt_class, lat, ctrl, e_used, params);
                    E_r_new  = net.energy(node_id)/net.E0(node_id);
                    s_next   = state_index(class_to_num(pkt_class), ...
                               discretise_energy(E_r_new), discretise_link(net.L_s(node_id)));
                    if ~isnan(R_reward) && ~isnan(max(Q(s_next,:)))
                        old_Q = Q(s, action_idx);
                        Q(s, action_idx) = old_Q + alpha_lr * ...
                            (R_reward + gamma_df*max(Q(s_next,:)) - old_Q);
                        delta = abs(Q(s, action_idx) - old_Q);
                        if delta > max_delta_this_round, max_delta_this_round = delta; end
                    end
                end

            case 'RLCR'
                [net, ~] = routing_rlcr(node_id, pkt_class, net, params);
                

            case 'FQ_UCR'
                [net, ~] = routing_fqucr(node_id, pkt_class, net, params);
               

        end  % end switch protocol_name
    end  % end for each alive node

    % Record per-round metrics
    net.metrics.alive_per_round(r)  = sum(net.alive);
    net.metrics.energy_per_round(r) = sum(net.energy(net.alive));

    % RL: decay epsilon and record convergence
    if strcmp(protocol_name, 'CARHy_RL')
        epsilon = max(epsilon * epsilon_decay, epsilon_min);
        Q_history(r) = max_delta_this_round;
        max_delta_this_round = 0;
    end

end  % end for each round

%% ── Compute final metrics ─────────────────────────────────────────────────

% FND: first node death round
metrics.FND = net.FND;
if metrics.FND == 0
    metrics.FND = R;
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
    E_initial = sum(net.E0);
    E_remaining = sum(net.energy);
    metrics.AvgEnergy = (E_initial - E_remaining) / length(alive_rounds);
else
    metrics.AvgEnergy = 0;
end

% Gini coefficient (energy balance — lower is better)
metrics.Gini = compute_gini(net.E0 - net.energy);

% Routing overhead (dual mode for clustering)
if data_pkts > 0
    if any(strcmp(protocol_name, {'RLCR','FQ_UCR'}))
        metrics.Overhead      = net.cluster_ctrl / data_pkts;                            % re-cluster only
        metrics.Overhead_tdma = (net.cluster_ctrl + net.cluster_ctrl_tdma) / data_pkts;  % + TDMA
    else
        metrics.Overhead      = ctrl_pkts / data_pkts;
        metrics.Overhead_tdma = metrics.Overhead;
    end
else
    metrics.Overhead = 0; metrics.Overhead_tdma = 0;
end
% Horizon components (main.m computes Throughput/AvgEnergy over a common horizon)
metrics.LND            = net.LND;  if metrics.LND==0, metrics.LND = R; end
metrics.TotalDelivered = net.metrics.delivered;
metrics.TotalEnergy    = sum(net.E0) - sum(net.energy);
metrics.EndRound       = end_round;
metrics.CapHit         = cap_hit;

% Throughput (delivered packets per round)
metrics.Throughput = net.metrics.delivered / R;

% Alive nodes per round (for lifetime figure)
metrics.alive_per_round = net.metrics.alive_per_round;

% RL-specific outputs
if strcmp(protocol_name, 'CARHy_RL')
    metrics.Q_table = Q;
    metrics.Q_history = Q_history;
    metrics.final_epsilon = epsilon;
end

end
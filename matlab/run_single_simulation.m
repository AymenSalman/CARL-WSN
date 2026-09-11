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
    Q = init_qtable();               % 18x3 zeros
    alpha_lr = params.alpha_lr;      % learning rate (grid-searchable)
    gamma_df = params.gamma_df;      % discount factor (grid-searchable)
    epsilon = params.epsilon0;       % initial exploration rate
    epsilon_decay = params.epsilon_decay;  % decay per round (grid-searchable)
    epsilon_min = params.epsilon_min;      % minimum exploration
    Q_history = zeros(R, 1);         % track convergence: max delta per round
    max_delta_this_round = 0;        % temp variable for convergence tracking
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
            if mod(r, params.T_full_dump) == 0
                frags = ceil(n_alive * params.dsdv_entry_bits / params.L);
                [e_tx, e_rx] = energy_model(params, params.L, params.comm_range);
                for ii = alive_idx(:)'
                    nb = find_neighbours(ii, net, params.comm_range);
                    ctrl_pkts = ctrl_pkts + frags;
                    net.energy(ii) = max(net.energy(ii) - frags*e_tx, 0);
                    net.energy(nb) = max(net.energy(nb) - frags*e_rx, 0);
                    net = check_node_death(net, ii, params);
                    for jj = nb, net = check_node_death(net, jj, params); end
                end
            else
                [e_tx, e_rx] = energy_model(params, params.dsdv_entry_bits, params.comm_range);
                for ii = alive_idx(:)'
                    nb = find_neighbours(ii, net, params.comm_range);
                    ctrl_pkts = ctrl_pkts + 1;
                    net.energy(ii) = max(net.energy(ii) - e_tx, 0);
                    net.energy(nb) = max(net.energy(nb) - e_rx, 0);
                    net = check_node_death(net, ii, params);
                    for jj = nb, net = check_node_death(net, jj, params); end
                end
            end

        case {'EH_Routing','MSLBA'}
            if mod(r, params.T_update) == 0
                [e_tx, e_rx] = energy_model(params, params.L_ctrl, params.comm_range);
                for ii = alive_idx(:)'
                    nb = find_neighbours(ii, net, params.comm_range);
                    ctrl_pkts = ctrl_pkts + 1;
                    net.energy(ii) = max(net.energy(ii) - e_tx, 0);
                    net.energy(nb) = max(net.energy(nb) - e_rx, 0);
                    net = check_node_death(net, ii, params);
                    for jj = nb, net = check_node_death(net, jj, params); end
                end
            end

        case 'ZRP'
            for ii = alive_idx(:)'
                E_r = net.energy(ii)/net.E0(ii);
                if E_r>=0.7, zr=120; elseif E_r>=0.3, zr=80; else, zr=40; end
                if hypot(net.x(ii)-net.BS(1),net.y(ii)-net.BS(2)) <= zr
                    ctrl_pkts = ctrl_pkts + 1/params.T_update;
                end
            end
        case 'RPL'
            [e_tx_dio, e_rx_dio] = energy_model(params, params.L_ctrl, params.comm_range);
            [e_tx_dao, e_rx_dao] = energy_model(params, params.L_ctrl, params.comm_range);
            transmitters = false(1, params.N);

            for ii = alive_idx(:)'
                inconsistency = false;
                                if net.rpl_parent(ii) > 0 && ~net.alive(net.rpl_parent(ii))   % unchanged: -1/0 both skip this check correctly
                    inconsistency = true;
                    net.rpl_rank(ii) = inf;
                end

                d_bs = hypot(net.x(ii)-net.BS(1), net.y(ii)-net.BS(2));
                best_rank = inf; best_parent = -1;
                if d_bs <= params.comm_range
                    cand = 1/link_prr(d_bs, params);
                    if cand < best_rank, best_rank = cand; best_parent = 0; end
                end
                nb = find_neighbours(ii, net, params.comm_range);
                for jj = nb
                    if isfinite(net.rpl_rank(jj)) && (isinf(net.rpl_rank(ii)) || net.rpl_rank(jj) < net.rpl_rank(ii))
                        d = hypot(net.x(ii)-net.x(jj), net.y(ii)-net.y(jj));
                        cand = net.rpl_rank(jj) + 1/link_prr(d, params);
                        if cand < best_rank, best_rank = cand; best_parent = jj; end
                    end
                end

                if best_parent >= 0
                    switch_parent = inconsistency || isinf(net.rpl_rank(ii)) || ...
                                     (best_rank <= net.rpl_rank(ii) - params.rpl_hysteresis);
                    if switch_parent
                        parent_changed = (net.rpl_parent(ii) ~= best_parent) || isinf(net.rpl_rank(ii));
                        net.rpl_rank(ii)   = best_rank;
                        net.rpl_parent(ii) = best_parent;
                        if parent_changed
                            % DAO (Non-Storing mode — Contiki-NG's documented
                            % default: "the DAO is sent directly to the root")
                            % + DAO-ACK (on by default: Contiki-NG
                            % RPL_WITH_DAO_ACK=1, Zephyr CONFIG_NET_RPL_DAO_ACK=y).
                            % Both are unicast, so real ARQ applies (IEEE 802.15.4).
                            chain = ii; node_walk = ii; reaches_root = false;
                            while true
                                p = net.rpl_parent(node_walk);
                                if p == 0
                                    reaches_root = true; break;
                                elseif p <= -1 || p == node_walk || length(chain) > params.max_hops
                                    break;
                                else
                                    chain = [chain, p]; node_walk = p; %#ok<AGROW>
                                end
                            end

                            if reaches_root
                                dao_ok = true;
                                for h = 1:length(chain)
                                    ctrl_pkts = ctrl_pkts + 1;
                                    if h < length(chain)
                                        [net, ok] = rpl_ctrl_hop(net, params, chain(h), chain(h+1));
                                    else
                                        [net, ok] = rpl_ctrl_hop(net, params, chain(h), 0);
                                    end
                                    if ~ok, dao_ok = false; break; end
                                end
                                if dao_ok
                                    % DAO-ACK travels back the same path. The
                                    % BS-adjacent leg's cost is charged
                                    % symmetrically to chain(end) (BS itself
                                    % has unconstrained energy regardless of
                                    % direction).
                                    ctrl_pkts = ctrl_pkts + 1;
                                    [net, ok] = rpl_ctrl_hop(net, params, chain(end), 0);
                                    for h = length(chain):-1:2
                                        if ~ok, break; end
                                        ctrl_pkts = ctrl_pkts + 1;
                                        [net, ok] = rpl_ctrl_hop(net, params, chain(h), chain(h-1));
                                    end
                                end
                            end
                            % If the chain doesn't reach the root, or the
                            % DAO/DAO-ACK fails partway (lossy channel), no
                            % automatic re-send occurs this round — the next
                            % parent change or inconsistency event will
                            % naturally re-trigger DAO origination.
                        end 
                    end
                end

                if inconsistency
                    net.rpl_I(ii) = params.rpl_I_min;
                    net.rpl_interval_start(ii) = r;
                    net.rpl_c(ii) = 0; net.rpl_heard(ii) = 0;
                    net.rpl_listen_t(ii) = r + randi([ceil(net.rpl_I(ii)/2), net.rpl_I(ii)]);
                elseif r >= net.rpl_interval_start(ii) + net.rpl_I(ii)
                    net.rpl_I(ii) = min(net.rpl_I(ii)*2, params.rpl_I_max);
                    net.rpl_interval_start(ii) = r;
                    net.rpl_c(ii) = 0; net.rpl_heard(ii) = 0;
                    net.rpl_listen_t(ii) = r + randi([ceil(net.rpl_I(ii)/2), net.rpl_I(ii)]);
                end

                if r == net.rpl_listen_t(ii) && net.rpl_heard(ii) < params.rpl_k
                    transmitters(ii) = true;
                end
            end

            for ii = find(transmitters)
                ctrl_pkts = ctrl_pkts + 1;
                nb = find_neighbours(ii, net, params.comm_range);
                net.energy(ii) = max(net.energy(ii) - e_tx_dio, 0);
                net.energy(nb) = max(net.energy(nb) - e_rx_dio, 0);
                net.rpl_heard(nb) = net.rpl_heard(nb) + 1;
                net = check_node_death(net, ii, params);
                for jj = nb, net = check_node_death(net, jj, params); end
            end
    end

    % Each alive node generates and sends one packet per round
    for i = 1:length(alive_idx)
        node_id = alive_idx(i);
        pkt_class = generate_packet(scenario, params);
        data_pkts = data_pkts + 1;

        switch protocol_name
           case {'AODV','DSDV','ZRP','EH_Routing','MSLBA'}
                [net, c_od] = route_baseline(node_id, pkt_class, net, params, protocol_name);
                ctrl_pkts = ctrl_pkts + c_od;

            case 'CARHy_RL'
                [mode_selected, action_idx, s] = ...
                    context_classifier_rl(node_id, pkt_class, net, params, Q, epsilon);

                if strcmp(mode_selected, 'defer')
                    net.energy(node_id) = max(net.energy(node_id) ...
                        - params.L*params.E_elec*0.1, 0);
                    net = check_node_death(net, node_id, params);
                    net.metrics.total_sent = net.metrics.total_sent + 1;
                    continue;
                end

                net.defer_count(node_id) = 0;
                [net, delivered, lat_data, n_hops, ~, e_used] = ...
                    forward_to_dest(node_id, net, params, net.BS, 'carl');

                lat = lat_data; ctrl = 0;
                switch mode_selected
                    case 'proactive'
                        ctrl = 1;
                        [e_tx, e_rx] = energy_model(params, params.L_ctrl, params.comm_range);
                        nb = find_neighbours(node_id, net, params.comm_range);
                        net.energy(node_id) = max(net.energy(node_id) - e_tx, 0);
                        net.energy(nb) = max(net.energy(nb) - e_rx, 0);
                        net = check_node_death(net, node_id, params);
                        for jj = nb, net = check_node_death(net, jj, params); end
                    case {'reactive','hybrid'}
                        if net.route_age(node_id) <= 0
                            ctrl = 1; net.route_age(node_id) = params.T_route;
                            if strcmp(mode_selected,'reactive')
                                lat = lat + n_hops*(params.L/params.datarate*1000);
                            end
                            [e_tx_req, e_rx_req] = energy_model(params, params.L_RREQ, params.comm_range);
                            net.energy(node_id) = max(net.energy(node_id) - e_tx_req, 0);
                            other_alive = find(net.alive); other_alive(other_alive==node_id) = [];
                            net.energy(other_alive) = max(net.energy(other_alive) - e_rx_req, 0);
                            [e_tx_rep, e_rx_rep] = energy_model(params, params.L_RREP, params.comm_range);
                            net.energy(node_id) = max(net.energy(node_id) - n_hops*(e_tx_rep+e_rx_rep), 0);
                            net = check_node_death(net, node_id, params);
                            for jj = other_alive, net = check_node_death(net, jj, params); end
                        end
                end
                ctrl_pkts = ctrl_pkts + ctrl;

                net.metrics.total_sent = net.metrics.total_sent + 1;
                if delivered
                    net.metrics.delivered = net.metrics.delivered + 1;
                    if strcmp(pkt_class,'A'), net.metrics.latency_A(end+1) = lat; end
                end

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

                        case 'RPL'
                [net, ~] = routing_rpl(node_id, pkt_class, net, params);

            case 'CARHy_Rule'
                mode_selected = context_classifier_rule(node_id, pkt_class, net, params);

                if strcmp(mode_selected, 'defer')
                    net.energy(node_id) = max(net.energy(node_id) ...
                        - params.L*params.E_elec*0.1, 0);
                    net = check_node_death(net, node_id, params);
                    net.metrics.total_sent = net.metrics.total_sent + 1;
                    continue;
                end

                [net, delivered, lat_data, n_hops, ~, ~] = ...
                    forward_to_dest(node_id, net, params, net.BS, 'carl');

                lat = lat_data; ctrl = 0;
                switch mode_selected
                    case 'proactive'
                        ctrl = 1;
                        [e_tx, e_rx] = energy_model(params, params.L_ctrl, params.comm_range);
                        nb = find_neighbours(node_id, net, params.comm_range);
                        net.energy(node_id) = max(net.energy(node_id) - e_tx, 0);
                        net.energy(nb) = max(net.energy(nb) - e_rx, 0);
                        net = check_node_death(net, node_id, params);
                        for jj = nb, net = check_node_death(net, jj, params); end
                    case {'reactive','hybrid'}
                        if net.route_age(node_id) <= 0
                            ctrl = 1; net.route_age(node_id) = params.T_route;
                            if strcmp(mode_selected,'reactive')
                                lat = lat + n_hops*(params.L/params.datarate*1000);
                            end
                            [e_tx_req, e_rx_req] = energy_model(params, params.L_RREQ, params.comm_range);
                            net.energy(node_id) = max(net.energy(node_id) - e_tx_req, 0);
                            other_alive = find(net.alive); other_alive(other_alive==node_id) = [];
                            net.energy(other_alive) = max(net.energy(other_alive) - e_rx_req, 0);
                            [e_tx_rep, e_rx_rep] = energy_model(params, params.L_RREP, params.comm_range);
                            net.energy(node_id) = max(net.energy(node_id) - n_hops*(e_tx_rep+e_rx_rep), 0);
                            net = check_node_death(net, node_id, params);
                            for jj = other_alive, net = check_node_death(net, jj, params); end
                        end
                end
                ctrl_pkts = ctrl_pkts + ctrl;

                net.metrics.total_sent = net.metrics.total_sent + 1;
                if delivered
                    net.metrics.delivered = net.metrics.delivered + 1;
                    if strcmp(pkt_class,'A'), net.metrics.latency_A(end+1) = lat; end
                end
                % No Q-table, no reward, no learning — this is the whole
                % point of the ablation: identical energy/routing mechanics,
                % zero learned adaptation.
        end  % end switch protocol_name
    end  % end for each alive node

    net.metrics.alive_per_round(r)  = sum(net.alive);
    net.metrics.energy_per_round(r) = sum(net.energy(net.alive));

    if strcmp(protocol_name, 'CARHy_RL')
        epsilon = max(epsilon * epsilon_decay, epsilon_min);
        Q_history(r) = max_delta_this_round;
        max_delta_this_round = 0;
    end

end  % end for each round

%% ── Compute final metrics ─────────────────────────────────────────────────

metrics.FND = net.FND;
if metrics.FND == 0
    metrics.FND = R;
end

metrics.HND = net.HND;
if metrics.HND == 0
    metrics.HND = R;
end

if net.metrics.total_sent > 0
    metrics.PDR = net.metrics.delivered / net.metrics.total_sent;
else
    metrics.PDR = 0;
end

if ~isempty(net.metrics.latency_A)
    metrics.LatA = mean(net.metrics.latency_A);
else
    metrics.LatA = 0;
end

alive_rounds = find(net.metrics.energy_per_round > 0);
if ~isempty(alive_rounds)
    E_initial = sum(net.E0);
    E_remaining = sum(net.energy);
    metrics.AvgEnergy = (E_initial - E_remaining) / length(alive_rounds);
else
    metrics.AvgEnergy = 0;
end

metrics.Gini = compute_gini(net.E0 - net.energy);

if data_pkts > 0
    if any(strcmp(protocol_name, {'RLCR','FQ_UCR'}))
        metrics.Overhead      = net.cluster_ctrl / data_pkts;
        metrics.Overhead_tdma = (net.cluster_ctrl + net.cluster_ctrl_tdma) / data_pkts;
    else
        metrics.Overhead      = ctrl_pkts / data_pkts;
        metrics.Overhead_tdma = metrics.Overhead;
    end
else
    metrics.Overhead = 0; metrics.Overhead_tdma = 0;
end
metrics.LND            = net.LND;  if metrics.LND==0, metrics.LND = R; end
metrics.TotalDelivered = net.metrics.delivered;
metrics.TotalEnergy    = sum(net.E0) - sum(net.energy);
metrics.EndRound       = end_round;
metrics.CapHit         = cap_hit;

metrics.Throughput = net.metrics.delivered / R;
metrics.alive_per_round = net.metrics.alive_per_round;

if strcmp(protocol_name, 'CARHy_RL')
    metrics.Q_table = Q;
    metrics.Q_history = Q_history;
    metrics.final_epsilon = epsilon;
end

end
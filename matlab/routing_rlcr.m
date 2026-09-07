function [net, latency] = routing_rlcr(node_id, packet_class, net, params)
% ROUTING_RLCR  RLCR: RL-based Clustering and Routing (Daanoune & Baghdad 2026)
%   Published in Ad Hoc Networks, vol. 188, 2026.
%
%   Two-phase protocol:
%     Phase 1: Q-Learning CH selection — each node decides whether to
%              become a CH based on residual energy, distance to BS,
%              and local node density.
%     Phase 2: Q-Learning inter-cluster routing — CHs select the best
%              next-hop CH to forward data to BS.
%
%   The Q-table is stored in net.rlcr_Q and persists across rounds.

%% ── Initialise RLCR state on first call ──────────────────────────────────
if ~isfield(net, 'rlcr_init') || ~net.rlcr_init
    % CH selection Q-table: per node
    % State: (energy_level, dist_level, density_level) = 3x3x3 = 27 states
    % Action: 1=become_CH, 2=stay_member
    net.rlcr_Q_ch = zeros(params.N, 27, 2);
    
    % Routing Q-table: per CH
    % State: current_CH_id (up to N)
    % Action: next_hop_CH_id (up to N)
    net.rlcr_Q_route = zeros(params.N, params.N) * 0.01;
    
    net.rlcr_ch_list = [];
    net.rlcr_membership = zeros(1, params.N);  % which CH each node belongs to
    net.rlcr_alpha = 0.1;
    net.rlcr_gamma = 0.9;
    net.rlcr_epsilon = 0.1;
    net.rlcr_init = true;
    net.rlcr_last_cluster_round = 0;
end

%% ── Phase 1: Clustering (re-cluster every 50 rounds) ─────────────────────
cluster_interval = 50;
if net.round - net.rlcr_last_cluster_round >= cluster_interval
    
    alive_nodes = find(net.alive);
    n_alive = length(alive_nodes);
    
    % Each alive node decides: CH or member
    ch_candidates = [];
    for idx = 1:n_alive
        nid = alive_nodes(idx);
        
        % Compute state
        E_r = net.energy(nid) / net.E0(nid);
        d_bs = sqrt((net.x(nid) - params.BS_x)^2 + (net.y(nid) - params.BS_y)^2);
        d_max = sqrt(2) * params.A;
        d_norm = d_bs / d_max;
        
        % Count neighbours within 100m
        n_nb = 0;
        for j = 1:length(alive_nodes)
            if alive_nodes(j) ~= nid
                d = sqrt((net.x(alive_nodes(j)) - net.x(nid))^2 + ...
                         (net.y(alive_nodes(j)) - net.y(nid))^2);
                if d <= 100
                    n_nb = n_nb + 1;
                end
            end
        end
        density = min(n_nb / 20, 1);  % normalise: 20 neighbours = max
        
        % Discretise to 3 levels each
        e_level = min(floor(E_r * 3) + 1, 3);
        d_level = min(floor(d_norm * 3) + 1, 3);
        den_level = min(floor(density * 3) + 1, 3);
        
        s = (e_level-1)*9 + (d_level-1)*3 + den_level;
        
        % Epsilon-greedy action selection
        if rand() < net.rlcr_epsilon
            action = randi(2);
        else
            [~, action] = max(net.rlcr_Q_ch(nid, s, :));
        end
        
        if action == 1  % become CH
            ch_candidates = [ch_candidates, nid];
        end
        
        % Store state for later Q-update
        net.rlcr_node_state(nid) = s;
        net.rlcr_node_action(nid) = action;
    end
    
    % If too few CHs, force top-energy nodes
    target_ch = max(round(n_alive * 0.1), 2);
    if length(ch_candidates) < target_ch
        [~, sorted_idx] = sort(net.energy(alive_nodes), 'descend');
        ch_candidates = alive_nodes(sorted_idx(1:target_ch));
    end
    
    % If too many CHs, keep top-energy ones
    if length(ch_candidates) > round(n_alive * 0.2)
        [~, sorted_idx] = sort(net.energy(ch_candidates), 'descend');
        ch_candidates = ch_candidates(sorted_idx(1:round(n_alive * 0.15)));
    end
    
    net.rlcr_ch_list = ch_candidates;
    
    % Assign members to nearest CH
    for idx = 1:n_alive
        nid = alive_nodes(idx);
        if ismember(nid, ch_candidates)
            net.rlcr_membership(nid) = nid;  % CH is its own member
        else
            min_dist = inf;
            best_ch = ch_candidates(1);
            for c = 1:length(ch_candidates)
                d = sqrt((net.x(nid) - net.x(ch_candidates(c)))^2 + ...
                         (net.y(nid) - net.y(ch_candidates(c)))^2);
                if d < min_dist
                    min_dist = d;
                    best_ch = ch_candidates(c);
                end
            end
            net.rlcr_membership(nid) = best_ch;
        end
    end
    
    % Update CH selection Q-table based on cluster quality
    for idx = 1:n_alive
        nid = alive_nodes(idx);
        s = net.rlcr_node_state(nid);
        a = net.rlcr_node_action(nid);
        
        % Reward: higher for CHs with balanced clusters, lower for depleted CHs
        if ismember(nid, ch_candidates)
            cluster_size = sum(net.rlcr_membership(alive_nodes) == nid);
            reward = net.energy(nid)/net.E0(nid) - 0.1 * abs(cluster_size - n_alive/length(ch_candidates)) / n_alive;
        else
            % Member reward: closer to CH = better
            my_ch = net.rlcr_membership(nid);
            d_ch = sqrt((net.x(nid)-net.x(my_ch))^2 + (net.y(nid)-net.y(my_ch))^2);
            reward = 1 - d_ch/200;
        end
        
        reward = max(min(reward, 1), -1);
        old_q = net.rlcr_Q_ch(nid, s, a);
        net.rlcr_Q_ch(nid, s, a) = old_q + net.rlcr_alpha * (reward + net.rlcr_gamma * max(net.rlcr_Q_ch(nid, s, :)) - old_q);
    end
    
       % Re-clustering control overhead: CH advertisement (all) + joins (members)
    n_ch = length(net.rlcr_ch_list);
    net.cluster_ctrl = net.cluster_ctrl + n_alive + (n_alive - n_ch);

    % ── Control-packet energy: CH advertisement (broadcast) + join (unicast) ──
    [e_tx_adv, e_rx_adv] = energy_model(params, params.L_ctrl, params.comm_range);
    for idx = 1:n_alive
        nid = alive_nodes(idx);
        nb  = find_neighbours(nid, net, params.comm_range);
        net.energy(nid) = max(net.energy(nid) - e_tx_adv, 0);
        net.energy(nb)  = max(net.energy(nb)  - e_rx_adv, 0);
    end
    for idx = 1:n_alive
        nid = alive_nodes(idx);
        if ~ismember(nid, ch_candidates)
            my_ch = net.rlcr_membership(nid);
            d_join = sqrt((net.x(nid)-net.x(my_ch))^2 + (net.y(nid)-net.y(my_ch))^2);
            [e_tx_j, e_rx_j] = energy_model(params, params.L_ctrl, d_join);
            net.energy(nid)   = max(net.energy(nid)   - e_tx_j, 0);
            net.energy(my_ch) = max(net.energy(my_ch) - e_rx_j, 0);
        end
    end
    for idx = 1:n_alive
        net = check_node_death(net, alive_nodes(idx), params);
    end

    net.rlcr_last_cluster_round = net.round;
end

%% ── Phase 2: routing on the real channel (all hops via transmit_hop) ─────
my_ch = net.rlcr_membership(node_id);
if my_ch == 0 || ~net.alive(my_ch), my_ch = node_id; end

delivered = true; latency = 0;

% Step A: Member -> CH (one channel-aware hop)
if node_id ~= my_ch
    [net, ok, dl] = transmit_hop(net, params, node_id, my_ch);
    latency = latency + dl;
    if ~ok, delivered = false; end
end

% Step B: CH -> BS (inter-cluster Q-routing), each hop channel-aware
if delivered
    current = my_ch; hops = 0; max_hops = 10; visited = false(1, params.N);
    while current ~= 0 && hops < max_hops
        visited(current) = true;
        d_to_bs = sqrt((net.x(current)-params.BS_x)^2 + (net.y(current)-params.BS_y)^2);
        if d_to_bs <= params.comm_range
            [net, ok, dl] = transmit_hop(net, params, current, 0);
            latency = latency + dl; if ~ok, delivered = false; end
            break;
        end
        candidate_chs = net.rlcr_ch_list(net.alive(net.rlcr_ch_list) & ~visited(net.rlcr_ch_list));
        if isempty(candidate_chs)
            [net, ok, dl] = transmit_hop(net, params, current, 0);
            latency = latency + dl; if ~ok, delivered = false; end
            break;
        end
        if rand() < net.rlcr_epsilon
            next_hop = candidate_chs(randi(length(candidate_chs)));
        else
            [~, bi] = max(net.rlcr_Q_route(current, candidate_chs));
            next_hop = candidate_chs(bi);
        end
        [net, ok, dl] = transmit_hop(net, params, current, next_hop);
        latency = latency + dl;
        if ~ok, delivered = false; break; end
        d_next_bs = sqrt((net.x(next_hop)-params.BS_x)^2 + (net.y(next_hop)-params.BS_y)^2);
        progress = (d_to_bs - d_next_bs) / d_to_bs;
        route_reward = 0.5*progress + 0.5*(net.energy(next_hop)/net.E0(next_hop));
        if ~isnan(route_reward)
            old_q = net.rlcr_Q_route(current, next_hop);
            fmax = max(net.rlcr_Q_route(next_hop, :)); if isnan(fmax), fmax = 0; end
            net.rlcr_Q_route(current, next_hop) = old_q + net.rlcr_alpha*(route_reward + net.rlcr_gamma*fmax - old_q);
        end
        current = next_hop; hops = hops + 1;
    end
end

% TDMA per-round intra-cluster signalling (amortised; only in 'tdma' mode)
na = sum(net.alive);
if na > 0 && ~isempty(net.rlcr_ch_list)
    net.cluster_ctrl_tdma = net.cluster_ctrl_tdma + sum(net.alive(net.rlcr_ch_list))/na;
end

% Metrics
net.metrics.total_sent = net.metrics.total_sent + 1;
if delivered
    net.metrics.delivered = net.metrics.delivered + 1;
    if strcmp(packet_class, 'A'), net.metrics.latency_A(end+1) = latency; end
end

end
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
    
    net.rlcr_last_cluster_round = net.round;
end

%% ── Phase 2: Intra-cluster + Inter-cluster Routing ───────────────────────
my_ch = net.rlcr_membership(node_id);
if my_ch == 0
    my_ch = node_id;  % fallback
end

% Step A: Member → CH transmission (intra-cluster)
if node_id ~= my_ch
    d_to_ch = sqrt((net.x(node_id)-net.x(my_ch))^2 + (net.y(node_id)-net.y(my_ch))^2);
    net = deduct_energy_tx(net, node_id, d_to_ch, params);
    net = deduct_energy_rx(net, my_ch, params);
end

% Step B: CH → BS routing (inter-cluster Q-Learning)
current = my_ch;
hops = 0;
max_hops = 10;
visited = false(1, params.N);

while current ~= 0 && hops < max_hops
    visited(current) = true;
    d_to_bs = sqrt((net.x(current)-params.BS_x)^2 + (net.y(current)-params.BS_y)^2);
    
    % If within direct range, send to BS
    if d_to_bs <= 150
        net = deduct_energy_tx(net, current, d_to_bs, params);
        break;
    end
    
    % Q-Learning: select next-hop CH
    candidate_chs = net.rlcr_ch_list(net.alive(net.rlcr_ch_list) & ~visited(net.rlcr_ch_list));
    
    if isempty(candidate_chs)
        % No CH available, send directly to BS
        net = deduct_energy_tx(net, current, d_to_bs, params);
        break;
    end
    
    % Epsilon-greedy
    if rand() < net.rlcr_epsilon
        next_hop = candidate_chs(randi(length(candidate_chs)));
    else
        q_vals = net.rlcr_Q_route(current, candidate_chs);
        [~, best_idx] = max(q_vals);
        next_hop = candidate_chs(best_idx);
    end
    
    % Transmit to next hop
    d_hop = sqrt((net.x(current)-net.x(next_hop))^2 + (net.y(current)-net.y(next_hop))^2);
    net = deduct_energy_tx(net, current, d_hop, params);
    net = deduct_energy_rx(net, next_hop, params);
    
    % Compute routing reward
    d_next_bs = sqrt((net.x(next_hop)-params.BS_x)^2 + (net.y(next_hop)-params.BS_y)^2);
    progress = (d_to_bs - d_next_bs) / d_to_bs;
    energy_factor = net.energy(next_hop) / net.E0(next_hop);
    route_reward = 0.5 * progress + 0.5 * energy_factor;
    
    % Q-update
    if ~isnan(route_reward)
        old_q = net.rlcr_Q_route(current, next_hop);
        future_max = max(net.rlcr_Q_route(next_hop, :));
        if isnan(future_max), future_max = 0; end
        net.rlcr_Q_route(current, next_hop) = old_q + net.rlcr_alpha * ...
            (route_reward + net.rlcr_gamma * future_max - old_q);
    end
    
    current = next_hop;
    hops = hops + 1;
end

% Clustering protocols don't differentiate traffic class
% Latency = cluster formation delay + intra-cluster + inter-cluster hops
latency = 15 + hops * 12 + rand() * 5;

% Record delivery
net.metrics.total_sent = net.metrics.total_sent + 1;
net.metrics.delivered = net.metrics.delivered + 1;
if strcmp(packet_class, 'A')
    net.metrics.latency_A = [net.metrics.latency_A, latency];
end

end

function net = deduct_energy_tx(net, node_id, d, params)
    E_elec = params.E_elec;
    eps_fs = params.eps_fs;
    eps_mp = params.eps_mp;
    L = params.L;
    d0 = sqrt(eps_fs / eps_mp);
    
    if d < d0
        e_tx = L * E_elec + L * eps_fs * d^2;
    else
        e_tx = L * E_elec + L * eps_mp * d^4;
    end
    
    net.energy(node_id) = max(net.energy(node_id) - e_tx, 0);
    if net.energy(node_id) <= 0 && net.alive(node_id)
        net.alive(node_id) = false;
        dead_count = sum(~net.alive(1:params.N));
        % Track FND
        if net.FND == 0
            net.FND = net.round;
            fprintf('  >> FND at round %d (node %d died)\n', net.round, node_id);
        end
        % Track HND
        if net.HND == 0 && dead_count >= floor(params.N / 2)
            net.HND = net.round;
            fprintf('  >> HND at round %d (%d nodes dead)\n', net.round, dead_count);
        end
    end
end

function net = deduct_energy_rx(net, node_id, params)
    e_rx = params.L * params.E_elec;
    net.energy(node_id) = max(net.energy(node_id) - e_rx, 0);
    if net.energy(node_id) <= 0 && net.alive(node_id)
        net.alive(node_id) = false;
        dead_count = sum(~net.alive(1:params.N));
        if net.FND == 0
            net.FND = net.round;
            fprintf('  >> FND at round %d (node %d died)\n', net.round, node_id);
        end
        if net.HND == 0 && dead_count >= floor(params.N / 2)
            net.HND = net.round;
            fprintf('  >> HND at round %d (%d nodes dead)\n', net.round, dead_count);
        end
    end
end
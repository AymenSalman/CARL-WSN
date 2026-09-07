function [net, latency] = routing_fqucr(node_id, packet_class, net, params)
% ROUTING_FQUCR  FQ-UCR: Fuzzy Q-Learning Unequal Clustering Routing
%   (Wang & Duan, Entropy 2025, DOI: 10.3390/e27020118)
%
%   Phase 1: Unequal clustering using fuzzy logic
%     - Inputs: residual energy, distance to BS, node density
%     - Output: CH competition radius (unequal clusters)
%     - CHs closer to BS get smaller clusters to preserve energy
%
%   Phase 2: Inter-cluster routing using Q-Learning
%     - CHs learn optimal next-hop CH toward BS
%     - Reward: weighted combination of progress + relay energy

%% ── Initialise FQ-UCR state on first call ────────────────────────────────
if ~isfield(net, 'fqucr_init') || ~net.fqucr_init
    net.fqucr_Q_route = zeros(params.N, params.N) * 0.01;
    net.fqucr_ch_list = [];
    net.fqucr_membership = zeros(1, params.N);
    net.fqucr_alpha = 0.1;
    net.fqucr_gamma = 0.9;
    net.fqucr_epsilon = 0.1;
    net.fqucr_init = true;
    net.fqucr_last_cluster_round = 0;
end

%% ── Phase 1: Fuzzy-based Unequal Clustering (every 50 rounds) ───────────
cluster_interval = 50;
if net.round - net.fqucr_last_cluster_round >= cluster_interval
    
    alive_nodes = find(net.alive);
    n_alive = length(alive_nodes);
    
    % Compute fuzzy CH probability for each node
    ch_scores = zeros(1, params.N);
    comp_radius = zeros(1, params.N);
    
    for idx = 1:n_alive
        nid = alive_nodes(idx);
        
        % Fuzzy inputs (normalised 0-1)
        E_r = net.energy(nid) / net.E0(nid);
        d_bs = sqrt((net.x(nid)-params.BS_x)^2 + (net.y(nid)-params.BS_y)^2);
        d_max = sqrt(2) * params.A;
        d_norm = d_bs / d_max;
        
        % Count neighbours
        n_nb = 0;
        for j = 1:length(alive_nodes)
            if alive_nodes(j) ~= nid
                d = sqrt((net.x(alive_nodes(j))-net.x(nid))^2 + ...
                         (net.y(alive_nodes(j))-net.y(nid))^2);
                if d <= 100
                    n_nb = n_nb + 1;
                end
            end
        end
        density = min(n_nb / 20, 1);
        
        % Fuzzy inference (simplified Mamdani-style)
        % Rule 1: High energy + far from BS + high density → high CH chance
        % Rule 2: Low energy → low CH chance
        % Rule 3: Close to BS → smaller competition radius
        
        % Fuzzy membership functions
        % Energy: low(<0.3), medium(0.2-0.7), high(>0.5)
        mu_e_low = max(0, min(1, (0.3 - E_r) / 0.3));
        mu_e_med = max(0, min((E_r - 0.2)/0.3, (0.7 - E_r)/0.2));
        mu_e_high = max(0, min(1, (E_r - 0.5) / 0.5));
        
        % Distance: near(<0.3), medium(0.2-0.7), far(>0.5)
        mu_d_near = max(0, min(1, (0.3 - d_norm) / 0.3));
        mu_d_med = max(0, min((d_norm - 0.2)/0.3, (0.7 - d_norm)/0.2));
        mu_d_far = max(0, min(1, (d_norm - 0.5) / 0.5));
        
        % Density: sparse(<0.3), medium(0.2-0.7), dense(>0.5)
        mu_den_sparse = max(0, min(1, (0.3 - density) / 0.3));
        mu_den_med = max(0, min((density - 0.2)/0.3, (0.7 - density)/0.2));
        mu_den_dense = max(0, min(1, (density - 0.5) / 0.5));
        
        % Fuzzy rules for CH probability (centroid defuzzification)
        % Rule weights: high energy = good, far from BS = good, dense = good
        score = 0; weight_sum = 0;
        
        % R1: high energy, far, dense → very high (0.9)
        w = min([mu_e_high, mu_d_far, mu_den_dense]);
        score = score + w * 0.9; weight_sum = weight_sum + w;
        
        % R2: high energy, medium dist, medium density → high (0.7)
        w = min([mu_e_high, mu_d_med, mu_den_med]);
        score = score + w * 0.7; weight_sum = weight_sum + w;
        
        % R3: medium energy, far, dense → medium (0.5)
        w = min([mu_e_med, mu_d_far, mu_den_dense]);
        score = score + w * 0.5; weight_sum = weight_sum + w;
        
        % R4: medium energy, medium, medium → medium (0.4)
        w = min([mu_e_med, mu_d_med, mu_den_med]);
        score = score + w * 0.4; weight_sum = weight_sum + w;
        
        % R5: low energy, any, any → low (0.1)
        w = mu_e_low;
        score = score + w * 0.1; weight_sum = weight_sum + w;
        
        % R6: any energy, near BS, any → medium-low (0.3)
        w = mu_d_near;
        score = score + w * 0.3; weight_sum = weight_sum + w;
        
        % R7: high energy, near, dense → medium (0.5) — needed near BS
        w = min([mu_e_high, mu_d_near, mu_den_dense]);
        score = score + w * 0.5; weight_sum = weight_sum + w;
        
        if weight_sum > 0
            ch_scores(nid) = score / weight_sum;
        else
            ch_scores(nid) = E_r * 0.5;  % fallback
        end
        
        % Unequal competition radius: closer to BS = smaller radius
        % This is the key FQ-UCR innovation
        R_max = 100;
        R_min = 40;
        comp_radius(nid) = R_max - (R_max - R_min) * (1 - d_norm);
    end
    
    % Select CHs: nodes with score above threshold, resolve conflicts
    threshold = 0.4;
    tentative_chs = alive_nodes(ch_scores(alive_nodes) >= threshold);
    
    % Conflict resolution: if two tentative CHs within comp_radius, keep higher score
    final_chs = [];
    [~, sorted_idx] = sort(ch_scores(tentative_chs), 'descend');
    tentative_sorted = tentative_chs(sorted_idx);
    
    for idx = 1:length(tentative_sorted)
        nid = tentative_sorted(idx);
        conflict = false;
        for c = 1:length(final_chs)
            d = sqrt((net.x(nid)-net.x(final_chs(c)))^2 + ...
                     (net.y(nid)-net.y(final_chs(c)))^2);
            if d < comp_radius(nid)
                conflict = true;
                break;
            end
        end
        if ~conflict
            final_chs = [final_chs, nid];
        end
    end
    
    % Ensure minimum CHs
    if length(final_chs) < 2
        [~, sorted_all] = sort(net.energy(alive_nodes), 'descend');
        final_chs = alive_nodes(sorted_all(1:min(3, n_alive)));
    end
    
    net.fqucr_ch_list = final_chs;
    
    % Assign members to nearest CH
    for idx = 1:n_alive
        nid = alive_nodes(idx);
        if ismember(nid, final_chs)
            net.fqucr_membership(nid) = nid;
        else
            min_dist = inf;
            best_ch = final_chs(1);
            for c = 1:length(final_chs)
                d = sqrt((net.x(nid)-net.x(final_chs(c)))^2 + ...
                         (net.y(nid)-net.y(final_chs(c)))^2);
                if d < min_dist
                    min_dist = d;
                    best_ch = final_chs(c);
                end
            end
            net.fqucr_membership(nid) = best_ch;
        end
    end
    
       n_ch = length(net.fqucr_ch_list);
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
        if ~ismember(nid, final_chs)
            my_ch = net.fqucr_membership(nid);
            d_join = sqrt((net.x(nid)-net.x(my_ch))^2 + (net.y(nid)-net.y(my_ch))^2);
            [e_tx_j, e_rx_j] = energy_model(params, params.L_ctrl, d_join);
            net.energy(nid)   = max(net.energy(nid)   - e_tx_j, 0);
            net.energy(my_ch) = max(net.energy(my_ch) - e_rx_j, 0);
        end
    end
    for idx = 1:n_alive
        net = check_node_death(net, alive_nodes(idx), params);
    end

    net.fqucr_last_cluster_round = net.round;
end















%% ── Phase 2: routing on the real channel (all hops via transmit_hop) ─────
my_ch = net.fqucr_membership(node_id);
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
        candidate_chs = net.fqucr_ch_list(net.alive(net.fqucr_ch_list) & ~visited(net.fqucr_ch_list));
        if isempty(candidate_chs)
            [net, ok, dl] = transmit_hop(net, params, current, 0);
            latency = latency + dl; if ~ok, delivered = false; end
            break;
        end
        if rand() < net.fqucr_epsilon
            next_hop = candidate_chs(randi(length(candidate_chs)));
        else
            [~, bi] = max(net.fqucr_Q_route(current, candidate_chs));
            next_hop = candidate_chs(bi);
        end
        [net, ok, dl] = transmit_hop(net, params, current, next_hop);
        latency = latency + dl;
        if ~ok, delivered = false; break; end
        d_next_bs = sqrt((net.x(next_hop)-params.BS_x)^2 + (net.y(next_hop)-params.BS_y)^2);
        progress = (d_to_bs - d_next_bs) / d_to_bs;
        route_reward = 0.6*progress + 0.4*(net.energy(next_hop)/net.E0(next_hop));
        if ~isnan(route_reward)
            old_q = net.fqucr_Q_route(current, next_hop);
            fmax = max(net.fqucr_Q_route(next_hop, :)); if isnan(fmax), fmax = 0; end
            net.fqucr_Q_route(current, next_hop) = old_q + net.fqucr_alpha*(route_reward + net.fqucr_gamma*fmax - old_q);
        end
        current = next_hop; hops = hops + 1;
    end
end

% TDMA per-round intra-cluster signalling (amortised; only in 'tdma' mode)
na = sum(net.alive);
if na > 0 && ~isempty(net.fqucr_ch_list)
    net.cluster_ctrl_tdma = net.cluster_ctrl_tdma + sum(net.alive(net.fqucr_ch_list))/na;
end

% Metrics
net.metrics.total_sent = net.metrics.total_sent + 1;
if delivered
    net.metrics.delivered = net.metrics.delivered + 1;
    if strcmp(packet_class, 'A'), net.metrics.latency_A(end+1) = latency; end
end

end
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
    
    net.fqucr_last_cluster_round = net.round;
end

%% ── Phase 2: Intra-cluster + Inter-cluster Routing ───────────────────────
my_ch = net.fqucr_membership(node_id);
if my_ch == 0
    my_ch = node_id;
end

% Member → CH transmission
if node_id ~= my_ch
    d_to_ch = sqrt((net.x(node_id)-net.x(my_ch))^2 + (net.y(node_id)-net.y(my_ch))^2);
    net = deduct_energy_tx_fq(net, node_id, d_to_ch, params);
    net = deduct_energy_rx_fq(net, my_ch, params);
end

% CH → BS: Q-Learning inter-cluster routing
current = my_ch;
hops = 0;
max_hops = 10;
visited = false(1, params.N);

while current ~= 0 && hops < max_hops
    visited(current) = true;
    d_to_bs = sqrt((net.x(current)-params.BS_x)^2 + (net.y(current)-params.BS_y)^2);
    
    if d_to_bs <= 150
        net = deduct_energy_tx_fq(net, current, d_to_bs, params);
        break;
    end
    
    % Find candidate next-hop CHs
    candidate_chs = net.fqucr_ch_list(net.alive(net.fqucr_ch_list) & ~visited(net.fqucr_ch_list));
    
    if isempty(candidate_chs)
        net = deduct_energy_tx_fq(net, current, d_to_bs, params);
        break;
    end
    
    % Epsilon-greedy
    if rand() < net.fqucr_epsilon
        next_hop = candidate_chs(randi(length(candidate_chs)));
    else
        q_vals = net.fqucr_Q_route(current, candidate_chs);
        [~, best_idx] = max(q_vals);
        next_hop = candidate_chs(best_idx);
    end
    
    % Transmit
    d_hop = sqrt((net.x(current)-net.x(next_hop))^2 + (net.y(current)-net.y(next_hop))^2);
    net = deduct_energy_tx_fq(net, current, d_hop, params);
    net = deduct_energy_rx_fq(net, next_hop, params);
    
    % Reward
    d_next_bs = sqrt((net.x(next_hop)-params.BS_x)^2 + (net.y(next_hop)-params.BS_y)^2);
    progress = (d_to_bs - d_next_bs) / d_to_bs;
    energy_factor = net.energy(next_hop) / net.E0(next_hop);
    route_reward = 0.6 * progress + 0.4 * energy_factor;
    
    % Q-update
    if ~isnan(route_reward)
        old_q = net.fqucr_Q_route(current, next_hop);
        future_max = max(net.fqucr_Q_route(next_hop, :));
        if isnan(future_max), future_max = 0; end
        net.fqucr_Q_route(current, next_hop) = old_q + net.fqucr_alpha * ...
            (route_reward + net.fqucr_gamma * future_max - old_q);
    end
    
    current = next_hop;
    hops = hops + 1;
end

% Fuzzy clustering + Q-Learning routing latency
latency = 12 + hops * 10 + rand() * 5;

% Record delivery
net.metrics.total_sent = net.metrics.total_sent + 1;
net.metrics.delivered = net.metrics.delivered + 1;
if strcmp(packet_class, 'A')
    net.metrics.latency_A = [net.metrics.latency_A, latency];
end

end

%% ── Helpers ──────────────────────────────────────────────────────────────


function net = deduct_energy_tx_fq(net, node_id, d, params)
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

function net = deduct_energy_rx_fq(net, node_id, params)
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
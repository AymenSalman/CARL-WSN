function next_hop = select_energy_aware_hop(node_id, net, params)
% SELECT_ENERGY_AWARE_HOP  Choose next hop toward BS preferring high-energy nodes
%   Combines distance progress toward BS with residual energy of candidate relays
%   Used by CARL-WSN to extend network lifetime
%
%   Weight: 0.4 × distance_progress + 0.6 × energy_ratio

bs_x = params.BS_x;
bs_y = params.BS_y;
d_to_bs = sqrt((net.x(node_id) - bs_x)^2 + (net.y(node_id) - bs_y)^2);

% Find alive neighbours within transmission range
candidates = [];
scores = [];

for j = 1:length(net.alive)
    if ~net.alive(j) || j == node_id
        continue;
    end
    
    d_to_j = sqrt((net.x(node_id) - net.x(j))^2 + (net.y(node_id) - net.y(j))^2);
    
    if d_to_j > 100  % within communication range
        continue;
    end
    
    % Distance progress: how much closer does this relay get us to BS?
    d_j_bs = sqrt((net.x(j) - bs_x)^2 + (net.y(j) - bs_y)^2);
    progress = (d_to_bs - d_j_bs) / d_to_bs;
    
    if progress <= 0
        continue;  % skip relays that move away from BS
    end
    
    % Energy factor
    e_ratio = net.energy(j) / net.E0(j);
    
    % Combined score
    score = 0.4 * progress + 0.6 * e_ratio;
    
    candidates = [candidates, j];
    scores = [scores, score];
end

if isempty(candidates)
    next_hop = node_id;  % no valid relay, self-loop (will be handled by routing)
else
    [~, best_idx] = max(scores);
    next_hop = candidates(best_idx);
end

end
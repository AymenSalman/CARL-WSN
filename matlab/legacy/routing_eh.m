function [net, latency] = routing_eh(node_id, packet_class, net, params)
% ROUTING_EH  Energy-harvesting aware routing baseline (IJEECS 2021)
%   Selects next hop based on residual energy weighting
%   Recreated from parameters in Salman et al. IJEECS 2021

if ~net.alive(node_id)
    latency = Inf; return;
end

L = params.L;

% EH routing: prefer nodes with highest residual energy as relays
alive_nodes  = find(net.alive);
d_to_BS      = compute_distance(net.x(node_id), net.y(node_id), ...
                                 net.BS(1), net.BS(2));
best_relay   = -1;
best_score   = -Inf;

for k = alive_nodes
    if k == node_id, continue; end
    d_hop      = compute_distance(net.x(node_id), net.y(node_id), ...
                                   net.x(k), net.y(k));
    d_relay_BS = compute_distance(net.x(k), net.y(k), ...
                                   net.BS(1), net.BS(2));
    if d_relay_BS < d_to_BS && d_hop <= 200
        % Score = energy weight / distance (prefer high energy, short hop)
        score = net.energy(k) / (d_hop + 1);
        if score > best_score
            best_score = score;
            best_relay = k;
        end
    end
end

if best_relay == -1
    [E_tx, ~] = energy_model(params, L, d_to_BS);
    net.energy(node_id) = net.energy(node_id) - E_tx;
else
    d1 = compute_distance(net.x(node_id), net.y(node_id), ...
                           net.x(best_relay), net.y(best_relay));
    d2 = compute_distance(net.x(best_relay), net.y(best_relay), ...
                           net.BS(1), net.BS(2));
    [E1, Er1] = energy_model(params, L, d1);
    [E2, ~]   = energy_model(params, L, d2);
    net.energy(node_id)    = net.energy(node_id)    - E1;
    net.energy(best_relay) = net.energy(best_relay) - Er1 - E2;
end

net.energy = max(net.energy, 0);
latency    = 35 + rand() * 25;
net        = check_dead_nodes(net);
ack        = double(rand() > 0.08);
net        = update_link_stability(net, node_id, ack);
net.metrics.delivered  = net.metrics.delivered + 1;
net.metrics.total_sent = net.metrics.total_sent + 1;
if strcmp(packet_class, 'A')
    net.metrics.latency_A(end+1) = latency;
end
end
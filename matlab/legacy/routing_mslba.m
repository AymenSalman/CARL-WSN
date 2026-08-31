function [net, latency] = routing_mslba(node_id, packet_class, net, params)
% ROUTING_MSLBA  Multi-sink load balancing baseline (IJSER 2023)
%   Routes to nearest sink (BS or secondary sink) for load balancing

if ~net.alive(node_id)
    latency = Inf; return;
end

L = params.L;

% Choose closest destination: BS or sink
d_BS   = compute_distance(net.x(node_id), net.y(node_id), net.BS(1),   net.BS(2));
d_sink = compute_distance(net.x(node_id), net.y(node_id), net.sink(1), net.sink(2));

if d_BS <= d_sink
    dest = net.BS;
else
    dest = net.sink;
end

% Find best relay toward chosen destination
alive_nodes = find(net.alive);
d_dest      = compute_distance(net.x(node_id), net.y(node_id), dest(1), dest(2));
best_relay  = -1;
best_d      = d_dest;

for k = alive_nodes
    if k == node_id, continue; end
    d_hop     = compute_distance(net.x(node_id), net.y(node_id), net.x(k), net.y(k));
    d_relay_d = compute_distance(net.x(k), net.y(k), dest(1), dest(2));
    if d_relay_d < best_d && d_hop <= 200
        best_d     = d_relay_d;
        best_relay = k;
    end
end

if best_relay == -1
    [E_tx, ~] = energy_model(params, L, d_dest);
    net.energy(node_id) = net.energy(node_id) - E_tx;
else
    d1 = compute_distance(net.x(node_id), net.y(node_id), net.x(best_relay), net.y(best_relay));
    d2 = compute_distance(net.x(best_relay), net.y(best_relay), dest(1), dest(2));
    [E1, Er1] = energy_model(params, L, d1);
    [E2, ~]   = energy_model(params, L, d2);
    net.energy(node_id)    = net.energy(node_id)    - E1;
    net.energy(best_relay) = net.energy(best_relay) - Er1 - E2;
end

net.energy = max(net.energy, 0);
latency    = 30 + rand() * 30;
net        = check_dead_nodes(net);
ack        = double(rand() > 0.09);
net        = update_link_stability(net, node_id, ack);
net.metrics.delivered  = net.metrics.delivered + 1;
net.metrics.total_sent = net.metrics.total_sent + 1;
if strcmp(packet_class, 'A')
    net.metrics.latency_A(end+1) = latency;
end
end
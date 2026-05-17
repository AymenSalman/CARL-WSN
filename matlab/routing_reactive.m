function [net, latency] = routing_reactive(node_id, packet_class, net, params)
% ROUTING_REACTIVE  AODV-inspired reactive routing mode
%   Discovers route on demand via RREQ/RREP flood.
%   Energy-efficient for low-urgency traffic on stable links.
%
%   Inputs:
%     node_id      - transmitting node index
%     packet_class - 'A', 'B', or 'C'
%     net          - current network struct
%     params       - simulation parameters
%
%   Outputs:
%     net          - updated network struct
%     latency      - simulated end-to-end delay in ms

%% ── Check node is alive ───────────────────────────────────────────────────
if ~net.alive(node_id)
    latency = Inf;
    return;
end

%% ── Route discovery cost (RREQ flood) ────────────────────────────────────
L = params.L;

% RREQ overhead: broadcast to neighbours within range
neighbours = find_neighbours(node_id, net, 100);   % 100m range
n_neighbours = length(neighbours);

% Energy for broadcasting RREQ to all neighbours
E_rreq = n_neighbours * params.E_elec * L * 0.05;   % 5% of packet size
net.energy(node_id) = net.energy(node_id) - E_rreq;

%% ── Find next hop (same greedy logic as proactive) ───────────────────────
alive_nodes   = find(net.alive);
d_direct      = compute_distance(net.x(node_id), net.y(node_id), ...
                                  net.BS(1), net.BS(2));
best_relay    = -1;
best_d_to_BS  = d_direct;

for k = alive_nodes
    if k == node_id, continue; end
    d_hop      = compute_distance(net.x(node_id), net.y(node_id), ...
                                   net.x(k), net.y(k));
    d_relay_BS = compute_distance(net.x(k), net.y(k), ...
                                   net.BS(1), net.BS(2));
    if d_relay_BS < best_d_to_BS && d_hop <= 200
        best_d_to_BS = d_relay_BS;
        best_relay   = k;
    end
end

%% ── Transmit packet ───────────────────────────────────────────────────────
if best_relay == -1
    d_tx = d_direct;
    [E_tx, ~] = energy_model(params, L, d_tx);
    net.energy(node_id) = net.energy(node_id) - E_tx;
else
    d_tx1 = compute_distance(net.x(node_id), net.y(node_id), ...
                              net.x(best_relay), net.y(best_relay));
    d_tx2 = compute_distance(net.x(best_relay), net.y(best_relay), ...
                              net.BS(1), net.BS(2));
    [E_tx1, E_rx1] = energy_model(params, L, d_tx1);
    [E_tx2, ~]     = energy_model(params, L, d_tx2);
    net.energy(node_id)    = net.energy(node_id)    - E_tx1;
    net.energy(best_relay) = net.energy(best_relay) - E_rx1 - E_tx2;
end

net.energy = max(net.energy, 0);

%% ── Simulate latency ──────────────────────────────────────────────────────
% Reactive: route discovery adds delay (RREQ + RREP round trip)
rreq_delay_ms = 20 + rand() * 30;   % 20-50ms route discovery
tx_delay_ms   = 10 + rand() * 10;   % 10-20ms transmission

if strcmp(packet_class, 'A')
    % Emergency should NOT use reactive — but if it does, high latency penalty
    latency = rreq_delay_ms + tx_delay_ms + 50;
else
    latency = rreq_delay_ms + tx_delay_ms;
end

%% ── Update state ──────────────────────────────────────────────────────────
net = check_dead_nodes(net);
ack = double(rand() > 0.10);   % 90% ACK success in reactive mode
net = update_link_stability(net, node_id, ack);
net.metrics.delivered  = net.metrics.delivered + 1;
net.metrics.total_sent = net.metrics.total_sent + 1;

if strcmp(packet_class, 'A')
    net.metrics.latency_A(end+1) = latency;
end

end
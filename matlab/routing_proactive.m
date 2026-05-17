function [net, latency] = routing_proactive(node_id, packet_class, net, params)
% ROUTING_PROACTIVE  DSDV-inspired proactive routing mode
%   Transmits a packet using pre-built routing tables.
%   Routes are maintained by periodic broadcasts every round.
%   Suited for Class A emergency traffic and unstable link scenarios.
%
%   Inputs:
%     node_id      - transmitting node index
%     packet_class - 'A', 'B', or 'C'
%     net          - current network struct
%     params       - simulation parameters
%
%   Outputs:
%     net          - updated network struct (energy deducted)
%     latency      - simulated end-to-end delay in ms

%% ── Check node is alive ───────────────────────────────────────────────────
if ~net.alive(node_id)
    latency = Inf;
    return;
end

%% ── Find next hop toward Base Station ────────────────────────────────────
% Use minimum energy-weighted distance path to BS
% In proactive mode, routes are pre-computed each round

alive_nodes = find(net.alive);

% Compute direct distance from this node to BS
d_direct = compute_distance(net.x(node_id), net.y(node_id), ...
                             net.BS(1), net.BS(2));

% Find best relay: alive node closest to BS that is also reachable
best_relay    = -1;
best_d_to_BS  = d_direct;   % start with direct transmission as fallback

for k = alive_nodes
    if k == node_id
        continue;
    end
    d_hop     = compute_distance(net.x(node_id), net.y(node_id), ...
                                  net.x(k), net.y(k));
    d_relay_BS = compute_distance(net.x(k), net.y(k), ...
                                   net.BS(1), net.BS(2));

    % Select relay only if it brings us closer to BS
    % and is within transmission range (200m max)
    if d_relay_BS < best_d_to_BS && d_hop <= 200
        best_d_to_BS = d_relay_BS;
        best_relay   = k;
    end
end

%% ── Compute energy cost ───────────────────────────────────────────────────
L = params.L;   % packet size in bits

if best_relay == -1
    % Direct transmission to BS
    d_tx = d_direct;
    [E_tx, ~] = energy_model(params, L, d_tx);
    net.energy(node_id) = net.energy(node_id) - E_tx;

    % Periodic table update overhead (proactive cost)
    E_overhead = L * params.E_elec * 0.1;   % 10% overhead for table maintenance
    net.energy(node_id) = net.energy(node_id) - E_overhead;
else
    % Two-hop: node -> relay -> BS
    d_tx1 = compute_distance(net.x(node_id), net.y(node_id), ...
                              net.x(best_relay), net.y(best_relay));
    d_tx2 = compute_distance(net.x(best_relay), net.y(best_relay), ...
                              net.BS(1), net.BS(2));

    [E_tx1, E_rx1] = energy_model(params, L, d_tx1);
    [E_tx2, ~]     = energy_model(params, L, d_tx2);

    E_overhead = L * params.E_elec * 0.1;

    net.energy(node_id)    = net.energy(node_id)    - E_tx1 - E_overhead;
    net.energy(best_relay) = net.energy(best_relay) - E_rx1 - E_tx2;
end

%% ── Clamp energy to zero (node cannot go negative) ───────────────────────
net.energy = max(net.energy, 0);

%% ── Simulate latency ──────────────────────────────────────────────────────
% Proactive: route already known -> low latency
% Base: 10ms propagation + 5ms processing
% Class A gets priority queuing (no queuing delay)
base_latency_ms = 10 + 5;

if strcmp(packet_class, 'A')
    latency = base_latency_ms + rand() * 5;    % 10-15ms (priority)
else
    latency = base_latency_ms + rand() * 15;   % 10-25ms (normal)
end

%% ── Update alive status ───────────────────────────────────────────────────
net = check_dead_nodes(net);

%% ── Update ACK history (proactive: high ACK success rate) ────────────────
ack = double(rand() > 0.05);   % 95% ACK success in proactive mode
net = update_link_stability(net, node_id, ack);

%% ── Count delivered packet ───────────────────────────────────────────────
net.metrics.delivered  = net.metrics.delivered + 1;
net.metrics.total_sent = net.metrics.total_sent + 1;

if strcmp(packet_class, 'A')
    net.metrics.latency_A(end+1) = latency;
end

end
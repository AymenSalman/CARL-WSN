function [net, latency] = routing_hybrid(node_id, packet_class, net, params)
% ROUTING_HYBRID  ZRP-style hybrid routing with context-driven zone radius
%   Uses proactive routing WITHIN a zone and reactive ACROSS zones.
%   Zone radius adapts based on node energy state — energy-critical nodes
%   shrink their zone to reduce maintenance overhead.
%   This is what differentiates CARHy-WSN from fixed-radius ZRP.
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

L = params.L;

%% ── Context-driven zone radius adaptation ────────────────────────────────
% Standard ZRP uses a fixed zone radius (e.g. 2 hops)
% CARHy-WSN adapts it based on residual energy ratio
E_r = net.energy(node_id) / net.E0(node_id);

if E_r >= 0.6
    zone_range_m = 120;   % healthy node: large zone, more proactive coverage
elseif E_r >= 0.3
    zone_range_m = 80;    % moderate energy: medium zone
else
    zone_range_m = 40;    % energy-critical: small zone, minimal overhead
end

%% ── Check if BS is within zone (use proactive path) ─────────────────────
d_to_BS = compute_distance(net.x(node_id), net.y(node_id), ...
                            net.BS(1), net.BS(2));

%% ── Find best relay ──────────────────────────────────────────────────────
alive_nodes  = find(net.alive);
best_relay   = -1;
best_d_to_BS = d_to_BS;

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

%% ── Energy cost depends on whether relay is in-zone or out-of-zone ───────
if d_to_BS <= zone_range_m
    % BS is within zone: use proactive path (pre-built, low overhead)
    E_zone_overhead = L * params.E_elec * 0.08;   % 8% zone maintenance
    in_zone = true;
else
    % BS is outside zone: use reactive inter-zone routing (IERP)
    E_zone_overhead = L * params.E_elec * 0.15;   % 15% IERP overhead
    in_zone = false;
end

net.energy(node_id) = net.energy(node_id) - E_zone_overhead;

%% ── Transmit packet ───────────────────────────────────────────────────────
if best_relay == -1
    [E_tx, ~] = energy_model(params, L, d_to_BS);
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
if in_zone
    % In-zone: proactive route known, low latency
    latency = 12 + rand() * 10;      % 12-22ms
else
    % Out-of-zone: inter-zone reactive discovery
    latency = 25 + rand() * 20;      % 25-45ms
end

%% ── Update state ──────────────────────────────────────────────────────────
net = check_dead_nodes(net);
ack = double(rand() > 0.07);   % 93% ACK success in hybrid mode
net = update_link_stability(net, node_id, ack);
net.metrics.delivered  = net.metrics.delivered + 1;
net.metrics.total_sent = net.metrics.total_sent + 1;

if strcmp(packet_class, 'A')
    net.metrics.latency_A(end+1) = latency;
end

end
function metrics = run_single_simulation(params, protocol_name, scenario)
% RUN_SINGLE_SIMULATION  Runs one complete simulation
%   Returns all 8 metrics for one protocol/scenario/seed combination

%% ── Initialise ────────────────────────────────────────────────────────────
net       = init_network(params);
R         = params.rounds;
N         = params.N;
ctrl_pkts = 0;   % routing control packet counter
data_pkts = 0;   % data packet counter

%% ── Per-round simulation loop ─────────────────────────────────────────────
for r = 1:R
    net.round = r;

    % Skip round if less than 10% nodes alive
    if sum(net.alive) < floor(N * 0.10)
        break;
    end

    alive_idx = find(net.alive);

    % Each alive node generates and sends one packet per round
    for i = 1:length(alive_idx)
        node_id = alive_idx(i);

        % Generate packet class based on scenario
        pkt_class = generate_packet(scenario, params);
        data_pkts = data_pkts + 1;

        % Route packet using the specified protocol
        switch protocol_name
            case 'CARHy'
                [net, ~] = run_carhy(node_id, pkt_class, net, params);
                ctrl_pkts = ctrl_pkts + estimate_ctrl_overhead('CARHy', pkt_class, net, node_id, params);

            case 'AODV'
                [net, ~] = routing_reactive(node_id, pkt_class, net, params);
                ctrl_pkts = ctrl_pkts + estimate_ctrl_overhead('AODV', pkt_class, net, node_id, params);

            case 'DSDV'
                [net, ~] = routing_proactive(node_id, pkt_class, net, params);
                ctrl_pkts = ctrl_pkts + estimate_ctrl_overhead('DSDV', pkt_class, net, node_id, params);

            case 'ZRP'
                [net, ~] = routing_hybrid(node_id, pkt_class, net, params);
                ctrl_pkts = ctrl_pkts + estimate_ctrl_overhead('ZRP', pkt_class, net, node_id, params);

            case 'EH_Routing'
                % Energy-harvesting aware routing (your IJEECS 2021 baseline)
                [net, ~] = routing_eh(node_id, pkt_class, net, params);
                ctrl_pkts = ctrl_pkts + estimate_ctrl_overhead('EH_Routing', pkt_class, net, node_id, params);

            case 'MSLBA'
                % Multi-sink load balancing (your IJSER 2023 baseline)
                [net, ~] = routing_mslba(node_id, pkt_class, net, params);
                ctrl_pkts = ctrl_pkts + estimate_ctrl_overhead('MSLBA', pkt_class, net, node_id, params);
        end
    end

    % Record per-round metrics
    net.metrics.alive_per_round(r)  = sum(net.alive);
    net.metrics.energy_per_round(r) = sum(net.energy(net.alive));
end

%% ── Compute final metrics ─────────────────────────────────────────────────

% FND: first node death round
metrics.FND = net.FND;
if metrics.FND == 0
    metrics.FND = R;   % no node died = full lifetime
end

% HND: half node death round
metrics.HND = net.HND;
if metrics.HND == 0
    metrics.HND = R;
end

% PDR: packet delivery ratio
if net.metrics.total_sent > 0
    metrics.PDR = net.metrics.delivered / net.metrics.total_sent;
else
    metrics.PDR = 0;
end

% Class A latency (mean)
if ~isempty(net.metrics.latency_A)
    metrics.LatA = mean(net.metrics.latency_A);
else
    metrics.LatA = 0;
end

% Average energy consumed per round (across alive rounds)
alive_rounds = find(net.metrics.energy_per_round > 0);
if ~isempty(alive_rounds)
    % Energy consumed = initial total - remaining total
    E_initial = sum(net.E0);
    E_remaining = sum(net.energy);
    metrics.AvgEnergy = (E_initial - E_remaining) / length(alive_rounds);
else
    metrics.AvgEnergy = 0;
end

% Gini coefficient (energy balance — lower is better)
metrics.Gini = compute_gini(net.E0 - net.energy);

% Routing overhead (control packets per data packet)
if data_pkts > 0
    metrics.Overhead = ctrl_pkts / data_pkts;
else
    metrics.Overhead = 0;
end

% Throughput (delivered packets per round)
metrics.Throughput = net.metrics.delivered / R;

end
function [net, latency] = run_carhy(node_id, packet_class, net, params)
% RUN_CARHY  CARHy-WSN: classify context then route accordingly
%   This is the top-level function that implements the full protocol.
%   It calls context_classifier() then dispatches to the correct mode.
%
%   Inputs:
%     node_id      - transmitting node index
%     packet_class - 'A', 'B', or 'C'
%     net          - current network struct
%     params       - simulation parameters
%
%   Outputs:
%     net          - updated network struct
%     latency      - end-to-end delay in ms

%% ── Step 1: classify context ──────────────────────────────────────────────
mode = context_classifier(node_id, packet_class, net, params);

%% ── Step 2: route using selected mode ────────────────────────────────────
switch mode
    case 'proactive'
        [net, latency] = routing_proactive(node_id, packet_class, net, params);
    case 'reactive'
        [net, latency] = routing_reactive(node_id, packet_class, net, params);
    case 'hybrid'
        [net, latency] = routing_hybrid(node_id, packet_class, net, params);
    otherwise
        warning('run_carhy: unknown mode "%s"', mode);
        [net, latency] = routing_reactive(node_id, packet_class, net, params);
end

end
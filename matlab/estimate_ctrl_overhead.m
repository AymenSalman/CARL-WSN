function ctrl = estimate_ctrl_overhead(protocol, pkt_class, net, node_id, params)
% Estimate control packet overhead per data packet transmission
neighbours = find_neighbours(node_id, net, 100);
n = length(neighbours);
switch protocol
    case 'DSDV'
        ctrl = n * 0.20;   % periodic table broadcasts
    case 'AODV'
        ctrl = n * 0.10;   % RREQ + RREP
    case 'ZRP'
        ctrl = n * 0.15;   % zone table + IERP
    case 'CARHy'
        if strcmp(pkt_class, 'A')
            ctrl = n * 0.08;   % proactive for emergency
        elseif strcmp(pkt_class, 'B')
            ctrl = n * 0.05;   % reactive for telemetry
        else
            ctrl = n * 0.06;   % hybrid for events
        end
    otherwise
        ctrl = n * 0.10;
end
end
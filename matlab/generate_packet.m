function pkt_class = generate_packet(scenario, params)
% Generate packet class based on traffic scenario
switch scenario
    case 'ClassA'
        pkt_class = 'A';
    case 'ClassB'
        pkt_class = 'B';
    case 'ClassC'
        pkt_class = 'C';
    case 'Mixed'
        % Realistic mix: 20% emergency, 50% telemetry, 30% event
        r = rand();
        if r < 0.20
            pkt_class = 'A';
        elseif r < 0.70
            pkt_class = 'B';
        else
            pkt_class = 'C';
        end
    otherwise
        pkt_class = 'B';
end
end
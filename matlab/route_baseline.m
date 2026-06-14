function [net, ctrl_ondemand] = route_baseline(node_id, pkt_class, net, params, proto)
% One data packet for a non-clustering baseline: shared delivery + protocol-
% specific destination, next-hop mode, and (reactive) discovery latency/overhead.
    ctrl_ondemand = 0;
    switch proto
        case 'AODV',       dest=net.BS;   mode='greedy';  reactive=true;
        case 'DSDV',       dest=net.BS;   mode='greedy';  reactive=false;
        case 'EH_Routing', dest=net.BS;   mode='energy';  reactive=false;
        case 'ZRP',        dest=net.BS;   mode='greedy';  reactive=false;
        case 'MSLBA'
            if hypot(net.x(node_id)-net.BS(1),  net.y(node_id)-net.BS(2)) <= ...
               hypot(net.x(node_id)-net.sink(1),net.y(node_id)-net.sink(2))
                dest = net.BS;
            else
                dest = net.sink;
            end
            mode='greedy'; reactive=false;
    end

    % ZRP hybrid: reactive only when BS is beyond the energy-scaled zone
    if strcmp(proto,'ZRP')
        E_r = net.energy(node_id)/net.E0(node_id);
        if E_r>=0.7, zr=120; elseif E_r>=0.3, zr=80; else, zr=40; end
        reactive = hypot(net.x(node_id)-net.BS(1), net.y(node_id)-net.BS(2)) > zr;
    end

    [net, delivered, lat_data, n_hops, ~] = forward_to_dest(node_id, net, params, dest, mode);

    lat = lat_data;
    if reactive && n_hops>0 && net.route_age(node_id) <= 0
        ctrl_ondemand = sum(net.alive) + n_hops;          % RREQ flood + RREP
        net.route_age(node_id) = params.T_route;          % cache route
        lat = lat + 2 * n_hops * (params.L/params.datarate*1000);  % RREQ out + RREP back
    end

    net.metrics.total_sent = net.metrics.total_sent + 1;
    if delivered
        net.metrics.delivered = net.metrics.delivered + 1;
        if strcmp(pkt_class,'A'), net.metrics.latency_A(end+1) = lat; end
    end
end
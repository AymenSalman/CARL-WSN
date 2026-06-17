function [net, success, lat_added] = transmit_hop(net, params, tx, rx)
% Single channel-aware hop with ARQ (shared by clustering protocols).
%   rx > 0 : receiver is a node (charge rx energy);  rx <= 0 : BS (free rx).
% All-or-nothing after max_retx. Charges energy, checks deaths (unified),
% returns success and latency added (ms).
    if rx > 0
        d = hypot(net.x(tx)-net.x(rx), net.y(tx)-net.y(rx));
    else
        d = hypot(net.x(tx)-params.BS_x, net.y(tx)-params.BS_y);
    end
    t_tx = params.L/params.datarate*1000;
    success = false; lat_added = 0;
    for a = 1:params.max_retx
        lat_added = lat_added + t_tx + params.t_proc_ms;
        [e_tx,~] = energy_model(params, params.L, d);
        net.energy(tx) = max(net.energy(tx) - e_tx, 0);
        if rx > 0
            net.energy(rx) = max(net.energy(rx) - params.L*params.E_elec, 0);
        end
        if crn_draw(params.seed, net.round, tx, max(rx,0), a) < link_prr(d, params)
            success = true; break;
        else
            lat_added = lat_added + params.t_timeout_ms;
        end
    end
    net = check_node_death(net, tx, params);
    if rx > 0, net = check_node_death(net, rx, params); end
end
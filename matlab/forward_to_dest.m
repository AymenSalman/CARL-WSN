function [net, delivered, lat_data, n_hops, src_ack] = ...
         forward_to_dest(src, net, params, dest, mode)
% Shared multi-hop data-plane: realistic PRR channel + ARQ to `dest`.
% Updates energy, node deaths, and link stability (L_s) for the source.
% Returns delivery outcome, data-plane latency (ms), hop count, src first-hop ACK.
    t_tx = params.L/params.datarate*1000;
    cur = src; lat_data = 0; n_hops = 0; delivered = false; src_ack = NaN;
    for h = 1:params.max_hops
        dcd = hypot(net.x(cur)-dest(1), net.y(cur)-dest(2));
        if dcd <= params.comm_range
            nxt = -1; d = dcd;                    % final hop to dest (BS/sink: free rx)
        else
            nxt = pick_nexthop(cur, net, params, dest, mode);
            if nxt <= 0, break; end               % no progress -> packet dropped
            d = hypot(net.x(cur)-net.x(nxt), net.y(cur)-net.y(nxt));
        end
        success = false;
        for a = 1:params.max_retx
            lat_data = lat_data + t_tx + params.t_proc_ms;
            [e_tx,~] = energy_model(params, params.L, d);
            net.energy(cur) = max(net.energy(cur)-e_tx, 0);
            if nxt > 0
                net.energy(nxt) = max(net.energy(nxt)-params.L*params.E_elec, 0);
            end
            if crn_draw(params.seed, net.round, cur, max(nxt,0), a) < link_prr(d, params)
                success = true; break;
            else
                lat_data = lat_data + params.t_timeout_ms;   % retx timeout
            end
        end
        if h==1, src_ack = double(success); end
        n_hops = n_hops + 1;
        net = check_node_death(net, cur, params);
        if nxt > 0, net = check_node_death(net, nxt, params); end
        if ~success, break; end                   % hop failed after retx -> dropped
        if nxt == -1, delivered = true; break; end
        cur = nxt;
    end
    if ~isnan(src_ack)
        net = update_link_stability(net, src, src_ack);   % L_s now lives
    end
end
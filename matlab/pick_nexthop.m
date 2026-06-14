function nxt = pick_nexthop(cur, net, params, dest, mode)
% Reliability-aware next hop toward dest (a [x y] point).
%   mode 'greedy' : score = progress * PRR     (AODV/DSDV/ZRP/MSLBA)
%   mode 'energy' : score = energy_ratio * PRR (EH-Routing)
    dcur = hypot(net.x(cur)-dest(1), net.y(cur)-dest(2));
    nxt = -1; best = -inf;
    for j = 1:numel(net.alive)
        if j==cur || ~net.alive(j), continue; end
        dj = hypot(net.x(cur)-net.x(j), net.y(cur)-net.y(j));
        if dj > params.comm_range, continue; end
        ddest = hypot(net.x(j)-dest(1), net.y(j)-dest(2));
        if ddest >= dcur, continue; end          % must make progress
        if strcmp(mode,'energy')
            s = (net.energy(j)/net.E0(j)) * link_prr(dj, params);
        else
            s = ((dcur-ddest)/dcur) * link_prr(dj, params);
        end
        if s > best, best = s; nxt = j; end
    end
end
function [net, latency] = routing_rpl(node_id, packet_class, net, params)
% ROUTING_RPL  RPL data-plane forwarding (RFC 6550, MRHOF/RFC 6719, Trickle/RFC 6206)
%   DODAG construction, rank computation, and Trickle timer maintenance are
%   handled once per round in run_single_simulation.m's per-round block
%   (mirroring DSDV/ZRP's periodic control-plane treatment). This function
%   only performs data-plane delivery along the already-established parent
%   chain, via the shared transmit_hop engine (same as RLCR/FQ-UCR).

delivered = true; latency = 0;
current = node_id; hops = 0; max_hops = params.max_hops; visited = false(1, params.N);

while hops < max_hops
    visited(current) = true;
    parent = net.rpl_parent(current);

          if parent == -1
        % No parent assigned yet (DODAG hasn't reached this node) — fails
        % immediately, consistent with the design's "no valid parent" rule.
        delivered = false;
        break;
    elseif parent == 0
        % Parent is BS directly
        [net, ok, dl] = transmit_hop(net, params, current, 0);
        latency = latency + dl; if ~ok, delivered = false; end
        break;
    elseif parent > 0 && net.alive(parent) && ~visited(parent)
        [net, ok, dl] = transmit_hop(net, params, current, parent);
        latency = latency + dl;
        if ~ok, delivered = false; break; end
        current = parent; hops = hops + 1;
    else
        % No valid parent (DODAG not yet reached this node, or parent just
        % died and re-convergence hasn't happened this round) — packet fails.
        delivered = false;
        break;
    end
end
if hops >= max_hops, delivered = false; end  % defensive backstop; rank
                                               % invariant should prevent this

net.metrics.total_sent = net.metrics.total_sent + 1;
if delivered
    net.metrics.delivered = net.metrics.delivered + 1;
    if strcmp(packet_class,'A'), net.metrics.latency_A(end+1) = latency; end
end

end
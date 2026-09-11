function [net, success] = rpl_ctrl_hop(net, params, tx, rx)
% RPL_CTRL_HOP  ARQ-protected single hop for RPL's unicast control
%   messages (DAO, DAO-ACK). Mirrors transmit_hop.m's channel model
%   (max_retx, crn_draw, link_prr) sized for L_ctrl instead of L.
%   Kept RPL-local so transmit_hop.m (shared with RLCR/FQ-UCR) is never
%   touched — this ARQ treatment applies to RPL only.
%
%   IEEE 802.15.4 MAC-layer ACK+retry applies to unicast frames; DAO is
%   unicast (real ARQ applies here). DIO remains flat/unacknowledged, as
%   it is multicast and gets no MAC-layer ACK in the real standard.
%
%   rx>0: node; rx<=0: BS (unconstrained energy, no death check).
    if rx > 0
        d = hypot(net.x(tx)-net.x(rx), net.y(tx)-net.y(rx));
    else
        d = hypot(net.x(tx)-net.BS(1), net.y(tx)-net.BS(2));
    end
    success = false;
    for a = 1:params.max_retx
        [e_tx, ~] = energy_model(params, params.L_ctrl, d);
        net.energy(tx) = max(net.energy(tx) - e_tx, 0);
        if rx > 0
            net.energy(rx) = max(net.energy(rx) - params.L_ctrl*params.E_elec, 0);
        end
        % Attempt index offset by +100 so this doesn't draw the same
        % crn_draw outcome as a data-plane transmit_hop call on the same
        % (tx,rx,round) — keeps DAO's channel draw independent of any
        % data packet that happens to use the same link this round.
        if crn_draw(params.seed, net.round, tx, max(rx,0), a+100) < link_prr(d, params)
            success = true; break;
        end
    end
    net = check_node_death(net, tx, params);
    if rx > 0, net = check_node_death(net, rx, params); end
end
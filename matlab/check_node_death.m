function net = check_node_death(net, node_id, params)
% CHECK_NODE_DEATH  Mark a single node dead if its energy is depleted.
%   Records FND, HND, and LND milestone rounds. Used by forward_to_dest
%   so all protocols share one death-tracking path.
    if net.energy(node_id) <= 0 && net.alive(node_id)
        net.alive(node_id) = false;
        dead = sum(~net.alive(1:params.N));
        if net.FND==0,                              net.FND = net.round; end
        if net.HND==0 && dead >= floor(params.N/2), net.HND = net.round; end
        if net.LND==0 && dead >= params.N,          net.LND = net.round; end
    end
end
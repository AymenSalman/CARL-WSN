function net = check_dead_nodes(net)
% CHECK_DEAD_NODES  Mark nodes with zero energy as dead
%   Also records FND and HND milestone rounds.

N = length(net.energy);

for i = 1:N
    if net.alive(i) && net.energy(i) <= 0
        net.alive(i) = false;

        % Record first node death round
        if net.FND == 0
            net.FND = net.round;
            fprintf('  >> FND at round %d (node %d died)\n', net.round, i);
        end

        % Record half node death round
        dead_count = sum(~net.alive);
        if net.HND == 0 && dead_count >= floor(N/2)
            net.HND = net.round;
            fprintf('  >> HND at round %d (%d nodes dead)\n', net.round, dead_count);
        end
    end
end

end
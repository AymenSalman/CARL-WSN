function neighbours = find_neighbours(node_id, net, range_m)
% FIND_NEIGHBOURS  Returns indices of alive nodes within range_m metres

neighbours = [];
for k = 1:length(net.alive)
    if k == node_id || ~net.alive(k)
        continue;
    end
    d = compute_distance(net.x(node_id), net.y(node_id), ...
                          net.x(k), net.y(k));
    if d <= range_m
        neighbours(end+1) = k; %#ok<AGROW>
    end
end

end
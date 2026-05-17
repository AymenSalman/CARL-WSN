function d = compute_distance(x1, y1, x2, y2)
% COMPUTE_DISTANCE  Euclidean distance between two points
%   d = compute_distance(x1, y1, x2, y2)
%
%   Works for scalar inputs (node to node) and
%   vectorised inputs (one node to all others).
%
%   Example:
%     d_to_BS = compute_distance(net.x, net.y, net.BS(1), net.BS(2));

d = sqrt((x1 - x2).^2 + (y1 - y2).^2);

end
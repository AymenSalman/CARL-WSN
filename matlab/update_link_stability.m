function net = update_link_stability(net, node_id, ack_received)
% UPDATE_LINK_STABILITY  Update ACK history after each transmission
%
%   Shifts the ACK history window and records the new outcome.
%   Called after every packet transmission attempt.
%
%   Inputs:
%     net          - network struct (modified in place)
%     node_id      - index of the transmitting node
%     ack_received - 1 if ACK received (success), 0 if lost (failure)
%
%   Output:
%     net          - updated network struct

% Shift history window: drop oldest, add newest
net.ack_history(1:end-1, node_id) = net.ack_history(2:end, node_id);
net.ack_history(end, node_id)     = ack_received;

end
function Q = init_qtable()
% INIT_QTABLE  Create empty Q-table for CARL-WSN RL agent
%   Q-table dimensions: 18 states x 3 actions
%   All values initialised to zero (agent knows nothing)
%
%   States (18 total):
%     3 urgency classes x 3 energy levels x 2 link levels
%
%   Actions (3 total):
%     1 = proactive, 2 = reactive, 3 = hybrid

Q = zeros(18, 3);

end
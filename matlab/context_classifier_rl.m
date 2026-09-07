function [mode, action_idx, s] = context_classifier_rl(node_id, packet_class, net, params, Q, epsilon)
% CONTEXT_CLASSIFIER_RL  RL-based mode selection using epsilon-greedy Q-Learning
%
%   Same inputs as context_classifier.m, plus:
%     Q       - current Q-table (18 x 3)
%     epsilon - exploration rate (0 to 1)
%
%   Outputs:
%     mode       - 'proactive', 'reactive', or 'hybrid'
%     action_idx - action taken (1, 2, or 3)
%     s          - state index (1 to 18) — needed for Q-update later
%
%   SAFETY CONSTRAINT: Class A ALWAYS uses proactive.
%   This is hardcoded and cannot be overridden by the RL agent.
%   It guarantees sub-100ms emergency latency at all times.

%% ── Step 1: Compute context vector (identical to original) ────────────
U = packet_class;
E_r = net.energy(node_id) / net.E0(node_id);

% Link stability: live EWMA maintained by forward_to_dest (Woo & Culler, a=0.5)
L_s = net.L_s(node_id);

%% ── Step 2: Discretise state ──────────────────────────────────────────
U_num    = class_to_num(U);
Er_level = discretise_energy(E_r);
Ls_level = discretise_link(L_s);
s        = state_index(U_num, Er_level, Ls_level);

%% ── Step 3: Safety constraint — Class A always proactive ──────────────
if strcmp(U, 'A')
    mode = 'proactive';
    action_idx = 1;
    return;
end

%% ── Step 3b: Critical energy deferral for non-urgent traffic ──────────
% Once a node's energy drops below T_defer, it can never recover above it
% (no energy harvesting in this model — energy is strictly non-increasing,
% Eq. 3). Therefore any deferred Class B/C packet's usefulness window
% (TTL, matching its class's own latency tolerance from Sec. 3.2) is
% mathematically guaranteed to elapse before the node could ever resume
% normal transmission. Deferral below T_defer is therefore unconditional
% and permanent for the remainder of the node's lifetime — there is no
% forced-retransmit escape valve.
if E_r < params.T_defer && (strcmp(U, 'B') || strcmp(U, 'C'))
    mode = 'defer';
    action_idx = 0;
    return;
end

%% ── Step 4: Epsilon-greedy action selection ───────────────────────────
if rand() < epsilon
    % Explore: pick random action
    action_idx = randi(3);
else
    % Exploit: pick action with highest Q-value
    [~, action_idx] = max(Q(s, :));
    
    % Break ties randomly
    max_val = Q(s, action_idx);
    best_actions = find(Q(s, :) == max_val);
    if length(best_actions) > 1
        action_idx = best_actions(randi(length(best_actions)));
    end
end

%% ── Step 5: Map action to mode string ─────────────────────────────────
modes = {'proactive', 'reactive', 'hybrid'};
mode = modes{action_idx};

end
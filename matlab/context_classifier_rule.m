function mode = context_classifier_rule(node_id, packet_class, net, params)
% CONTEXT_CLASSIFIER_RULE  Simple rule-based mode selection (Reviewer 2E
%   ablation). Steps 1-2 identical to context_classifier_rl.m (unchanged,
%   hardcoded in the real CARL-WSN too). Step 3 replaces the RL agent's
%   learned mode selection with a fixed rule derived directly from
%   CARL-WSN's own stated design rationale (§4.5.1-4.5.3), not from the
%   agent's learned results (Fig. 8) — avoiding circular comparison.

U = packet_class;
E_r = net.energy(node_id) / net.E0(node_id);
L_s = net.L_s(node_id);

if strcmp(U, 'A')
    mode = 'proactive';
    return;
end

if E_r < params.T_defer && (strcmp(U, 'B') || strcmp(U, 'C'))
    mode = 'defer';
    return;
end

% Step 3: fixed rule, grounded in §4.5.1 ("proactive... when link
% instability makes reactive discovery unreliable"), §4.5.3 ("hybrid...
% primarily for energy-critical nodes"; T_E is get_params.m's own defined
% energy-critical threshold), and §4.5.2 ("reactive... on healthy nodes
% with stable links" — B and C treated identically, matching the paper's
% own prose, which draws no B/C distinction in this description).
if L_s < params.T_L
    mode = 'proactive';
elseif E_r < params.T_E
    mode = 'hybrid';
else
    mode = 'reactive';
end

end
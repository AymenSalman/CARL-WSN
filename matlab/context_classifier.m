function mode = context_classifier(node_id, packet_class, net, params)
% CONTEXT_CLASSIFIER  Selects routing mode based on 3D context vector
%   This is the core novelty of CARHy-WSN.
%
%   Computes context vector C = (U, E_r, L_s) where:
%     U   = application urgency class (A=emergency, B=telemetry, C=best-effort)
%     E_r = normalised residual energy ratio (current/initial), range 0-1
%     L_s = link stability score (EWMA of ACK success), range 0-1
%
%   Returns one of three routing modes:
%     'proactive' - use pre-built routing tables (low latency)
%     'reactive'  - discover route on demand (low energy)
%     'hybrid'    - zone-based with context-driven radius
%
%   Inputs:
%     node_id      - index of the transmitting node (1 to N)
%     packet_class - traffic class: 'A', 'B', or 'C'
%     net          - network struct (current state)
%     params       - configuration struct
%
%   Output:
%     mode         - string: 'proactive', 'reactive', or 'hybrid'

%% ── Step 1: Compute the 3D context vector ─────────────────────────────────

% U: Urgency class (directly from packet header)
U = packet_class;   % 'A', 'B', or 'C'

% E_r: Normalised residual energy ratio
E_r = net.energy(node_id) / net.E0(node_id);
% E_r = 1.0 means full energy, E_r = 0.0 means dead

% L_s: Link stability score using EWMA of ACK history
% ack_history is a 10 x N matrix; column node_id = last 10 ACK outcomes
% 1 = ACK received (success), 0 = ACK lost (failure)
alpha = 0.3;   % EWMA smoothing factor
ack_col = net.ack_history(:, node_id);    % last 10 ACKs for this node
weights = alpha * (1-alpha).^(0:9)';     % exponentially decaying weights
weights = weights / sum(weights);         % normalise to sum = 1
L_s = dot(weights, ack_col);             % weighted average (0 to 1)

%% ── Step 2: Mode-switching decision table ─────────────────────────────────
%
%   Rule table (from CARHy-WSN proposal, Table in Section IV):
%
%   U         | E_r          | L_s          | Mode
%   ----------|--------------|--------------|------------------
%   A (emerg) | any          | any          | PROACTIVE
%   B or C    | >= T_E       | >= T_L       | REACTIVE
%   B         | <  T_E       | any          | HYBRID
%   B or C    | any          | <  T_L       | PROACTIVE
%   C         | <  T_E       | <  T_L       | REACTIVE (+ backoff)

T_E = params.T_E;   % energy threshold (default 0.3)
T_L = params.T_L;   % link stability threshold (default 0.7)

if strcmp(U, 'A')
    % Rule 1: Emergency traffic ALWAYS uses proactive
    % Pre-built routes guarantee no route-discovery delay
    mode = 'proactive';

elseif strcmp(U, 'B') || strcmp(U, 'C')

    if E_r >= T_E && L_s >= T_L
        % Rule 2: Healthy node on stable link -> reactive saves energy
        mode = 'reactive';

    elseif strcmp(U, 'B') && E_r < T_E
        % Rule 3: Telemetry on energy-critical node -> hybrid
        % Reduces broadcast overhead vs full reactive discovery
        mode = 'hybrid';

    elseif L_s < T_L
        % Rule 4: Unstable link -> proactive (use cached alternate routes)
        % Avoids repeated failed reactive route discoveries
        mode = 'proactive';

    else
        % Rule 5: Best-effort on energy-critical node -> reactive with backoff
        % Lowest priority, save energy, accept higher latency
        mode = 'reactive';
    end

else
    % Safety fallback — should never reach here
    warning('context_classifier: unknown packet class "%s", defaulting to reactive', U);
    mode = 'reactive';
end

end
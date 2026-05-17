function [E_tx, E_rx] = energy_model(params, L, d)
% ENERGY_MODEL  First-order radio energy consumption model
%   Computes energy consumed to transmit and receive a packet.
%   Based on Heinzelman et al. (2000) — the standard WSN energy model.
%
%   Inputs:
%     params  - configuration struct from get_params()
%     L       - packet size in bits
%     d       - transmission distance in metres
%
%   Outputs:
%     E_tx    - energy consumed to TRANSMIT L bits over distance d (Joules)
%     E_rx    - energy consumed to RECEIVE L bits (Joules)
%
%   Model equations:
%     If d < d0 (short range, free-space model):
%       E_tx = L * E_elec + L * epsilon_fs * d^2
%     If d >= d0 (long range, multipath model):
%       E_tx = L * E_elec + L * epsilon_mp * d^4
%     Always:
%       E_rx  = L * E_elec

%% ── Transmission energy ───────────────────────────────────────────────────
if d < params.d0
    % Short distance: free-space propagation model
    E_tx = L * params.E_elec + L * params.epsilon_fs * d^2;
else
    % Long distance: multipath propagation model
    E_tx = L * params.E_elec + L * params.epsilon_mp * d^4;
end

%% ── Reception energy ──────────────────────────────────────────────────────
% Reception cost is independent of distance
E_rx = L * params.E_elec;

end
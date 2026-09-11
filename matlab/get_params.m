function params = get_params()
% GET_PARAMS  Returns all CARHy-WSN simulation parameters
%   Edit this file to change any simulation setting.
%   All other functions read from this struct — never hardcode values.

%% ── Network ───────────────────────────────────────────────────────────────
params.N      = 100;     % number of sensor nodes
params.area   = 200;     % deployment area side length (m) — 200x200 m square

%% ── Energy model (first-order radio model, Heinzelman 2000) ──────────────
params.E_min      = 0.5e0;      % minimum initial energy (J)
params.E_max      = 2.0e0;      % maximum initial energy (J)
params.E_elec     = 50e-9;      % electronics energy (J/bit)
params.epsilon_fs = 10e-12;     % free-space amp energy (J/bit/m^2)
params.epsilon_mp = 0.0013e-12; % multipath amp energy (J/bit/m^4)
params.d0         = sqrt(params.epsilon_fs / params.epsilon_mp); % crossover distance
params.L          = 4000;       % packet size (bits)

%% ── EWMA link stability (adopt cited WMEWMA values) ─────────────────────
params.W       = 30;     % ACK window  (Woo & Culler)
params.ewma_a  = 0.5;    % smoothing   (Woo & Culler)



params.w_p = 0.4;   % relay progress weight (GEAR-style; swept)
params.w_e = 0.6;   % relay energy weight   (GEAR-style; swept)


%% ── Overhead / discovery ────────────────────────────────────────────────
params.T_update = 1;     % proactive table-broadcast interval (rounds)
params.T_route  = 5;     % AODV route-cache lifetime (rounds); RFC 3561 defines this parameter type (ACTIVE_ROUTE_TIMEOUT), value chosen for internal consistency (see T_full_dump, rpl_I_min)
params.T_full_dump = params.T_route;  % DSDV full-dump interval tied to the same
                                        % staleness-tolerance timescale as AODV/CARL-WSN's
                                        % route-cache lifetime (T_route), for internal
                                        % consistency across protocols rather than an
                                        % independently chosen constant

%% ── RPL (RFC 6550/6719/6206-grounded Trickle + MRHOF baseline) ──────────
params.rpl_I_min     = params.T_route;         % Trickle Imin (rounds); same internal
                                                 % consistency anchor as T_full_dump
params.rpl_doublings = 8;                       % Contiki-NG default [Oikonomou et al.,
                                                 % SoftwareX 2022]; RFC 6550's own
                                                 % suggested 20 is impractical at this
                                                 % I_min scale (see methodology notes)
params.rpl_I_max     = params.rpl_I_min * 2^params.rpl_doublings;  % = 1280 rounds
params.rpl_k         = 10;                      % RFC 6550's own official DIORedundancyConstant
params.rpl_hysteresis = 1.5;                    % RFC 6719 PARENT_SWITCH_THRESHOLD, in ETX units
%% ── Traffic classes ───────────────────────────────────────────────────────
% Class A: emergency — low latency critical
% Class B: periodic telemetry — energy efficient
% Class C: event-driven — best effort
params.lambda_A = 0.5;    % Class A arrival rate (packets/second)
params.lambda_B = 1/60;   % Class B arrival rate (packets/second) — 1/min
params.lambda_C = 0.1;    % Class C arrival rate (packets/second)

%% ── Context classifier thresholds ────────────────────────────────────────
params.T_E = 0.3;    % energy threshold: below this -> energy critical
params.T_L = 0.7;    % link stability threshold: below this -> unstable


%% ── Channel / link model (realistic PRR + ARQ) ─────────────────────────
params.comm_range  = 100;     % communication range (m)
params.ch_beta     = 90;      % PRR midpoint distance (m)  [Zuniga-Krishnamachari form]
params.ch_alpha    = 0.18;    % PRR transition sharpness
params.max_retx    = 3;       % ARQ attempts per hop       [IEEE 802.15.4 default]
params.max_hops    = 15;      % multi-hop loop guard
params.datarate    = 250e3;   % PHY data rate (bits/s)     [IEEE 802.15.4 O-QPSK]
params.t_proc_ms   = 1.0;     % per-hop processing delay (ms)
params.t_timeout_ms= 8.0;     % retransmission timeout (ms)


params.dsdv_entry_bits = 96;   % bits per DSDV routing-table entry
                               % (destination id + sequence no. + metric).
                               % Full-dump fragments = ceil(N_alive*entry_bits/L).
                               % Grounded in Perkins & Bhagwat full-dump structure; swept.

%% ── Routing ───────────────────────────────────────────────────────────────
% params.zone_radius = 2;   % LEGACY/UNUSED — ZRP's actual zone logic is
                              % hardcoded (energy-scaled 40/80/120m) directly
                              % in route_baseline.m; this parameter has no
                              % effect on any result in this study

%% ── Base station position ─────────────────────────────────────────────────
params.BS_x = 100;    % BS x-coordinate (centre of area)
params.BS_y = 100;    % BS y-coordinate (centre of area)
params.A    = 200;    % alias for area (used by baselines)
params.eps_fs = params.epsilon_fs;   % alias for baseline compatibility
params.eps_mp = params.epsilon_mp;   % alias for baseline compatibility

params.T_defer = 0.05;   % critical-node deferral threshold (swept)
% params.max_defer retired: deferral below T_defer is now unconditional and
% permanent for the remainder of the node's life, since energy is strictly
% non-increasing (Eq. 3, no harvesting) — a forced-retransmit escape valve
% cannot restore a node above T_defer once crossed, so it served no
% physically meaningful purpose. See context_classifier_rl.m.
params.cluster_overhead_mode = 'tdma';   % 'recluster' or 'tdma' (clustering overhead model)

%% ── Control-packet sizes (RFC 3561 / RFC 6550 verified) ────────────────────
params.L_RREQ = 24*8;    % RREQ size, bits (RFC 3561 Section 5.1: 24 bytes)
params.L_RREP = 20*8;    % RREP size, bits (RFC 3561 Section 5.2: 20 bytes)
params.L_ctrl = 20*8;    % Generic beacon/control packet, bits (RFC 3561 Section 6.9 Hello-message convention)

%% ── Simulation ────────────────────────────────────────────────────────────
params.rounds     = 2000;   % total simulation rounds
params.seed       = 42;     % random seed for reproducibility
                            % change to 43,44,45,46 for 5 independent runs

%% ── Output ────────────────────────────────────────────────────────────────
params.save_results = true;
params.results_dir  = '..\results\';   % relative path to results folder

%% ── Q-Learning hyperparameters (swept for grid search) ──────────────────
params.alpha_lr      = 0.1;     % learning rate
params.gamma_df       = 0.9;    % discount factor
params.epsilon0       = 0.1;    % initial exploration rate
params.epsilon_decay  = 0.998;  % decay per round
params.epsilon_min    = 0.01;   % minimum exploration

fprintf('Parameters loaded: N=%d, area=%dx%d m, rounds=%d\n', ...
        params.N, params.area, params.area, params.rounds);
end
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


%% ── Overhead / discovery ────────────────────────────────────────────────
params.T_update = 1;     % proactive table-broadcast interval (rounds)
params.T_route  = 5;     % AODV route-cache lifetime (rounds); grounded in AODV RFC, swept

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


%% ── Routing ───────────────────────────────────────────────────────────────
params.zone_radius = 2;   % ZRP zone radius (hops) — base value for hybrid mode

%% ── Base station position ─────────────────────────────────────────────────
params.BS_x = 100;    % BS x-coordinate (centre of area)
params.BS_y = 100;    % BS y-coordinate (centre of area)
params.A    = 200;    % alias for area (used by baselines)
params.eps_fs = params.epsilon_fs;   % alias for baseline compatibility
params.eps_mp = params.epsilon_mp;   % alias for baseline compatibility

%% ── Simulation ────────────────────────────────────────────────────────────
params.rounds     = 2000;   % total simulation rounds
params.seed       = 42;     % random seed for reproducibility
                            % change to 43,44,45,46 for 5 independent runs

%% ── Output ────────────────────────────────────────────────────────────────
params.save_results = true;
params.results_dir  = '..\results\';   % relative path to results folder

fprintf('Parameters loaded: N=%d, area=%dx%d m, rounds=%d\n', ...
        params.N, params.area, params.area, params.rounds);
end
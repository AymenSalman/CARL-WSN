function net = init_network(params)
% INIT_NETWORK  Deploy WSN nodes and initialise all network state
%   net = init_network(params) returns a struct containing all node
%   positions, energy levels, and initial state for the CARHy-WSN
%   simulation.
%
%   Input:
%     params  - configuration struct from get_params()
%
%   Output:
%     net     - network struct with fields:
%                 x, y        : node positions (1 x N)
%                 energy      : current energy (1 x N) in Joules
%                 E0          : initial energy (1 x N) in Joules
%                 alive       : logical alive/dead flag (1 x N)
%                 L_s         : link stability score (1 x N), init = 1.0
%                 class_count : packets sent per class [A B C] (1 x 3)
%                 round       : current simulation round
%                 FND         : first node death round (0 = not yet)
%                 HND         : half node death round (0 = not yet)

rng(params.seed);   % reproducible random placement

N  = params.N;      % number of sensor nodes
A  = params.area;   % side length of square deployment area (m)

%% ── Node positions (uniform random inside A x A square) ──────────────────
net.x = rand(1, N) .* A;
net.y = rand(1, N) .* A;

%% ── Heterogeneous initial energy (Uniform between E_min and E_max) ───────
net.E0     = params.E_min + rand(1, N) .* (params.E_max - params.E_min);
net.energy = net.E0;          % current energy starts at initial energy

%% ── Node state ────────────────────────────────────────────────────────────
net.alive       = true(1, N);        % all nodes alive at start
net.L_s         = ones(1, N);        % link stability = 1.0 (perfect) at start
net.ack_history = ones(params.W, N);   % was ones(10,N) — now W=30
net.LND         = 0;                   % last node death (run-to-death horizon)
net.cluster_ctrl = 0;   % accumulated clustering control packets (RLCR/FQ-UCR)
net.cluster_ctrl_tdma = 0;
net.route_age   = zeros(1, N);         % AODV/ZRP route cache age

%% ── Base station and sink positions ──────────────────────────────────────
% Base station at centre of area
net.BS  = [params.area/2, params.area/2];

% Sink at right edge (consistent with IJSER 2023 multi-sink topology)
net.sink = [params.area, params.area/2];

%% ── Traffic class counters ────────────────────────────────────────────────
net.class_count = zeros(1, 3);   % [Class_A  Class_B  Class_C] packets sent

%% ── Simulation state ──────────────────────────────────────────────────────
net.round = 0;
net.FND   = 0;   % first node death round (0 = not reached yet)
net.HND   = 0;   % half node death round  (0 = not reached yet)

%% ── Routing tables (empty at start — filled by each protocol) ─────────────
net.route_table = zeros(N, N);   % next-hop table: route_table(i,j) = next hop from i to j

net.defer_count = zeros(1, params.N);   % consecutive-deferral counter per node


%% ── Metrics storage (pre-allocated for speed) ────────────────────────────
R = params.rounds;
net.metrics.alive_per_round    = zeros(1, R);
net.metrics.energy_per_round   = zeros(1, R);
net.metrics.pdr_per_round      = zeros(1, R);
net.metrics.latency_A          = [];    % grows dynamically
net.metrics.delivered          = 0;
net.metrics.total_sent         = 0;

%fprintf('Network initialised: %d nodes, area %.0fx%.0f m\n', N, A, A);
%fprintf('Energy range: %.2f J to %.2f J\n', params.E_min, params.E_max);
%fprintf('BS at (%.0f, %.0f), Sink at (%.0f, %.0f)\n', ...
%        net.BS(1), net.BS(2), net.sink(1), net.sink(2));
end
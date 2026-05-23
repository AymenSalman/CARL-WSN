%% GENERATE_ALIVE_NODES_FIGURE.M
%  Enhancement-1: Alive nodes over time for all 6 protocols
%  Run from: D:\Aymen Research Repo\CARHy_WSN_Paper\matlab\
%  Output:   ..\figures\fig7_alive_nodes.pdf
%
%  IMPORTANT: This script requires a small modification to
%  run_single_simulation.m — see Step 0 below.
%  
%  Estimated time: ~5 minutes (6 protocols × 5 seeds × 2000 rounds)

clc; clear; close all;
fprintf('=== Generating Alive-Nodes-Over-Time Figure ===\n\n');

%% ── Step 0: MODIFICATION REQUIRED ────────────────────────────────────────
%  Before running this script, add these lines to run_single_simulation.m:
%
%  (a) BEFORE the main simulation loop (after network initialisation):
%      alive_per_round = zeros(1, params.rounds);
%
%  (b) INSIDE the main loop, at the END of each round (after check_dead_nodes):
%      alive_per_round(round) = sum(net.energy > 0);
%
%  (c) ADD to the metrics struct at the end of run_single_simulation:
%      metrics.alive_per_round = alive_per_round;
%
%  If you already have alive_per_round tracked, skip this step.
%  ─────────────────────────────────────────────────────────────────────────

%% ── Configuration ─────────────────────────────────────────────────────────
params    = get_params();
protocols = {'CARHy', 'AODV', 'DSDV', 'ZRP', 'EH_Routing', 'MSLBA'};
seeds     = [42, 43, 44, 45, 46];
scenario  = 'Mixed';

n_proto = length(protocols);
n_seeds = length(seeds);
rounds  = params.rounds;  % should be 2000

% Storage: alive_all(protocol, round) — averaged over seeds
alive_all = zeros(n_proto, rounds);

%% ── Run simulations ──────────────────────────────────────────────────────
for p = 1:n_proto
    alive_seeds = zeros(n_seeds, rounds);
    for k = 1:n_seeds
        params.seed = seeds(k);
        fprintf('  Running %-12s seed=%d ... ', protocols{p}, seeds(k));
        
        metrics = run_single_simulation(params, protocols{p}, scenario);
        
        % Retrieve alive_per_round from metrics
        alive_seeds(k, :) = metrics.alive_per_round;
        
        fprintf('FND=%d\n', metrics.FND);
    end
    alive_all(p, :) = mean(alive_seeds, 1);
end

%% ── Plot ─────────────────────────────────────────────────────────────────
fig = figure('Visible', 'off', 'Position', [100 100 700 420]);

% Protocol display names and colours (matching your existing figures)
display_names = {'CARHy-WSN', 'AODV', 'DSDV', 'ZRP', 'EH-Routing', 'MSLBA'};
colors = [
    0.2000  0.4000  0.8000;   % CARHy  — blue
    0.2660  0.6740  0.1880;   % AODV   — green
    0.8500  0.1000  0.1000;   % DSDV   — red
    1.0000  0.6000  0.0000;   % ZRP    — orange
    0.5000  0.0000  0.8000;   % EH-Routing — purple
    0.6500  0.4500  0.2000;   % MSLBA  — brown
];
line_styles = {'-', '--', '-.', ':', '-', '--'};
line_widths = [2.0, 1.5, 1.5, 1.5, 1.5, 1.5];

hold on;
for p = 1:n_proto
    plot(1:rounds, alive_all(p,:), ...
        'Color', colors(p,:), ...
        'LineStyle', line_styles{p}, ...
        'LineWidth', line_widths(p), ...
        'DisplayName', display_names{p});
end
hold off;

xlabel('Round', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Number of Alive Nodes', 'FontSize', 12, 'FontWeight', 'bold');
title('Network Lifetime — Alive Nodes Over Time', 'FontSize', 14, 'FontWeight', 'bold');
legend('Location', 'northeast', 'FontSize', 10);
grid on;
xlim([1 rounds]);
ylim([0 params.N + 5]);
set(gca, 'FontSize', 11);

%% ── Export ────────────────────────────────────────────────────────────────
outdir = fullfile('..', 'figures');
if ~exist(outdir, 'dir'), mkdir(outdir); end
outpath = fullfile(outdir, 'fig7_alive_nodes.pdf');
exportgraphics(fig, outpath, 'ContentType', 'vector');
fprintf('\n  Saved: %s\n', outpath);

% Also save the raw data for reference
save(fullfile(outdir, 'alive_nodes_data.mat'), ...
     'alive_all', 'protocols', 'rounds', 'seeds');
fprintf('  Data saved: alive_nodes_data.mat\n');
fprintf('\nDone.\n');

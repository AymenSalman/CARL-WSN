%% RUN_ALL_ENHANCEMENTS.M
%  Master script: runs all MATLAB enhancements in order
%  Run from: D:\Aymen Research Repo\CARHy_WSN_Paper\matlab\
%
%  BEFORE running this, complete the two modifications below.
%
%  Outputs:
%    ..\figures\fig_topology.pdf          — network topology (Enhancement A)
%    ..\figures\fig7_alive_nodes.pdf      — alive nodes over time (Enhancement 1)
%    ..\figures\fig8_sensitivity_heatmap.pdf — threshold sensitivity (Enhancement 2)
%    ..\figures\tab_sensitivity.csv       — sensitivity data for LaTeX table
%    ..\figures\alive_nodes_data.mat      — raw alive-nodes data
%    ..\figures\sensitivity_data.mat      — raw sensitivity data
%
%  Estimated total time: ~20 minutes on Lenovo

%% ═══════════════════════════════════════════════════════════════════════════
%  REQUIRED MODIFICATIONS (do these BEFORE running)
%  ═══════════════════════════════════════════════════════════════════════════
%
%  ──────────────────────────────────────────────────────────────────────────
%  MODIFICATION 1: run_single_simulation.m — track alive nodes per round
%  ──────────────────────────────────────────────────────────────────────────
%
%  Open run_single_simulation.m and make these 3 changes:
%
%  (a) AFTER the line that initialises the network (after rng(params.seed)
%      and net = init_network(params) or similar), ADD:
%
%        alive_per_round = zeros(1, params.rounds);
%
%  (b) INSIDE the main for-loop, at the END of each round iteration
%      (after check_dead_nodes or energy updates), ADD:
%
%        alive_per_round(round) = sum(net.energy > 0);
%
%  (c) At the end of the function, where you build the metrics struct,
%      ADD this field:
%
%        metrics.alive_per_round = alive_per_round;
%
%  ──────────────────────────────────────────────────────────────────────────
%  MODIFICATION 2: Verify T_E and T_L are NOT hardcoded
%  ──────────────────────────────────────────────────────────────────────────
%
%  Search your routing code (route_carhy.m or the CARHy section inside
%  run_single_simulation.m) for any line like:
%
%      if E_r < 0.3      ← CHANGE TO:  if E_r < params.T_E
%      if L_s < 0.7      ← CHANGE TO:  if L_s < params.T_L
%
%  If your code already uses params.T_E and params.T_L, no change needed.
%
%  ══════════════════════════════════════════════════════════════════════════

clc; clear; close all;
fprintf('╔══════════════════════════════════════════════════╗\n');
fprintf('║  CARHy-WSN Paper Enhancement Runner             ║\n');
fprintf('║  %s                               ║\n', datestr(now, 'yyyy-mm-dd HH:MM'));
fprintf('╚══════════════════════════════════════════════════╝\n\n');

%% ── Task 1: Network Topology (quickest — no simulation needed) ────────────
fprintf('━━━ Task 1/3: Network Topology Figure ━━━\n');
generate_topology_figure;
fprintf('\n');

%% ── Task 2: Alive Nodes Figure (~5 min) ──────────────────────────────────
fprintf('━━━ Task 2/3: Alive Nodes Over Time ━━━\n');
generate_alive_nodes_figure;
fprintf('\n');

%% ── Task 3: Threshold Sensitivity (~15 min) ──────────────────────────────
fprintf('━━━ Task 3/3: Threshold Sensitivity Analysis ━━━\n');
run_sensitivity_analysis;
fprintf('\n');

%% ── Summary ──────────────────────────────────────────────────────────────
fprintf('╔══════════════════════════════════════════════════╗\n');
fprintf('║  ALL ENHANCEMENTS COMPLETE                      ║\n');
fprintf('╚══════════════════════════════════════════════════╝\n\n');
fprintf('Generated files:\n');
figdir = fullfile('..', 'figures');
fprintf('  1. %s\n', fullfile(figdir, 'fig_topology.pdf'));
fprintf('  2. %s\n', fullfile(figdir, 'fig7_alive_nodes.pdf'));
fprintf('  3. %s\n', fullfile(figdir, 'fig8_sensitivity_heatmap.pdf'));
fprintf('  4. %s\n', fullfile(figdir, 'tab_sensitivity.csv'));
fprintf('\nCopy these to your MacBook figures folder, then\n');
fprintf('send me the tab_sensitivity.csv output so I can\n');
fprintf('build the LaTeX table.\n');

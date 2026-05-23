%% GENERATE_TOPOLOGY_FIGURE.M
%  New Enhancement A: Network deployment topology figure
%  Run from: D:\Aymen Research Repo\CARHy_WSN_Paper\matlab\
%  Output:   ..\figures\fig_topology.pdf
%
%  Shows: 200×200m area, 100 nodes (colour-coded by initial energy),
%         BS at (100,100), secondary sink at (200,100),
%         transmission range circle around one sample node.
%
%  Uses seed=42 for reproducible node placement.
%  Estimated time: <1 minute

clc; clear; close all;
fprintf('=== Generating Network Topology Figure ===\n\n');

%% ── Parameters (must match get_params) ────────────────────────────────────
N      = 100;       % number of sensor nodes
A      = 200;       % area side length (m)
Emin   = 0.5;       % min initial energy (J)
Emax   = 2.0;       % max initial energy (J)
R_tx   = 200;       % max transmission range (m) — from your simulation
BS     = [100, 100]; % base station position
Sink2  = [200, 100]; % secondary sink position
seed   = 42;

%% ── Generate node positions (same seed as simulation) ────────────────────
rng(seed);
node_x  = rand(1, N) * A;
node_y  = rand(1, N) * A;
node_E0 = Emin + rand(1, N) * (Emax - Emin);  % heterogeneous energy

%% ── Plot ─────────────────────────────────────────────────────────────────
fig = figure('Visible', 'off', 'Position', [100 100 600 550]);

% Plot deployment boundary
rectangle('Position', [0 0 A A], 'EdgeColor', [0.5 0.5 0.5], ...
          'LineWidth', 1.5, 'LineStyle', '--', 'HandleVisibility', 'off');
hold on;

% Plot sensor nodes — colour by initial energy
scatter(node_x, node_y, 40, node_E0, 'filled', 'MarkerEdgeColor', [0.3 0.3 0.3], ...
        'LineWidth', 0.5);
cb = colorbar;
cb.Label.String = 'Initial Energy E_0 (J)';
cb.Label.FontSize = 11;
colormap(parula);
clim([Emin Emax]);

% Plot BS (large red star)
plot(BS(1), BS(2), 'p', 'MarkerSize', 22, 'MarkerFaceColor', [0.85 0.1 0.1], ...
     'MarkerEdgeColor', 'k', 'LineWidth', 1.2);

% Plot secondary sink (large blue diamond)
plot(Sink2(1), Sink2(2), 'd', 'MarkerSize', 16, 'MarkerFaceColor', [0.1 0.3 0.8], ...
     'MarkerEdgeColor', 'k', 'LineWidth', 1.2);

% Show transmission range circle around one example node (node 1)
theta = linspace(0, 2*pi, 100);
tx_range_display = 100;
plot(BS(1) + tx_range_display * cos(theta), ...
     BS(2) + tx_range_display * sin(theta), ...
     'Color', [0.3 0.7 0.3 0.5], 'LineWidth', 1.5, 'LineStyle', '-.');

% Labels
text(BS(1), BS(2) - 12, 'BS', 'HorizontalAlignment', 'center', ...
     'FontSize', 10, 'FontWeight', 'bold', 'Color', [0.85 0.1 0.1]);
text(Sink2(1) - 12, Sink2(2) - 12, 'Sink_2', 'HorizontalAlignment', 'center', ...
     'FontSize', 10, 'FontWeight', 'bold', 'Color', [0.1 0.3 0.8], ...
     'Interpreter', 'tex');

hold off;

xlabel('X Position (m)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Y Position (m)', 'FontSize', 12, 'FontWeight', 'bold');
title('Network Deployment Topology (N = 100)', 'FontSize', 14, 'FontWeight', 'bold');
legend({'Sensor Nodes', 'Base Station (BS)', 'Secondary Sink', 'Communication Range (100m)'}, ...
       'Location', 'southwest', 'FontSize', 9);
axis equal;
xlim([-10 215]);
ylim([-10 215]);
grid on;
set(gca, 'FontSize', 11);

%% ── Export ────────────────────────────────────────────────────────────────
outdir = fullfile('..', 'figures');
if ~exist(outdir, 'dir'), mkdir(outdir); end

outpath = fullfile(outdir, 'fig_topology.pdf');
exportgraphics(fig, outpath, 'ContentType', 'vector');
fprintf('  Saved: %s\n', outpath);
fprintf('\nDone.\n');

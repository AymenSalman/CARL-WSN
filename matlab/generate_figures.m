function generate_figures(results_mean, results_std, protocols, scenarios)
% GENERATE_FIGURES  Creates all paper figures as vector PDF files
%   Saves to ..\figures\ folder

figures_dir = '..\figures\';
if ~exist(figures_dir, 'dir')
    mkdir(figures_dir);
end

colors = {[0.12 0.47 0.71], [0.20 0.63 0.17], [0.89 0.10 0.11], ...
          [1.00 0.50 0.05], [0.42 0.24 0.60], [0.65 0.34 0.16]};

n_proto = length(protocols);
x_pos   = 1:n_proto;

%% ── Figure 1: Network Lifetime (FND) across scenarios ────────────────────
fig1 = figure('Visible','off','Position',[100 100 700 420]);
scen_idx = 4;   % Mixed traffic scenario
FND_vals = squeeze(results_mean(:, scen_idx, 1));
FND_err  = squeeze(results_std(:,  scen_idx, 1));

b = bar(x_pos, FND_vals, 0.6, 'FaceColor','flat');
for i = 1:n_proto
    b.CData(i,:) = colors{i};
end
hold on;
errorbar(x_pos, FND_vals, FND_err, 'k.', 'LineWidth', 1.2);
set(gca, 'XTick', x_pos, 'XTickLabel', protocols, 'FontSize', 11);
ylabel('First Node Death Round', 'FontSize', 12);
title('Network Lifetime — Mixed Traffic Scenario', 'FontSize', 13);
grid on; box off;
exportgraphics(fig1, fullfile(figures_dir,'fig1_lifetime_FND.pdf'), ...
               'ContentType','vector');
fprintf('Saved: fig1_lifetime_FND.pdf\n');
close(fig1);

%% ── Figure 2: Class A Emergency Latency comparison ───────────────────────
fig2 = figure('Visible','off','Position',[100 100 700 420]);
LatA_vals = squeeze(results_mean(:, scen_idx, 4));
LatA_err  = squeeze(results_std(:,  scen_idx, 4));

b2 = bar(x_pos, LatA_vals, 0.6, 'FaceColor','flat');
for i = 1:n_proto
    b2.CData(i,:) = colors{i};
end
hold on;
errorbar(x_pos, LatA_vals, LatA_err, 'k.', 'LineWidth', 1.2);
yline(100, '--r', 'Latency threshold (100ms)', 'FontSize', 10);
set(gca, 'XTick', x_pos, 'XTickLabel', protocols, 'FontSize', 11);
ylabel('Mean Latency (ms)', 'FontSize', 12);
title('Class A Emergency Packet Latency', 'FontSize', 13);
grid on; box off;
exportgraphics(fig2, fullfile(figures_dir,'fig2_latency_classA.pdf'), ...
               'ContentType','vector');
fprintf('Saved: fig2_latency_classA.pdf\n');
close(fig2);

%% ── Figure 3: PDR under all four traffic scenarios ───────────────────────
fig3 = figure('Visible','off','Position',[100 100 750 450]);
PDR_all = squeeze(results_mean(:,:,3)) * 100;   % convert to %
b3 = bar(PDR_all', 0.8);
for i = 1:n_proto
    b3(i).FaceColor = colors{i};
end
set(gca, 'XTick', 1:4, 'XTickLabel', scenarios, 'FontSize', 11);
ylabel('Packet Delivery Ratio (%)', 'FontSize', 12);
title('PDR across Traffic Scenarios', 'FontSize', 13);
legend(protocols, 'Location','southeast', 'FontSize', 9);
ylim([0 110]);
grid on; box off;
exportgraphics(fig3, fullfile(figures_dir,'fig3_PDR_scenarios.pdf'), ...
               'ContentType','vector');
fprintf('Saved: fig3_PDR_scenarios.pdf\n');
close(fig3);

%% ── Figure 4: Energy Balance (Gini coefficient) ─────────────────────────
fig4 = figure('Visible','off','Position',[100 100 700 420]);
Gini_vals = squeeze(results_mean(:, scen_idx, 6));
Gini_err  = squeeze(results_std(:,  scen_idx, 6));

b4 = bar(x_pos, Gini_vals, 0.6, 'FaceColor','flat');
for i = 1:n_proto
    b4.CData(i,:) = colors{i};
end
hold on;
errorbar(x_pos, Gini_vals, Gini_err, 'k.', 'LineWidth', 1.2);
set(gca, 'XTick', x_pos, 'XTickLabel', protocols, 'FontSize', 11);
ylabel('Gini Coefficient (lower = more balanced)', 'FontSize', 12);
title('Energy Balance across Protocols', 'FontSize', 13);
grid on; box off;
exportgraphics(fig4, fullfile(figures_dir,'fig4_energy_gini.pdf'), ...
               'ContentType','vector');
fprintf('Saved: fig4_energy_gini.pdf\n');
close(fig4);

%% ── Figure 5: Routing Overhead ───────────────────────────────────────────
fig5 = figure('Visible','off','Position',[100 100 700 420]);
OH_vals = squeeze(results_mean(:, scen_idx, 7));
OH_err  = squeeze(results_std(:,  scen_idx, 7));

b5 = bar(x_pos, OH_vals, 0.6, 'FaceColor','flat');
for i = 1:n_proto
    b5.CData(i,:) = colors{i};
end
hold on;
errorbar(x_pos, OH_vals, OH_err, 'k.', 'LineWidth', 1.2);
set(gca, 'XTick', x_pos, 'XTickLabel', protocols, 'FontSize', 11);
ylabel('Control Packets per Data Packet', 'FontSize', 12);
title('Routing Overhead Comparison', 'FontSize', 13);
grid on; box off;
exportgraphics(fig5, fullfile(figures_dir,'fig5_routing_overhead.pdf'), ...
               'ContentType','vector');
fprintf('Saved: fig5_routing_overhead.pdf\n');
close(fig5);

%% ── Figure 6: Throughput comparison ─────────────────────────────────────
fig6 = figure('Visible','off','Position',[100 100 700 420]);
TP_vals = squeeze(results_mean(:, scen_idx, 8));
TP_err  = squeeze(results_std(:,  scen_idx, 8));

b6 = bar(x_pos, TP_vals, 0.6, 'FaceColor','flat');
for i = 1:n_proto
    b6.CData(i,:) = colors{i};
end
hold on;
errorbar(x_pos, TP_vals, TP_err, 'k.', 'LineWidth', 1.2);
set(gca, 'XTick', x_pos, 'XTickLabel', protocols, 'FontSize', 11);
ylabel('Packets Delivered per Round', 'FontSize', 12);
title('Network Throughput — Mixed Traffic', 'FontSize', 13);
grid on; box off;
exportgraphics(fig6, fullfile(figures_dir,'fig6_throughput.pdf'), ...
               'ContentType','vector');
fprintf('Saved: fig6_throughput.pdf\n');
close(fig6);

%% ── Figure 7: Alive nodes over time (CARHy vs best baseline) ────────────
% This needs raw per-round data — placeholder for now
fprintf('Note: fig7 (alive over time) requires per-round raw data.\n');
fprintf('      Run with params.save_raw=true to enable.\n');

fprintf('\nAll figures saved to %s\n', figures_dir);
end
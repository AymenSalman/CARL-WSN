%% RUN_SENSITIVITY_ANALYSIS.M
%  Enhancement-2: T_E × T_L threshold sensitivity analysis
%  Run from: D:\Aymen Research Repo\CARHy_WSN_Paper\matlab\
%  Output:   ..\figures\tab_sensitivity.csv  (for LaTeX table)
%            ..\figures\fig8_sensitivity_heatmap.pdf
%
%  Tests 9 threshold combinations: T_E ∈ {0.2, 0.3, 0.4} × T_L ∈ {0.6, 0.7, 0.8}
%  Only CARHy-WSN is re-run (baselines don't use thresholds)
%  
%  IMPORTANT: get_params() must accept overrides for T_E and T_L.
%  See Step 0 below.
%
%  Estimated time: 9 × 5 seeds = 45 runs (~15 minutes on Lenovo)

clc; clear; close all;
fprintf('=== Threshold Sensitivity Analysis ===\n\n');

%% ── Step 0: MODIFICATION REQUIRED ────────────────────────────────────────
%  Your get_params() sets params.T_E = 0.3 and params.T_L = 0.7.
%  This script overrides those values AFTER calling get_params().
%  Make sure run_single_simulation() reads T_E and T_L from params
%  (i.e., uses params.T_E and params.T_L, not hardcoded 0.3 and 0.7).
%
%  Check your route_carhy.m or similar function — if it has:
%      if E_r < 0.3   ← HARDCODED, must change to params.T_E
%      if L_s < 0.7   ← HARDCODED, must change to params.T_L
%  ─────────────────────────────────────────────────────────────────────────

%% ── Configuration ─────────────────────────────────────────────────────────
T_E_values = [0.2, 0.3, 0.4];
T_L_values = [0.6, 0.7, 0.8];
seeds      = [42, 43, 44, 45, 46];
scenario   = 'Mixed';

n_TE    = length(T_E_values);
n_TL    = length(T_L_values);
n_seeds = length(seeds);

% Storage matrices (for heatmaps)
LatA_grid = zeros(n_TE, n_TL);
OH_grid   = zeros(n_TE, n_TL);
FND_grid  = zeros(n_TE, n_TL);
HND_grid  = zeros(n_TE, n_TL);

% Also store std for the table
LatA_std_grid = zeros(n_TE, n_TL);
OH_std_grid   = zeros(n_TE, n_TL);

total_runs = n_TE * n_TL * n_seeds;
run_count  = 0;

%% ── Run sensitivity sweep ────────────────────────────────────────────────
for i = 1:n_TE
    for j = 1:n_TL
        params      = get_params();       % reset to defaults each time
        params.T_E  = T_E_values(i);      % override energy threshold
        params.T_L  = T_L_values(j);      % override link stability threshold
        
        lat_seeds = zeros(1, n_seeds);
        oh_seeds  = zeros(1, n_seeds);
        fnd_seeds = zeros(1, n_seeds);
        hnd_seeds = zeros(1, n_seeds);
        
        for k = 1:n_seeds
            run_count = run_count + 1;
            params.seed = seeds(k);
            
            fprintf('[%2d/%d] T_E=%.1f  T_L=%.1f  seed=%d ... ', ...
                    run_count, total_runs, T_E_values(i), T_L_values(j), seeds(k));
            
            metrics = run_single_simulation(params, 'CARHy', scenario);
            
            lat_seeds(k) = metrics.LatA;
            oh_seeds(k)  = metrics.Overhead;
            fnd_seeds(k) = metrics.FND;
            hnd_seeds(k) = metrics.HND;
            
            fprintf('LatA=%.1fms  OH=%.3f  FND=%d\n', ...
                    metrics.LatA, metrics.Overhead, metrics.FND);
        end
        
        LatA_grid(i,j)     = mean(lat_seeds);
        OH_grid(i,j)       = mean(oh_seeds);
        FND_grid(i,j)      = mean(fnd_seeds);
        HND_grid(i,j)      = mean(hnd_seeds);
        LatA_std_grid(i,j)  = std(lat_seeds);
        OH_std_grid(i,j)    = std(oh_seeds);
    end
end

%% ── Print results table ──────────────────────────────────────────────────
fprintf('\n=== SENSITIVITY RESULTS ===\n\n');
fprintf('%-6s %-6s %10s %10s %10s %10s\n', ...
        'T_E', 'T_L', 'LatA(ms)', 'OH', 'FND', 'HND');
fprintf('%s\n', repmat('-', 1, 54));
for i = 1:n_TE
    for j = 1:n_TL
        fprintf('%-6.1f %-6.1f %10.2f %10.3f %10.1f %10.1f\n', ...
                T_E_values(i), T_L_values(j), ...
                LatA_grid(i,j), OH_grid(i,j), ...
                FND_grid(i,j), HND_grid(i,j));
    end
end

% Compute improvement percentages vs AODV (latency) and DSDV (overhead)
% AODV LatA = 100.0 ms, DSDV OH = 6.27 (from your Mixed results)
AODV_LatA = 100.0;
DSDV_OH   = 6.266;  % from CSV

fprintf('\n=== IMPROVEMENT PERCENTAGES ===\n\n');
fprintf('%-6s %-6s %12s %12s\n', ...
        'T_E', 'T_L', 'Lat%vsAODV', 'OH%vsDSDV');
fprintf('%s\n', repmat('-', 1, 40));
for i = 1:n_TE
    for j = 1:n_TL
        lat_pct = (AODV_LatA - LatA_grid(i,j)) / AODV_LatA * 100;
        oh_pct  = (DSDV_OH   - OH_grid(i,j))   / DSDV_OH   * 100;
        fprintf('%-6.1f %-6.1f %11.1f%% %11.1f%%\n', ...
                T_E_values(i), T_L_values(j), lat_pct, oh_pct);
    end
end

%% ── Save CSV for LaTeX table ─────────────────────────────────────────────
outdir = fullfile('..', 'figures');
if ~exist(outdir, 'dir'), mkdir(outdir); end

fid = fopen(fullfile(outdir, 'tab_sensitivity.csv'), 'w');
fprintf(fid, 'T_E,T_L,LatA_mean,LatA_std,OH_mean,OH_std,FND_mean,HND_mean\n');
for i = 1:n_TE
    for j = 1:n_TL
        fprintf(fid, '%.1f,%.1f,%.4f,%.4f,%.4f,%.4f,%.1f,%.1f\n', ...
                T_E_values(i), T_L_values(j), ...
                LatA_grid(i,j), LatA_std_grid(i,j), ...
                OH_grid(i,j), OH_std_grid(i,j), ...
                FND_grid(i,j), HND_grid(i,j));
    end
end
fclose(fid);
fprintf('\n  CSV saved: %s\n', fullfile(outdir, 'tab_sensitivity.csv'));

%% ── Generate heatmap figure ──────────────────────────────────────────────
fig = figure('Visible', 'off', 'Position', [100 100 900 380]);

% ── Subplot 1: Latency heatmap ──
subplot(1, 2, 1);
imagesc(LatA_grid);
colormap(subplot(1,2,1), flipud(summer));
colorbar;
set(gca, 'XTick', 1:n_TL, 'XTickLabel', arrayfun(@(x) sprintf('%.1f',x), T_L_values, 'UniformOutput', false));
set(gca, 'YTick', 1:n_TE, 'YTickLabel', arrayfun(@(x) sprintf('%.1f',x), T_E_values, 'UniformOutput', false));
xlabel('T_L (Link Stability Threshold)', 'FontSize', 11, 'FontWeight', 'bold');
ylabel('T_E (Energy Threshold)', 'FontSize', 11, 'FontWeight', 'bold');
title('Mean Class A Latency (ms)', 'FontSize', 12, 'FontWeight', 'bold');
% Add value labels on cells
for i = 1:n_TE
    for j = 1:n_TL
        text(j, i, sprintf('%.1f', LatA_grid(i,j)), ...
             'HorizontalAlignment', 'center', 'FontSize', 11, 'FontWeight', 'bold');
    end
end
set(gca, 'FontSize', 11);

% ── Subplot 2: Overhead heatmap ──
subplot(1, 2, 2);
imagesc(OH_grid);
colormap(subplot(1,2,2), flipud(summer));
colorbar;
set(gca, 'XTick', 1:n_TL, 'XTickLabel', arrayfun(@(x) sprintf('%.1f',x), T_L_values, 'UniformOutput', false));
set(gca, 'YTick', 1:n_TE, 'YTickLabel', arrayfun(@(x) sprintf('%.1f',x), T_E_values, 'UniformOutput', false));
xlabel('T_L (Link Stability Threshold)', 'FontSize', 11, 'FontWeight', 'bold');
ylabel('T_E (Energy Threshold)', 'FontSize', 11, 'FontWeight', 'bold');
title('Routing Overhead', 'FontSize', 12, 'FontWeight', 'bold');
% Add value labels on cells
for i = 1:n_TE
    for j = 1:n_TL
        text(j, i, sprintf('%.2f', OH_grid(i,j)), ...
             'HorizontalAlignment', 'center', 'FontSize', 11, 'FontWeight', 'bold');
    end
end
set(gca, 'FontSize', 11);

sgtitle('CARHy-WSN Threshold Sensitivity Analysis', 'FontSize', 14, 'FontWeight', 'bold');

outpath = fullfile(outdir, 'fig8_sensitivity_heatmap.pdf');
exportgraphics(fig, outpath, 'ContentType', 'vector');
fprintf('  Heatmap saved: %s\n', outpath);

%% ── Save workspace ───────────────────────────────────────────────────────
save(fullfile(outdir, 'sensitivity_data.mat'), ...
     'T_E_values', 'T_L_values', ...
     'LatA_grid', 'OH_grid', 'FND_grid', 'HND_grid', ...
     'LatA_std_grid', 'OH_std_grid');
fprintf('  Data saved: sensitivity_data.mat\n');
fprintf('\nDone.\n');

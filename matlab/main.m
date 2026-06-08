%% MAIN.M  CARHy-WSN Simulation Runner
%  Runs all 6 protocols across 4 traffic scenarios x 5 seeds
%  Collects all 8 metrics and exports results to CSV
%  Generates all paper figures as vector PDF
%
%  Usage: Run this file. Results saved to ..\results\
%  Estimated time: ~30-60 minutes (use parfor for speed)

clc; clear; close all;
fprintf('========================================\n');
fprintf('  CARHy-WSN Simulation Starting\n');
fprintf('  %s\n', datestr(now));
fprintf('========================================\n\n');

%% ── Configuration ─────────────────────────────────────────────────────────
params = get_params();

protocols = {'CARHy_RL', 'AODV', 'DSDV', 'ZRP', 'EH_Routing', 'MSLBA', 'RLCR', 'FQ_UCR'};
scenarios = {'ClassA', 'ClassB', 'ClassC', 'Mixed'};
seeds     = [42, 43, 44, 45, 46];   % 5 independent runs

n_proto = length(protocols);
n_scen  = length(scenarios);
n_seeds = length(seeds);

% Results storage: [protocol x scenario x seed x metric]
% Metrics: FND, HND, PDR, LatA, AvgEnergy, Gini, Overhead, Throughput
n_metrics = 8;
results = zeros(n_proto, n_scen, n_seeds, n_metrics);

fprintf('Running %d protocols x %d scenarios x %d seeds = %d total runs\n\n', ...
        n_proto, n_scen, n_seeds, n_proto*n_scen*n_seeds);

%% ── Main simulation loop ──────────────────────────────────────────────────
total_runs = n_proto * n_scen * n_seeds;
run_count  = 0;

for p = 1:n_proto
    for s = 1:n_scen
        for k = 1:n_seeds

            run_count = run_count + 1;
            params.seed = seeds(k);

            fprintf('[%3d/%d] Protocol=%-12s Scenario=%-8s Seed=%d ... ', ...
                    run_count, total_runs, protocols{p}, scenarios{s}, seeds(k));

            % Run single simulation
            metrics = run_single_simulation(params, protocols{p}, scenarios{s});

            % Store results
            results(p, s, k, :) = [
                metrics.FND,
                metrics.HND,
                metrics.PDR,
                metrics.LatA,
                metrics.AvgEnergy,
                metrics.Gini,
                metrics.Overhead,
                metrics.Throughput
            ];

            fprintf('FND=%d  PDR=%.1f%%  LatA=%.1fms\n', ...
                    metrics.FND, metrics.PDR*100, metrics.LatA);
        end
    end
end

%% ── Compute mean and std across seeds ────────────────────────────────────
results_mean = mean(results, 3);   % average over seeds dimension
results_std  = std(results,  0, 3);

fprintf('\n========================================\n');
fprintf('  All simulations complete\n');
fprintf('========================================\n\n');

%% ── Save results to CSV ───────────────────────────────────────────────────
save_results_csv(results_mean, results_std, protocols, scenarios);

%% ── Generate paper figures ────────────────────────────────────────────────
generate_figures(results_mean, results_std, protocols, scenarios);

fprintf('\nDone. Check ..\results\ and ..\figures\ folders.\n');
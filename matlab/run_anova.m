%% RUN_ANOVA.M  Statistical significance testing for CARHy-WSN results
% Runs one-way ANOVA + Tukey HSD on latency and overhead
% across all 6 protocols using the 5 seed repetitions

clc; clear;
fprintf('=== ANOVA Statistical Significance Tests ===\n\n');

params = get_params();
protocols = {'CARHy','AODV','DSDV','ZRP','EH_Routing','MSLBA'};
seeds     = [42, 43, 44, 45, 46];
n_proto   = length(protocols);
n_seeds   = length(seeds);

%% ── Collect raw per-seed results ─────────────────────────────────────────
params.rounds = 2000;

latA_raw     = zeros(n_proto, n_seeds);
overhead_raw = zeros(n_proto, n_seeds);
FND_raw      = zeros(n_proto, n_seeds);
PDR_raw      = zeros(n_proto, n_seeds);

fprintf('Collecting raw results (this may take a few minutes)...\n\n');

for p = 1:n_proto
    for k = 1:n_seeds
        params.seed = seeds(k);
        m = run_single_simulation(params, protocols{p}, 'Mixed');
        latA_raw(p,k)     = m.LatA;
        overhead_raw(p,k) = m.Overhead;
        FND_raw(p,k)      = m.FND;
        PDR_raw(p,k)      = m.PDR;
        fprintf('  %s seed=%d done\n', protocols{p}, seeds(k));
    end
end

%% ── ANOVA on Class A Latency ──────────────────────────────────────────────
fprintf('\n=== ANOVA: Class A Emergency Latency ===\n');
[p_lat, tbl_lat, stats_lat] = anova1(latA_raw', protocols, 'off');
fprintf('F-statistic: %.4f\n', tbl_lat{2,5});
fprintf('p-value:     %.6f\n', p_lat);
if p_lat < 0.05
    fprintf('Result: SIGNIFICANT (p < 0.05) -- differences are not by chance\n');
else
    fprintf('Result: NOT significant (p >= 0.05)\n');
end

% Tukey HSD post-hoc test
fprintf('\nTukey HSD Post-Hoc Comparisons (latency):\n');
[comparison_lat, means_lat, ~, gnames_lat] = multcompare(stats_lat, ...
    'CType','tukey-kramer','Display','off');
fprintf('%-15s vs %-15s  mean diff  p-value  significant?\n', ...
    'Protocol 1','Protocol 2');
fprintf('%s\n', repmat('-',1,65));
for i = 1:size(comparison_lat,1)
    g1  = gnames_lat{comparison_lat(i,1)};
    g2  = gnames_lat{comparison_lat(i,2)};
    md  = comparison_lat(i,4);
    pv  = comparison_lat(i,6);
    sig = '';
    if pv < 0.001, sig = '***';
    elseif pv < 0.01, sig = '**';
    elseif pv < 0.05, sig = '*';
    end
    fprintf('%-15s vs %-15s  %+8.2f   %.4f   %s\n', g1, g2, md, pv, sig);
end

%% ── ANOVA on Routing Overhead ─────────────────────────────────────────────
fprintf('\n=== ANOVA: Routing Overhead ===\n');
[p_oh, tbl_oh, stats_oh] = anova1(overhead_raw', protocols, 'off');
fprintf('F-statistic: %.4f\n', tbl_oh{2,5});
fprintf('p-value:     %.6f\n', p_oh);
if p_oh < 0.05
    fprintf('Result: SIGNIFICANT (p < 0.05)\n');
else
    fprintf('Result: NOT significant (p >= 0.05)\n');
end

fprintf('\nTukey HSD Post-Hoc Comparisons (overhead):\n');
[comparison_oh, ~, ~, gnames_oh] = multcompare(stats_oh, ...
    'CType','tukey-kramer','Display','off');
fprintf('%-15s vs %-15s  mean diff  p-value  significant?\n', ...
    'Protocol 1','Protocol 2');
fprintf('%s\n', repmat('-',1,65));
for i = 1:size(comparison_oh,1)
    g1  = gnames_oh{comparison_oh(i,1)};
    g2  = gnames_oh{comparison_oh(i,2)};
    md  = comparison_oh(i,4);
    pv  = comparison_oh(i,6);
    sig = '';
    if pv < 0.001, sig = '***';
    elseif pv < 0.01, sig = '**';
    elseif pv < 0.05, sig = '*';
    end
    fprintf('%-15s vs %-15s  %+8.2f   %.4f   %s\n', g1, g2, md, pv, sig);
end

fprintf('\nSignificance codes:  *** p<0.001  ** p<0.01  * p<0.05\n');
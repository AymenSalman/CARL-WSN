function save_results_csv(results_mean, results_std, protocols, scenarios)
% Save all results to CSV files in the results folder
results_dir = '..\results\';
if ~exist(results_dir, 'dir')
    mkdir(results_dir);
end

metric_names = {'FND','HND','PDR','LatA_ms','AvgEnergy_J','Gini','Overhead','Throughput'};

for s = 1:length(scenarios)
    fname = fullfile(results_dir, sprintf('results_%s.csv', scenarios{s}));
    fid   = fopen(fname, 'w');

    % Header
    fprintf(fid, 'Protocol');
    for m = 1:length(metric_names)
        fprintf(fid, ',%s_mean,%s_std', metric_names{m}, metric_names{m});
    end
    fprintf(fid, '\n');

    % Data rows
    for p = 1:length(protocols)
        fprintf(fid, '%s', protocols{p});
        for m = 1:length(metric_names)
            fprintf(fid, ',%.4f,%.4f', results_mean(p,s,m), results_std(p,s,m));
        end
        fprintf(fid, '\n');
    end

    fclose(fid);
    fprintf('Saved: %s\n', fname);
end
end
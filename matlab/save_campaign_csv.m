function save_campaign_csv(results_mean, results_std, protocols, scenarios, M)
    names = {'FND','HND','LND','PDR','LatA','Gini','Overhead','Overhead_tdma','Throughput','AvgEnergy'};
    idx   = [M.FND M.HND M.LND M.PDR M.LatA M.Gini M.OH M.OHt M.Thru M.AvgE];
    for s=1:numel(scenarios)
        fid = fopen(sprintf('..\\results\\results_%s.csv',scenarios{s}),'w');
        fprintf(fid,'Protocol');
        for mi=1:numel(names), fprintf(fid,',%s_mean,%s_std',names{mi},names{mi}); end
        fprintf(fid,'\n');
        for p=1:numel(protocols)
            fprintf(fid,'%s',protocols{p});
            for mi=1:numel(names)
                fprintf(fid,',%.4f,%.4f',results_mean(p,s,1,idx(mi)),results_std(p,s,1,idx(mi)));
            end
            fprintf(fid,'\n');
        end
        fclose(fid);
    end
    fprintf('CSVs -> results_<scenario>.csv\n');
end
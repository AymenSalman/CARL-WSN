function run_anova_tukey(raw, protocols, scenarios, M)
% One-way ANOVA across the 8 protocols + Tukey-Kramer post-hoc, per scenario/metric.
    names = {'FND','HND','LND','PDR','LatA','Gini','Overhead','Overhead_tdma','Throughput','AvgEnergy'};
    idx   = [M.FND M.HND M.LND M.PDR M.LatA M.Gini M.OH M.OHt M.Thru M.AvgE];
    fid = fopen('..\\results\\anova_results.txt','w');
    for s=1:numel(scenarios)
        for mi=1:numel(names)
            data = squeeze(raw(:,s,:,idx(mi)))';        % seeds x protocols
            if all(isnan(data(:))) || all(var(data,0,1,'omitnan')==0), continue; end
            [pval,~,stats] = anova1(data, protocols, 'off');
            fprintf(fid,'[%s | %s] ANOVA p = %.3g\n', scenarios{s}, names{mi}, pval);
            if pval < 0.05
                c = multcompare(stats,'CType','tukey-kramer','Display','off');
                for r=1:size(c,1)
                    if c(r,6) < 0.05
                        fprintf(fid,'    %-10s vs %-10s  diff=%+.3g  p=%.3g\n',...
                            protocols{c(r,1)}, protocols{c(r,2)}, c(r,4), c(r,6));
                    end
                end
            end
        end
        fprintf(fid,'\n');
    end
    fclose(fid);
    fprintf('ANOVA/Tukey -> anova_results.txt\n');
end
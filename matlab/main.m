%% MAIN.M  CARL-WSN full campaign on the rebuilt realistic engine
%  8 protocols x 4 scenarios x 20 seeds = 640 runs, serial, run-to-death.
clc; clear; close all;
params = get_params();
protocols = {'CARHy_RL','AODV','DSDV','ZRP','EH_Routing','MSLBA','RLCR','FQ_UCR','RPL','CARHy_Rule'};
scenarios = {'ClassA','ClassB','ClassC','Mixed'};
seeds     = 42:61;            % 20 seeds
params.rounds = 8000;         % SAFETY CAP; runs stop earlier at <10% alive

np=numel(protocols); ns=numel(scenarios); nk=numel(seeds);
M.FND=1;M.HND=2;M.LND=3;M.PDR=4;M.LatA=5;M.Gini=6;M.OH=7;M.OHt=8;
M.Deliv=9;M.Energy=10;M.End=11;M.Thru=12;M.AvgE=13; nm=13;
raw = nan(np,ns,nk,nm);
alive_curves = cell(np,ns,nk);
cap_flags = false(np,ns,nk);

t0=tic; rc=0; total=np*ns*nk;
fprintf('Campaign: %d runs (serial). Safety cap %d rounds.\n\n', total, params.rounds);
for s=1:ns
  for k=1:nk
    params.seed = seeds(k);
    for p=1:np
      rc=rc+1;
      m = run_single_simulation(params, protocols{p}, scenarios{s});
      raw(p,s,k,M.FND)=m.FND; raw(p,s,k,M.HND)=m.HND; raw(p,s,k,M.LND)=m.LND;
      raw(p,s,k,M.PDR)=m.PDR; raw(p,s,k,M.LatA)=m.LatA; raw(p,s,k,M.Gini)=m.Gini;
      raw(p,s,k,M.OH)=m.Overhead; raw(p,s,k,M.OHt)=m.Overhead_tdma;
      raw(p,s,k,M.Deliv)=m.TotalDelivered; raw(p,s,k,M.Energy)=m.TotalEnergy;
      raw(p,s,k,M.End)=m.EndRound;
      alive_curves{p,s,k}=m.alive_per_round; cap_flags(p,s,k)=m.CapHit;
      if m.CapHit
        fprintf('[%3d/%d] %-10s %-7s seed %d | PDR %.1f%% FND %d [!] CAP HIT (censored)\n',...
          rc,total,protocols{p},scenarios{s},seeds(k),100*m.PDR,m.FND);
      else
        fprintf('[%3d/%d] %-10s %-7s seed %d | PDR %.1f%% FND %d end %d\n',...
          rc,total,protocols{p},scenarios{s},seeds(k),100*m.PDR,m.FND,m.EndRound);
      end
    end
    % common horizon for this (scenario,seed): longest network-death round
    H = max(raw(:,s,k,M.End));
    raw(:,s,k,M.Thru) = raw(:,s,k,M.Deliv)/H;
    raw(:,s,k,M.AvgE) = raw(:,s,k,M.Energy)/H;
    save('..\results\campaign_checkpoint.mat','raw','alive_curves','cap_flags','M',...
         'protocols','scenarios','seeds','-v7.3');
    fprintf('  -- checkpoint saved (%s, seed %d), elapsed %.1f min\n',...
            scenarios{s},seeds(k),toc(t0)/60);
  end
end
fprintf('\nDone in %.1f min. Cap hits: %d\n', toc(t0)/60, sum(cap_flags(:)));

results_mean = mean(raw,3,'omitnan');
results_std  = std(raw,0,3,'omitnan');
save('..\results\campaign_results.mat','raw','results_mean','results_std','alive_curves',...
     'cap_flags','M','protocols','scenarios','seeds','-v7.3');
save_campaign_csv(results_mean, results_std, protocols, scenarios, M);
run_anova_tukey(raw, protocols, scenarios, M);
fprintf('\nAll outputs written.\n');
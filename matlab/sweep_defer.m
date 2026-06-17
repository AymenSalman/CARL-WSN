%% SWEEP_DEFER.M  T_defer x max_defer frontier for CARL (Mixed, 20 seeds)
clc; clear; close all;
params = get_params();
params.rounds = 8000;
seeds = 42:61;

T_grid  = [0.00 0.05 0.10 0.15 0.20];
MD_grid = [3 5 10];

% build the (T_defer, max_defer) combinations; md is irrelevant when T_defer=0
combos = [];
for td = T_grid
    if td==0
        combos = [combos; 0 3];           % no-deferral baseline (md unused)
    else
        for md = MD_grid, combos = [combos; td md]; end
    end
end
nc = size(combos,1); nk = numel(seeds);
PDR = zeros(nc,nk); FND = zeros(nc,nk); HND = zeros(nc,nk); CAP = false(nc,nk);

fprintf('Sweep: %d combos x %d seeds = %d runs\n', nc, nk, nc*nk);
t0=tic;
for c = 1:nc
    params.T_defer   = combos(c,1);
    params.max_defer = combos(c,2);
    for k = 1:nk
        params.seed = seeds(k);
        m = run_single_simulation(params, 'CARHy_RL', 'Mixed');
        PDR(c,k)=m.PDR*100; FND(c,k)=m.FND; HND(c,k)=m.HND; CAP(c,k)=m.CapHit;
    end
    if any(CAP(c,:)), capflag = '[CAP!]'; else, capflag = ''; end
    fprintf('  T_defer=%.2f max_defer=%2d | PDR=%5.1f%% FND=%4.0f HND=%4.0f %s\n', ...
        combos(c,1), combos(c,2), mean(PDR(c,:)), mean(FND(c,:)), mean(HND(c,:)), capflag);
end
fprintf('Done in %.1f min\n', toc(t0)/60);

% ── Frontier figure: PDR vs FND, labelled by (T_defer,max_defer) ──
figure('Color','w','Position',[100 100 760 560]);
mPDR=mean(PDR,2); mFND=mean(FND,2);
scatter(mFND,mPDR,70,'filled'); hold on;
for c=1:nc
    if combos(c,1)==0, lbl='no defer'; else, lbl=sprintf('%.2f/%d',combos(c,1),combos(c,2)); end
    text(mFND(c)+8,mPDR(c),lbl,'FontSize',9);
end
xlabel('FND (network lifetime, rounds)'); ylabel('CARL PDR (%)');
title('PDR vs Lifetime frontier  (label = T\_defer / max\_defer)');
grid on; set(gca,'FontSize',12,'FontWeight','bold');
exportgraphics(gcf,'..\figures\fig8_defer_frontier.pdf','ContentType','vector');

save('..\results\sweep_defer.mat','combos','PDR','FND','HND','CAP','seeds');
fprintf('Frontier -> fig8_defer_frontier.pdf ; data -> sweep_defer.mat\n');
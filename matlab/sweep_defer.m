%% SWEEP_DEFER.M  T_defer sensitivity for CARL (Mixed, 20 seeds)
%  NOTE: max_defer parameter retired — deferral below T_defer is now
%  unconditional and permanent (see context_classifier_rl.m). This is now
%  a single-parameter (T_defer) sweep, not a 2D frontier.
clc; clear; close all;
params = get_params();
params.rounds = 8000;
seeds = 42:61;

T_grid = [0.00 0.05 0.10 0.15 0.20];

nc = numel(T_grid); nk = numel(seeds);
PDR = zeros(nc,nk); FND = zeros(nc,nk); HND = zeros(nc,nk); CAP = false(nc,nk);

fprintf('Sweep: %d T_defer values x %d seeds = %d runs\n', nc, nk, nc*nk);
t0=tic;
for c = 1:nc
    params.T_defer = T_grid(c);
    for k = 1:nk
        params.seed = seeds(k);
        m = run_single_simulation(params, 'CARHy_RL', 'Mixed');
        PDR(c,k)=m.PDR*100; FND(c,k)=m.FND; HND(c,k)=m.HND; CAP(c,k)=m.CapHit;
    end
    if any(CAP(c,:)), capflag = '[CAP!]'; else, capflag = ''; end
    fprintf('  T_defer=%.2f | PDR=%5.1f%% FND=%4.0f HND=%4.0f %s\n', ...
        T_grid(c), mean(PDR(c,:)), mean(FND(c,:)), mean(HND(c,:)), capflag);
end
fprintf('Done in %.1f min\n', toc(t0)/60);

figure('Color','w','Position',[100 100 760 560]);
mPDR=mean(PDR,2); mFND=mean(FND,2);
scatter(mFND,mPDR,70,'filled'); hold on;
for c=1:nc
    if T_grid(c)==0, lbl='no defer'; else, lbl=sprintf('%.2f',T_grid(c)); end
    text(mFND(c)+8,mPDR(c),lbl,'FontSize',9);
end
xlabel('FND (network lifetime, rounds)'); ylabel('CARL PDR (%)');
title('PDR vs Lifetime frontier  (label = T\_defer)');
grid on; set(gca,'FontSize',12,'FontWeight','bold');
exportgraphics(gcf,'..\figures\fig8_defer_frontier.pdf','ContentType','vector');

save('..\results\sweep_defer.mat','T_grid','PDR','FND','HND','CAP','seeds');
fprintf('Frontier -> fig8_defer_frontier.pdf ; data -> sweep_defer.mat\n');
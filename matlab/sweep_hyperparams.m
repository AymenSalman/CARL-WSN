%% SWEEP_HYPERPARAMS.M  Full-factorial grid search: alpha x gamma x epsilon_decay
%  Reviewer 3 response: CARL-WSN's Q-learning hyperparameters were never
%  systematically grid-searched. This sweep tests all combinations of the
%  three core hyperparameters against the default operating point.
clc; clear; close all;
params = get_params();
params.rounds = 8000;
seeds = 42:61;

alpha_grid = [0.05 0.10 0.20];
gamma_grid = [0.70 0.90 0.99];
decay_grid = [0.995 0.998 0.999];

combos = [];
for a = alpha_grid
    for g = gamma_grid
        for d = decay_grid
            combos = [combos; a g d];
        end
    end
end
nc = size(combos,1); nk = numel(seeds);
PDR = zeros(nc,nk); FND = zeros(nc,nk); HND = zeros(nc,nk); CAP = false(nc,nk);

fprintf('Sweep: %d combos x %d seeds = %d runs\n', nc, nk, nc*nk);
t0=tic;
for c = 1:nc
    params.alpha_lr     = combos(c,1);
    params.gamma_df      = combos(c,2);
    params.epsilon_decay = combos(c,3);
    for k = 1:nk
        params.seed = seeds(k);
        m = run_single_simulation(params, 'CARHy_RL', 'Mixed');
        PDR(c,k)=m.PDR*100; FND(c,k)=m.FND; HND(c,k)=m.HND; CAP(c,k)=m.CapHit;
    end
    if any(CAP(c,:)), capflag = '[CAP!]'; else, capflag = ''; end
    fprintf('  a=%.2f g=%.2f decay=%.3f | PDR=%5.1f%% FND=%4.0f HND=%4.0f %s\n', ...
        combos(c,1), combos(c,2), combos(c,3), mean(PDR(c,:)), mean(FND(c,:)), mean(HND(c,:)), capflag);
end
fprintf('Done in %.1f min\n', toc(t0)/60);

save('..\results\sweep_hyperparams.mat','combos','PDR','FND','HND','CAP','seeds');
fprintf('Data -> sweep_hyperparams.mat\n');
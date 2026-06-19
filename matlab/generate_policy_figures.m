%% GENERATE_POLICY_FIGURES.M  Convergence + learned-policy + Q-value figures (current engine)
clc; clear; close all;
params = get_params(); params.rounds = 8000; params.seed = 42;
m = run_single_simulation(params, 'CARHy_RL', 'Mixed');
Q  = m.Q_table;        % 18 x 3
qh = m.Q_history;      % per-round max |delta Q|
figdir = '..\figures\';

% ── Convergence ──────────────────────────────────────────────────────────
figure('Color','w','Position',[100 100 760 460]);
qpos = qh; qpos(qpos<=0) = NaN;          % for log scale
semilogy(qpos,'LineWidth',1.2,'Color',[0.20 0.45 0.80]); hold on;
conv = find(movmean(qh,50) < 0.01, 1);
if ~isempty(conv)
    xline(conv,'--r','LineWidth',1.4);
    text(conv*1.05, max(qpos)*0.3, sprintf('converged \\approx round %d',conv),'FontSize',11);
end
xlabel('Round'); ylabel('max |\Delta Q| per round (log)');
title('CARL-WSN Q-table Convergence'); grid on;
set(gca,'FontSize',12,'FontWeight','bold');
exportgraphics(gcf,[figdir 'fig_convergence.pdf'],'ContentType','vector');

% ── Learned policy heatmap (split by link stability) ─────────────────────
% State index = (U-1)*6 + (Er-1)*2 + Ls ; Ls=1 unstable(1..), Ls=2 stable
[~, policy] = max(Q,[],2);               % 18x1 best action: 1=pro,2=rea,3=hyb
unstable = policy(1:2:18);               % Ls=1 states (odd indices)
stable   = policy(2:2:18);               % Ls=2 states (even indices)
P = [unstable, stable];                  % 9 x 2  (rows: 9 U/Er combos)
figure('Color','w','Position',[100 100 620 520]);
imagesc(P,[1 3]);
cmap = [0.20 0.45 0.80; 0.30 0.69 0.29; 1.00 0.60 0.00]; colormap(cmap);
cb = colorbar('Ticks',[1.33 2 2.67],'TickLabels',{'Proactive','Reactive','Hybrid'});
set(gca,'XTick',[1 2],'XTickLabel',{'Unstable L_s','Stable L_s'},...
    'YTick',1:9,'YTickLabel',{'A/Er1','A/Er2','A/Er3','B/Er1','B/Er2','B/Er3','C/Er1','C/Er2','C/Er3'});
ylabel('Urgency class / Energy level'); title('CARL-WSN Learned Policy');
set(gca,'FontSize',11,'FontWeight','bold');
exportgraphics(gcf,[figdir 'fig_learned_policy.pdf'],'ContentType','vector');

% ── Raw Q-values ─────────────────────────────────────────────────────────
figure('Color','w','Position',[100 100 820 460]);
bar(Q,'grouped'); 
xlabel('State index (1--18)'); ylabel('Q-value');
legend({'Proactive','Reactive','Hybrid'},'Location','best');
title('CARL-WSN Learned Q-values per State');
set(gca,'FontSize',12,'FontWeight','bold','XTick',1:18); grid on;
exportgraphics(gcf,[figdir 'fig_qvalues.pdf'],'ContentType','vector');

fprintf('Policy figures regenerated. Convergence at round %d.\n', conv);
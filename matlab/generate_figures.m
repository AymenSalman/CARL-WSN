%% GENERATE_FIGURES.M  Publication figures from the real campaign data
clc; clear; close all;
load('..\results\campaign_results.mat');   % must run from the matlab\ folder

disp_names = {'CARL-WSN','AODV','DSDV','ZRP','EH-Routing','MSLBA','RLCR','FQ-UCR'};
np = numel(protocols);
sMix = find(strcmp(scenarios,'Mixed'));
cols = [0.20 0.45 0.80; 0.30 0.69 0.29; 0.84 0.19 0.15; 1.00 0.60 0.00; ...
        0.49 0.18 0.56; 0.55 0.34 0.29; 0.30 0.75 0.75; 0.90 0.42 0.65];
figdir = '..\figures\';
mu  = @(s,met) squeeze(results_mean(:,s,1,met));
sd  = @(s,met) squeeze(results_std (:,s,1,met));
setfig = @() set(gcf,'Color','w','Position',[100 100 760 480]);
stylex = @() set(gca,'XTick',1:np,'XTickLabel',disp_names,'XTickLabelRotation',35,...
                 'FontSize',12,'FontWeight','bold','Box','off');

% Fig 1: lifetime FND + HND
figure; setfig();
F=mu(sMix,M.FND); H=mu(sMix,M.HND); Fe=sd(sMix,M.FND); He=sd(sMix,M.HND);
b=bar([F H],'grouped'); b(1).FaceColor=[0.20 0.45 0.80]; b(2).FaceColor=[0.84 0.19 0.15];
hold on; errorbar(b(1).XEndPoints,F,Fe,'k','linestyle','none','LineWidth',1);
errorbar(b(2).XEndPoints,H,He,'k','linestyle','none','LineWidth',1);
ylabel('Round'); legend({'FND','HND'},'Location','northwest');
title('Network Lifetime — Mixed Traffic'); stylex();
exportgraphics(gcf,[figdir 'fig1_lifetime_FND.pdf'],'ContentType','vector');

% Fig 2: Class A latency
figure; setfig();
L=mu(sMix,M.LatA); Le=sd(sMix,M.LatA);
b=bar(L,'FaceColor','flat'); for i=1:np, b.CData(i,:)=cols(i,:); end
hold on; errorbar(1:np,L,Le,'k','linestyle','none','LineWidth',1);
yline(100,'--r','Latency threshold (100 ms)','LineWidth',1.5,'FontSize',11);
ylabel('Mean Class A Latency (ms)'); ylim([0 max(40,max(L)+5)]);
title('Class A Emergency Packet Latency'); stylex();
exportgraphics(gcf,[figdir 'fig2_latency_classA.pdf'],'ContentType','vector');

% Fig 3: PDR across scenarios
figure; setfig();
PDR=squeeze(results_mean(:,:,1,M.PDR))*100;
bar(PDR,'grouped'); ylabel('Packet Delivery Ratio (%)'); ylim([0 110]);
legend(scenarios,'Location','southoutside','Orientation','horizontal');
title('PDR across Traffic Scenarios'); stylex();
exportgraphics(gcf,[figdir 'fig3_PDR_scenarios.pdf'],'ContentType','vector');

% Fig 4: Gini
figure; setfig();
G=mu(sMix,M.Gini); Ge=sd(sMix,M.Gini);
b=bar(G,'FaceColor','flat'); for i=1:np, b.CData(i,:)=cols(i,:); end
hold on; errorbar(1:np,G,Ge,'k','linestyle','none','LineWidth',1);
ylabel('Gini Coefficient (lower = more balanced)'); ylim([0 0.25]);
title('Energy Balance across Protocols'); stylex();
exportgraphics(gcf,[figdir 'fig4_energy_gini.pdf'],'ContentType','vector');

% Fig 5: overhead, log scale, clustering at TDMA
figure; setfig();
OH=mu(sMix,M.OH);
OH(strcmp(protocols,'RLCR'))   = results_mean(find(strcmp(protocols,'RLCR')),sMix,1,M.OHt);
OH(strcmp(protocols,'FQ_UCR')) = results_mean(find(strcmp(protocols,'FQ_UCR')),sMix,1,M.OHt);
b=bar(OH,'FaceColor','flat'); for i=1:np, b.CData(i,:)=cols(i,:); end
set(gca,'YScale','log'); ylabel('Control Packets per Data Packet (log)');
for i=1:np, text(i,OH(i)*1.15,sprintf('%.2f',OH(i)),'HorizontalAlignment','center','FontSize',9); end
title('Routing Overhead (clustering under TDMA accounting)'); stylex();
exportgraphics(gcf,[figdir 'fig5_routing_overhead.pdf'],'ContentType','vector');

% Fig 6: throughput
figure; setfig();
T=mu(sMix,M.Thru); Te=sd(sMix,M.Thru);
b=bar(T,'FaceColor','flat'); for i=1:np, b.CData(i,:)=cols(i,:); end
hold on; errorbar(1:np,T,Te,'k','linestyle','none','LineWidth',1);
ylabel('Packets Delivered per Round');
title('Network Throughput — Mixed Traffic'); stylex();
exportgraphics(gcf,[figdir 'fig6_throughput.pdf'],'ContentType','vector');

% Fig 7: alive-over-time, representative seed
figure; setfig();
ks=1; hold on;
for p=1:np
    c=alive_curves{p,sMix,ks};
    plot(1:numel(c),c,'LineWidth',1.8,'Color',cols(p,:));
end
xlabel('Round'); ylabel('Alive Nodes'); xlim([0 1500]); ylim([0 100]);
legend(disp_names,'Location','northeastoutside');
title('Network Decay — Mixed Traffic (seed 42)');
set(gca,'FontSize',12,'FontWeight','bold','Box','off');
exportgraphics(gcf,[figdir 'fig7_alive_curve.pdf'],'ContentType','vector');

fprintf('All 7 figures written to %s\n', figdir);
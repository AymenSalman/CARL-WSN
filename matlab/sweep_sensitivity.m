%% SWEEP_SENSITIVITY.M  One-at-a-time sensitivity of CARL to un-cited parameters
%  CARL only, Mixed, 20 seeds. Everything not being swept stays at locked defaults.
clc; clear; close all;
base = get_params(); base.rounds = 8000;
seeds = 42:61; nk = numel(seeds);

% Each entry: name, the field(s) to set, and the list of value-sets to try.
% A value-set is a struct of field overrides. Default is marked with (def).
S = {};
S{end+1} = struct('name','w_e/w_p (relay weights)', ...
    'sets',{{ struct('w_e',0.4,'w_p',0.6), struct('w_e',0.6,'w_p',0.4), struct('w_e',0.8,'w_p',0.2) }}, ...
    'labels',{{'0.4/0.6','0.6/0.4 (def)','0.8/0.2'}});
S{end+1} = struct('name','PRR midpoint beta', ...
    'sets',{{ struct('ch_beta',80), struct('ch_beta',90), struct('ch_beta',100) }}, ...
    'labels',{{'80','90 (def)','100'}});
S{end+1} = struct('name','PRR sharpness alpha', ...
    'sets',{{ struct('ch_alpha',0.12), struct('ch_alpha',0.18), struct('ch_alpha',0.25) }}, ...
    'labels',{{'0.12','0.18 (def)','0.25'}});
S{end+1} = struct('name','Link-stability T_L', ...
    'sets',{{ struct('T_L',0.6), struct('T_L',0.7), struct('T_L',0.8) }}, ...
    'labels',{{'0.6','0.7 (def)','0.8'}});

fid = fopen('..\results\sensitivity.txt','w');
allres = {};
t0 = tic;
for si = 1:numel(S)
    sw = S{si};
    fprintf('\n=== %s ===\n', sw.name);
    fprintf(fid,'\n=== %s ===\n', sw.name);
    fprintf(    '%-14s %7s %7s %7s %7s %9s\n','value','PDR%','FND','HND','LatA','Overhead');
    fprintf(fid,'%-14s %7s %7s %7s %7s %9s\n','value','PDR%','FND','HND','LatA','Overhead');
    nv = numel(sw.sets); R = zeros(nv,5);
    for vi = 1:nv
        params = base; ov = sw.sets{vi};
        f = fieldnames(ov);
        for j=1:numel(f), params.(f{j}) = ov.(f{j}); end
        acc = zeros(nk,5);
        for k=1:nk
            params.seed = seeds(k);
            m = run_single_simulation(params, 'CARHy_RL', 'Mixed');
            acc(k,:) = [m.PDR*100, m.FND, m.HND, m.LatA, m.Overhead];
        end
        R(vi,:) = mean(acc,1);
        fprintf(    '%-14s %7.1f %7.0f %7.0f %7.1f %9.2f\n', sw.labels{vi}, R(vi,:));
        fprintf(fid,'%-14s %7.1f %7.0f %7.0f %7.1f %9.2f\n', sw.labels{vi}, R(vi,:));
    end
    % sensitivity = % swing of each metric across the swept range
    swing = 100*(max(R)-min(R))./mean(R);
    fprintf(    '  swing%%: PDR %.1f  FND %.1f  HND %.1f  LatA %.1f  OH %.1f\n', swing);
    fprintf(fid,'  swing%%: PDR %.1f  FND %.1f  HND %.1f  LatA %.1f  OH %.1f\n', swing);
    allres{si} = struct('name',sw.name,'labels',{sw.labels},'R',R,'swing',swing);
end
fclose(fid);
save('..\results\sweep_sensitivity.mat','allres');
fprintf('\nDone in %.1f min. Table -> results\\sensitivity.txt\n', toc(t0)/60);
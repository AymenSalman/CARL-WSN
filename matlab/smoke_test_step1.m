clc; clear;
params = get_params(); params.seed = 42; params.rounds = 2000;

scen = {'ClassA','ClassB','ClassC','Mixed'};
fprintf('%-8s %6s %10s %9s %7s\n','scen','PDR%','LatA(ms)','overhead','FND');
for s = 1:numel(scen)
    m = run_single_simulation(params, 'CARHy_RL', scen{s});
    fprintf('%-8s %6.1f %10.1f %9.2f %7d\n', scen{s}, m.PDR*100, m.LatA, m.Overhead, m.FND);
end
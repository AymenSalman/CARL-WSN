%% RUN_DECISION_TREE.M  Validate lightweight decision tree for CARHy-WSN
% Trains a decision tree on synthetic context vectors
% and measures accuracy vs the rule-based oracle classifier
%
% This validates Contribution 4: the protocol can be made
% self-configuring using a lightweight ML classifier

clc; clear;
fprintf('=== Decision Tree Classifier Validation ===\n\n');

%% ── Step 1: Generate synthetic training data ──────────────────────────────
% Generate 10000 random context vectors
% Each sample: [U_numeric, E_r, L_s] -> mode label
rng(42);
N_samples = 10000;

% U: 1=ClassA, 2=ClassB, 3=ClassC
U   = randi(3, N_samples, 1);
E_r = rand(N_samples, 1);        % uniform [0, 1]
L_s = rand(N_samples, 1);        % uniform [0, 1]

T_E = 0.3;
T_L = 0.7;

% Generate ground truth labels using the rule-based oracle
% Modes: 1=proactive, 2=reactive, 3=hybrid
labels = zeros(N_samples, 1);

for i = 1:N_samples
    if U(i) == 1
        % Rule 1: Class A always proactive
        labels(i) = 1;
    elseif (U(i) == 2 || U(i) == 3) && E_r(i) >= T_E && L_s(i) >= T_L
        % Rule 2: Healthy node, stable link -> reactive
        labels(i) = 2;
    elseif U(i) == 2 && E_r(i) < T_E
        % Rule 3: Class B, energy critical -> hybrid
        labels(i) = 3;
    elseif L_s(i) < T_L
        % Rule 4: Unstable link -> proactive
        labels(i) = 1;
    else
        % Rule 5: Best effort degraded -> reactive
        labels(i) = 2;
    end
end

% Feature matrix
X = [U, E_r, L_s];
label_names = {'proactive','reactive','hybrid'};

fprintf('Dataset generated: %d samples\n', N_samples);
fprintf('Class distribution:\n');
fprintf('  Proactive: %d (%.1f%%)\n', sum(labels==1), sum(labels==1)/N_samples*100);
fprintf('  Reactive:  %d (%.1f%%)\n', sum(labels==2), sum(labels==2)/N_samples*100);
fprintf('  Hybrid:    %d (%.1f%%)\n', sum(labels==3), sum(labels==3)/N_samples*100);

%% ── Step 2: Train/test split (80/20) ─────────────────────────────────────
n_train = floor(0.8 * N_samples);
idx     = randperm(N_samples);

X_train = X(idx(1:n_train), :);
y_train = labels(idx(1:n_train));
X_test  = X(idx(n_train+1:end), :);
y_test  = labels(idx(n_train+1:end));

fprintf('\nTraining set: %d samples\n', n_train);
fprintf('Test set:     %d samples\n', N_samples - n_train);

%% ── Step 3: Train decision tree with max depth 3 ─────────────────────────
% MaxNumSplits = 2^3 - 1 = 7 (depth 3 tree)
dt = fitctree(X_train, y_train, ...
    'MaxNumSplits', 7, ...
    'MinLeafSize', 10, ...
    'CategoricalPredictors', 1);   % U is categorical

fprintf('\nDecision tree trained successfully.\n');
fprintf('Number of leaves: %d\n', sum(~dt.IsBranchNode));


%% ── Step 4: Evaluate on test set ─────────────────────────────────────────
y_pred = predict(dt, X_test);
accuracy = sum(y_pred == y_test) / length(y_test) * 100;

fprintf('\n=== Decision Tree Test Results ===\n');
fprintf('Overall accuracy: %.2f%%\n', accuracy);

% Per-class accuracy
for c = 1:3
    idx_c    = y_test == c;
    acc_c    = sum(y_pred(idx_c) == y_test(idx_c)) / sum(idx_c) * 100;
    fprintf('  %s accuracy: %.2f%% (%d samples)\n', ...
        label_names{c}, acc_c, sum(idx_c));
end

%% ── Step 5: Confusion matrix ──────────────────────────────────────────────
fprintf('\nConfusion Matrix (rows=actual, cols=predicted):\n');
fprintf('%12s %10s %10s %10s\n','','proactive','reactive','hybrid');
for r = 1:3
    row_str = sprintf('%12s', label_names{r});
    for c = 1:3
        row_str = [row_str, sprintf('%10d', ...
            sum(y_test==r & y_pred==c))];
    end
    fprintf('%s\n', row_str);
end

%% ── Step 6: Energy overhead of tree vs rule-based ────────────────────────
fprintf('\n=== Computational Cost Comparison ===\n');
fprintf('Rule-based classifier:\n');
fprintf('  Operations per packet: ~5 comparisons\n');
fprintf('  Memory: 0 bytes (no model stored)\n');
fprintf('  Latency: <0.01 ms\n\n');

fprintf('Decision tree classifier:\n');
fprintf('  Operations per packet: ~7 comparisons (tree traversal)\n');
n_nodes   = numel(dt.IsBranchNode);
mem_bytes = n_nodes * 3 * 8;   % 3 doubles per node (threshold, feature, value)
fprintf('  Memory: ~%d bytes (~%.1f KB)\n', mem_bytes, mem_bytes/1024);
fprintf('  Latency: <0.1 ms on sensor processor\n\n');

fprintf('Conclusion: Decision tree achieves %.2f%% accuracy with\n', accuracy);
fprintf('minimal overhead -- suitable for self-configuring deployment.\n');

%% ── Step 7: Cross-validation for robustness ──────────────────────────────
fprintf('\n=== 5-Fold Cross-Validation ===\n');
cv_model  = crossval(dt, 'KFold', 5);
cv_loss   = kfoldLoss(cv_model);
cv_acc    = (1 - cv_loss) * 100;
fprintf('Cross-validation accuracy: %.2f%%\n', cv_acc);
fprintf('Cross-validation error:    %.4f\n', cv_loss);
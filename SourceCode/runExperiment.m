function summary = runExperiment(scenarioName)

    cfg = getConfig(scenarioName);

    if ~exist('results', 'dir'), mkdir('results'); end
    if ~exist('figures', 'dir'), mkdir('figures'); end

    nSeeds = numel(cfg.seeds);
    nRows  = 2 * nSeeds;

    scenarios          = cell(nRows, 1);
    seeds              = zeros(nRows, 1);
    methods            = cell(nRows, 1);
    completedPct       = zeros(nRows, 1);
    messages           = zeros(nRows, 1);
    reassignmentDelay  = zeros(nRows, 1);
    recoverySuccessPct = zeros(nRows, 1);

    idx = 0;
    for seed = cfg.seeds
        scenario = makeScenario(cfg, seed);
        rC = runCentral(cfg, scenario);
        rH = runHybrid (cfg, scenario);
        mC = calcMetrics(rC);
        mH = calcMetrics(rH);

        idx = idx + 1;
        scenarios{idx}          = scenarioName;
        seeds(idx)              = seed;
        methods{idx}            = 'central';
        completedPct(idx)       = mC.completedPct;
        messages(idx)           = mC.messages;
        reassignmentDelay(idx)  = mC.reassignmentDelay;
        recoverySuccessPct(idx) = mC.recoverySuccessPct;

        idx = idx + 1;
        scenarios{idx}          = scenarioName;
        seeds(idx)              = seed;
        methods{idx}            = 'hybrid';
        completedPct(idx)       = mH.completedPct;
        messages(idx)           = mH.messages;
        reassignmentDelay(idx)  = mH.reassignmentDelay;
        recoverySuccessPct(idx) = mH.recoverySuccessPct;
    end

    % Создание таблицы сырых данных
    raw = table(scenarios, seeds, methods, completedPct, messages, ...
                reassignmentDelay, recoverySuccessPct, ...
        'VariableNames', {'scenario','seed','method','completedPct', ...
                          'messages','reassignmentDelay','recoverySuccessPct'});
                      
    % Используем ';' для корректного отображения в русском Excel
    writetable(raw, fullfile('results', sprintf('raw_%s.csv', scenarioName)), 'Delimiter', ';');

    % --- Сводка по методам ---
    methodNames = {'central', 'hybrid'};
    nMethods    = numel(methodNames);

    sumMethod               = cell(nMethods, 1);
    completedPct_mean       = zeros(nMethods, 1);
    completedPct_std        = zeros(nMethods, 1);
    messages_mean           = zeros(nMethods, 1);
    messages_std            = zeros(nMethods, 1);
    reassignmentDelay_mean  = zeros(nMethods, 1);
    recoverySuccessPct_mean = zeros(nMethods, 1);

    for i = 1:nMethods
        mask = strcmp(raw.method, methodNames{i});
        sumMethod{i}               = methodNames{i};
        completedPct_mean(i)       = mean(raw.completedPct(mask));
        completedPct_std(i)        = std (raw.completedPct(mask));
        messages_mean(i)           = mean(raw.messages(mask));
        messages_std(i)            = std (raw.messages(mask));
        reassignmentDelay_mean(i)  = mean(raw.reassignmentDelay(mask), 'omitnan');
        recoverySuccessPct_mean(i) = mean(raw.recoverySuccessPct(mask), 'omitnan');
    end

    summary = table(sumMethod, completedPct_mean, completedPct_std, ...
                    messages_mean, messages_std, ...
                    reassignmentDelay_mean, recoverySuccessPct_mean, ...
        'VariableNames', {'method', 'completedPct_mean', 'completedPct_std', ...
                          'messages_mean', 'messages_std', ...
                          'reassignmentDelay_mean', 'recoverySuccessPct_mean'});
                      
    writetable(summary, fullfile('results', sprintf('summary_%s.csv', scenarioName)), 'Delimiter', ';');

    % --- Парные разницы ---
    p_seed                 = cfg.seeds(:);
    p_d_completedPct       = zeros(nSeeds, 1);
    p_d_messages           = zeros(nSeeds, 1);
    p_d_reassignmentDelay  = zeros(nSeeds, 1);
    p_d_recoverySuccessPct = zeros(nSeeds, 1);

    for i = 1:nSeeds
        seed = cfg.seeds(i);
        cRow = raw(strcmp(raw.method, 'central') & raw.seed == seed, :);
        hRow = raw(strcmp(raw.method, 'hybrid')  & raw.seed == seed, :);

        p_d_completedPct(i)       = hRow.completedPct       - cRow.completedPct;
        p_d_messages(i)           = hRow.messages           - cRow.messages;
        p_d_reassignmentDelay(i)  = hRow.reassignmentDelay  - cRow.reassignmentDelay;
        p_d_recoverySuccessPct(i) = hRow.recoverySuccessPct - cRow.recoverySuccessPct;
    end

    paired = table(p_seed, p_d_completedPct, p_d_messages, ...
                   p_d_reassignmentDelay, p_d_recoverySuccessPct, ...
        'VariableNames', {'seed','d_completedPct','d_messages', ...
                          'd_reassignmentDelay','d_recoverySuccessPct'});
                      
    writetable(paired, fullfile('results', sprintf('paired_%s.csv', scenarioName)), 'Delimiter', ';');

    fprintf('  %s: completedPct %.2f%% (central) vs %.2f%% (hybrid)\n', ...
        scenarioName, completedPct_mean(1), completedPct_mean(2));
end
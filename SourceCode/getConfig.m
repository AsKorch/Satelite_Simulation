function cfg = getConfig(scenarioName)

    cfg.N             = 20;
    cfg.T             = 200;
    cfg.numTasks      = 100;
    cfg.clusterSize   = 5;
    cfg.numClusters   = ceil(cfg.N / cfg.clusterSize);
    cfg.taskDuration  = 10;
    cfg.deadlineSlack = 20;
    cfg.maxQueuePerSat = 3;

    cfg.groundDelay       = 2;   % Земля -> получатель
    cfg.groundDetectDelay = 2;   % центр узнаёт об отказе
    cfg.leaderDetectDelay = 1;   % кластер узнаёт об отказе
    cfg.localHop          = 1;   % лидер -> аппарат

    % --- Модель энергии и связности (вариант Б) ---
    cfg.eTaskDrain = 0.005;   % расход энергии за такт выполнения задачи
    cfg.eIdleRegen = 0.0002;  % восстановление энергии в простое (за такт)
    cfg.eMin       = 0.05;    % порог, ниже которого аппарат не выбирается лидером
    cfg.cBase      = 0.5;     % базовая связность
    cfg.cAmp       = 0.5;     % амплитуда колебаний связности
    cfg.cPeriod    = 100;     % период колебаний (такты)
    cfg.cPhaseStep = 7;       % фазовый сдвиг на каждый аппарат

    cfg.seeds = 1:20;
    cfg.scenarioName = scenarioName;

    cfg.failureTick       = NaN;
    cfg.failedSatIds      = [];
    cfg.outageStart       = NaN;
    cfg.outageEnd         = NaN;
    cfg.numLocalDiscoveries = 0;

    switch scenarioName
        case 'NORMAL'
        case 'NODE_FAILURE'
            cfg.failureTick = 100;
        case 'LEADER_FAILURE'
            cfg.failureTick = 100;
        case 'GROUND_OUTAGE'
            cfg.outageStart = 80;
            cfg.outageEnd   = 120;
            cfg.numLocalDiscoveries = 10;
    end
end
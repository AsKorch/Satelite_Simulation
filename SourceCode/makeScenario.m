function scenario = makeScenario(cfg, seed)

    rng(seed, 'twister');

    sats = struct('id',{},'alive',{},'cluster',{},'capability',{}, ...
                  'energy',{},'connectivity',{},'queue',{}, ...
                  'activeTask',{},'progress',{});
    for i = 1:cfg.N
        sats(i).id = i;
        sats(i).alive = true;
        sats(i).cluster = ceil(i / cfg.clusterSize);
        sats(i).capability = mod(i-1, 3) + 1;
        sats(i).energy = 1.0;
        sats(i).connectivity = cfg.cBase;   % будет пересчитываться в runHybrid
        sats(i).queue = [];
        sats(i).activeTask = NaN;
        sats(i).progress = 0;
    end

    clusters = struct('id',{},'memberIds',{},'leaderId',{}, ...
                      'taskQueue',{},'electionActive',{},'electionFinishTick',{});
    for c = 1:cfg.numClusters
        clusters(c).id = c;
        clusters(c).memberIds = find([sats.cluster] == c);
        clusters(c).leaderId = clusters(c).memberIds(1);
        clusters(c).taskQueue = [];
        clusters(c).electionActive = false;
        clusters(c).electionFinishTick = NaN;
    end

    % Отказ
    failedSatIds = [];
    if ~isnan(cfg.failureTick)
        if strcmp(cfg.scenarioName, 'NODE_FAILURE')
            leaderIds = [clusters.leaderId];
            cand = setdiff(1:cfg.N, leaderIds);
            failedSatIds = cand(mod(seed-1, numel(cand)) + 1);
        elseif strcmp(cfg.scenarioName, 'LEADER_FAILURE')
            targetCluster = mod(seed-1, cfg.numClusters) + 1;
            failedSatIds = clusters(targetCluster).leaderId;
        end
    end

    % Задачи
    tasks = struct('id',{},'releaseTick',{},'deadline',{},'duration',{}, ...
                   'type',{},'originCluster',{},'status',{},'assignedTo',{}, ...
                   'finishTick',{},'groundVisibleTick',{},'localDiscovery',{}, ...
                   'disruptedTick',{},'reassignedTick',{}, 'clusterId', {}, 'arriveTick', {});
    for k = 1:cfg.numTasks
        tasks(k).id = k;
        tasks(k).releaseTick = randi([1, max(1, cfg.T - 50)]);
        tasks(k).duration = cfg.taskDuration;
        tasks(k).deadline = tasks(k).releaseTick + cfg.taskDuration + cfg.deadlineSlack;
        tasks(k).type = randi(3);
        tasks(k).originCluster = randi(cfg.numClusters);
        tasks(k).status = 'pending';
        tasks(k).assignedTo = NaN;
        tasks(k).finishTick = NaN;
        tasks(k).localDiscovery = false;
        tasks(k).disruptedTick = NaN;
        tasks(k).reassignedTick = NaN;
        tasks(k).clusterId = NaN;    % Куда направлять задачу при отказе
        tasks(k).arriveTick = inf;   % Такт прибытия команды
    end

    % Разрыв связи
    groundAvailable = true(1, cfg.T);
    if ~isnan(cfg.outageStart)
        groundAvailable(cfg.outageStart:cfg.outageEnd) = false;

        % Задачи, попавшие в окно разрыва, помечаем как локально обнаруженные
        inWindow = find([tasks.releaseTick] >= cfg.outageStart & ...
                        [tasks.releaseTick] <= cfg.outageEnd);
        nLocal = min(cfg.numLocalDiscoveries, numel(inWindow));
        if nLocal > 0
            pick = inWindow(randperm(numel(inWindow), nLocal));
            for k = pick
                tasks(k).localDiscovery = true;
            end
        end
    end

    % Когда каждая задача «видна» Земле
    for k = 1:numel(tasks)
        rt = tasks(k).releaseTick;
        if ~isnan(cfg.outageStart) && rt >= cfg.outageStart && rt <= cfg.outageEnd
            tasks(k).groundVisibleTick = cfg.outageEnd + 1 + cfg.groundDelay;
        else
            tasks(k).groundVisibleTick = rt + cfg.groundDelay;
        end
    end

    scenario = struct('cfg', cfg, 'seed', seed, ...
        'sats', sats, 'tasks', tasks, 'clusters', clusters, ...
        'groundAvailable', groundAvailable, ...
        'failureTick', cfg.failureTick, 'failedSatIds', failedSatIds, ...
        'outageStart', cfg.outageStart, 'outageEnd', cfg.outageEnd);
end
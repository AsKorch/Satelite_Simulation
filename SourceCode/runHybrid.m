function result = runHybrid(cfg, scenario)

    sats     = scenario.sats;
    tasks    = scenario.tasks;
    clusters = scenario.clusters;
    T        = cfg.T;
    ground   = scenario.groundAvailable;

    msgs = 0;

    for t = 1:T

        % 1. Отказ
        if ~isnan(scenario.failureTick) && t == scenario.failureTick
            for sid = scenario.failedSatIds
                sats(sid).alive = false;
                c = sats(sid).cluster;

                if ~isnan(sats(sid).activeTask)
                    tid = sats(sid).activeTask;
                    tasks(tid).status = 'cluster_transit'; % Задача летит к лидеру
                    tasks(tid).assignedTo = NaN;
                    tasks(tid).disruptedTick = t;
                    tasks(tid).arriveTick = t + cfg.leaderDetectDelay;
                    tasks(tid).clusterId = c;
                end
                for qid = sats(sid).queue
                    tasks(qid).status = 'cluster_transit';
                    tasks(qid).assignedTo = NaN;
                    tasks(qid).disruptedTick = t;
                    tasks(qid).arriveTick = t + cfg.leaderDetectDelay;
                    tasks(qid).clusterId = c;
                end
                sats(sid).queue = [];
                sats(sid).activeTask = NaN;
                sats(sid).progress = 0;

                if clusters(c).leaderId == sid
                    clusters(c).leaderId = NaN;
                    clusters(c).electionActive = true;
                    clusters(c).electionFinishTick = t + cfg.leaderDetectDelay + 1;
                end
            end
        end

        % 1.5. Обновление связности (детерминированная периодическая функция)
        for sid = 1:cfg.N
            if ~sats(sid).alive, continue; end
            c_val = cfg.cBase + cfg.cAmp * ...
                sin(2*pi*(t + cfg.cPhaseStep*sid) / cfg.cPeriod);
            sats(sid).connectivity = max(0, min(1, c_val));
        end

        % 2. Выборы лидера
        for c = 1:numel(clusters)
            if clusters(c).electionActive && t >= clusters(c).electionFinishTick
                bestId = NaN; bestS = -inf;
                for sid = clusters(c).memberIds
                    if ~sats(sid).alive, continue; end
                    if sats(sid).energy < cfg.eMin, continue; end  % исчерпан — не лидер
                    E = sats(sid).energy;
                    C = sats(sid).connectivity;
                    L = numel(sats(sid).queue) / cfg.maxQueuePerSat;
                    S = 0.4*E + 0.3*C - 0.3*L;
                    if S > bestS || (S == bestS && (isnan(bestId) || sid < bestId))
                        bestS = S; bestId = sid;
                    end
                end
                if ~isnan(bestId)
                    clusters(c).leaderId     = bestId;
                    clusters(c).electionActive = false;
                    msgs = msgs + 1;
                end
            end
        end

        % 3. Локальное обнаружение
        for k = 1:numel(tasks)
            if ~tasks(k).localDiscovery, continue; end
            if ~strcmp(tasks(k).status, 'pending'), continue; end
            if tasks(k).releaseTick + 1 > t, continue; end
            c = tasks(k).originCluster;
            if isnan(clusters(c).leaderId), continue; end

            tasks(k).status = 'in_cluster_queue';
            clusters(c).taskQueue(end+1) = k;
        end

        % 3.5. Задачи доходят до кластера после отказа
        for k = 1:numel(tasks)
            if ~strcmp(tasks(k).status, 'cluster_transit'), continue; end
            if tasks(k).arriveTick > t, continue; end
            tasks(k).status = 'in_cluster_queue';
            c = tasks(k).clusterId;
            clusters(c).taskQueue(end+1) = k;
        end

        % 4. Диспетчеризация из центра
        if ground(t)
            for k = 1:numel(tasks)
                if ~strcmp(tasks(k).status, 'pending'), continue; end
                if tasks(k).groundVisibleTick > t, continue; end
                c = tasks(k).originCluster;
                if isnan(clusters(c).leaderId), continue; end

                tasks(k).status = 'dispatch_transit';
                tasks(k).arriveTick = t + cfg.groundDelay;
                msgs = msgs + 1;
            end
        end

        % 5. Задачи доходят до кластера от центра
        for k = 1:numel(tasks)
            if ~strcmp(tasks(k).status, 'dispatch_transit'), continue; end
            if tasks(k).arriveTick > t, continue; end
            tasks(k).status = 'in_cluster_queue';
            c = tasks(k).originCluster;
            clusters(c).taskQueue(end+1) = k;
        end

        % 6. Лидер раздаёт задачи
        for c = 1:numel(clusters)
            leader = clusters(c).leaderId;
            if isnan(leader) || ~sats(leader).alive, continue; end

            keep = true(size(clusters(c).taskQueue));
            for qi = 1:numel(clusters(c).taskQueue)
                k = clusters(c).taskQueue(qi);
                if ~strcmp(tasks(k).status, 'in_cluster_queue'), continue; end

                bestSat = 0; bestQ = inf;
                for sid = clusters(c).memberIds
                    s = sats(sid);
                    if ~s.alive, continue; end
                    if s.capability ~= tasks(k).type, continue; end
                    if numel(s.queue) >= cfg.maxQueuePerSat, continue; end
                    qlen = numel(s.queue);
                    if qlen < bestQ || (qlen == bestQ && sid < bestSat)
                        bestQ = qlen; bestSat = sid;
                    end
                end

                if bestSat > 0
                    tasks(k).status = 'in_transit';
                    tasks(k).assignedTo = bestSat;
                    tasks(k).arriveTick = t + cfg.localHop;
                    % Фиксируем время переназначения по факту ДОСТАВКИ
                    if isnan(tasks(k).reassignedTick) && ~isnan(tasks(k).disruptedTick)
                        tasks(k).reassignedTick = tasks(k).arriveTick;
                    end
                    msgs = msgs + 1;
                    keep(qi) = false;
                end
            end
            clusters(c).taskQueue = clusters(c).taskQueue(keep);
        end

        % 7. Прибытие к аппарату
        for k = 1:numel(tasks)
            if ~strcmp(tasks(k).status, 'in_transit'), continue; end
            if tasks(k).arriveTick > t, continue; end
            sid = tasks(k).assignedTo;
            if sats(sid).alive
                sats(sid).queue(end+1) = k;
                tasks(k).status = 'queued';
                msgs = msgs + 1;
            else
                c = sats(sid).cluster;
                tasks(k).status = 'in_cluster_queue';
                clusters(c).taskQueue(end+1) = k;
            end
        end

        % 8. Исполнение
        for sid = 1:cfg.N
            if ~sats(sid).alive, continue; end
            if isnan(sats(sid).activeTask) && ~isempty(sats(sid).queue)
                nid = sats(sid).queue(1);
                sats(sid).queue(1) = [];
                sats(sid).activeTask = nid;
                sats(sid).progress = 0;
                tasks(nid).status = 'running';
            end
            if ~isnan(sats(sid).activeTask)
                sats(sid).progress = sats(sid).progress + 1;
                nid = sats(sid).activeTask;
                if sats(sid).progress >= tasks(nid).duration
                    tasks(nid).status = 'completed';
                    tasks(nid).finishTick = t;
                    sats(sid).activeTask = NaN;
                    sats(sid).progress = 0;
                    msgs = msgs + 1;
                end
            end
        end

        % 9. Обновление энергии
        for sid = 1:cfg.N
            if ~sats(sid).alive, continue; end
            if ~isnan(sats(sid).activeTask)
                sats(sid).energy = max(0, sats(sid).energy - cfg.eTaskDrain);
            else
                sats(sid).energy = min(1, sats(sid).energy + cfg.eIdleRegen);
            end
        end

    end

    result = struct('tasks', tasks, 'sats', sats, 'messages', msgs, ...
                    'method', 'hybrid', 'clusters', clusters);
end
function result = runCentral(cfg, scenario)

    sats  = scenario.sats;
    tasks = scenario.tasks;
    T     = cfg.T;
    ground = scenario.groundAvailable;

    msgs = 0;

    for t = 1:T

        % 1. Отказ
        if ~isnan(scenario.failureTick) && t == scenario.failureTick
            for sid = scenario.failedSatIds
                sats(sid).alive = false;
                if ~isnan(sats(sid).activeTask)
                    tid = sats(sid).activeTask;
                    tasks(tid).status = 'pending';
                    tasks(tid).assignedTo = NaN;
                    tasks(tid).disruptedTick = t;
                    tasks(tid).groundVisibleTick = t + cfg.groundDetectDelay;
                end
                for qid = sats(sid).queue
                    tasks(qid).status = 'pending';
                    tasks(qid).assignedTo = NaN;
                    tasks(qid).disruptedTick = t;
                    tasks(qid).groundVisibleTick = t + cfg.groundDetectDelay;
                end
                sats(sid).queue = [];
                sats(sid).activeTask = NaN;
                sats(sid).progress = 0;
            end
        end

        % 2. Наземный центр отправляет назначения
        if ground(t)
            for k = 1:numel(tasks)
                if ~strcmp(tasks(k).status, 'pending'), continue; end
                if tasks(k).groundVisibleTick > t, continue; end

                bestSat = 0; bestQ = inf;
                for sid = 1:cfg.N
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
                    tasks(k).arriveTick = t + cfg.groundDelay;
                    % Фиксируем время переназначения по факту ДОСТАВКИ
                    if isnan(tasks(k).reassignedTick) && ~isnan(tasks(k).disruptedTick)
                        tasks(k).reassignedTick = tasks(k).arriveTick;
                    end
                    msgs = msgs + 1;
                end
            end
        end

        % 3. Прибытие
        for k = 1:numel(tasks)
            if ~strcmp(tasks(k).status, 'in_transit'), continue; end
            if tasks(k).arriveTick > t, continue; end
            sid = tasks(k).assignedTo;
            if sats(sid).alive
                sats(sid).queue(end+1) = k;
                tasks(k).status = 'queued';
                msgs = msgs + 1;
            else
                tasks(k).status = 'pending';
                tasks(k).groundVisibleTick = t + cfg.groundDetectDelay;
            end
        end

        % 4. Исполнение
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

        % 5. Обновление энергии (в централизованной схеме энергия
        %    не влияет на назначение задач, но моделируется для
        %    сопоставимости физической модели с гибридной архитектурой)
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
                    'method', 'central', 'clusters', []);
end
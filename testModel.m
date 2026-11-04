function testModel()
% Проверки инвариантов на маленьком N.

    cfg = getConfig('NORMAL');
    cfg.N = 5; cfg.T = 100; cfg.numTasks = 10;
    cfg.clusterSize = 2; cfg.numClusters = 3;

    for seed = 1:3
        sc = makeScenario(cfg, seed);
        for method = {'central', 'hybrid'}
            if strcmp(method{1}, 'central')
                r = runCentral(cfg, sc);
            else
                r = runHybrid(cfg, sc);
            end

            % 1. Завершённая задача не должна быть в очереди или активной
            for k = 1:numel(r.tasks)
                if strcmp(r.tasks(k).status, 'completed')
                    for s = r.sats
                        assert(isempty(s.queue) || ~any(s.queue == k), ...
                            sprintf('task %d completed but in queue of sat %d', k, s.id));
                        assert(isnan(s.activeTask) || s.activeTask ~= k, ...
                            sprintf('task %d completed but active on sat %d', k, s.id));
                    end
                end
            end

            % 2. Нет дубликатов в очереди спутника
            for s = r.sats
                assert(numel(unique(s.queue)) == numel(s.queue), ...
                    sprintf('duplicate taskId in queue of sat %d', s.id));
            end

            % 3. Нет назначения dead-спутнику (для running/queued)
            for k = 1:numel(r.tasks)
                if strcmp(r.tasks(k).status, 'running') || strcmp(r.tasks(k).status, 'queued')
                    sid = r.tasks(k).assignedTo;
                    assert(r.sats(sid).alive, ...
                        sprintf('task %d assigned to dead sat %d', k, sid));
                end
            end

            % 4. У спутника не более одной активной задачи
            for s = r.sats
                assert(isnan(s.activeTask) || isscalar(s.activeTask), ...
                    'multiple active tasks');
            end

            % 5. Учёт задач: completed <= released
            nDone = sum(strcmp({r.tasks.status}, 'completed'));
            assert(nDone <= numel(r.tasks), 'more completed than released');

            % 6. Энергия в диапазоне [0, 1]
            for s = r.sats
                assert(s.energy >= 0 && s.energy <= 1, ...
                    sprintf('energy out of range: sat %d, E = %.4f', s.id, s.energy));
            end

            % 7. Связность в диапазоне [0, 1] (только для гибридной)
            if strcmp(method{1}, 'hybrid')
                for s = r.sats
                    if ~s.alive, continue; end
                    assert(s.connectivity >= 0 && s.connectivity <= 1, ...
                        sprintf('connectivity out of range: sat %d, C = %.4f', ...
                                s.id, s.connectivity));
                end
            end

            % 8. Лидер кластера жив и имеет энергию выше порога
            if strcmp(method{1}, 'hybrid')
                for c = 1:numel(r.clusters)
                    if ~isnan(r.clusters(c).leaderId)
                        lid = r.clusters(c).leaderId;
                        assert(r.sats(lid).alive, ...
                            sprintf('leader %d is dead', lid));
                        assert(r.sats(lid).energy >= cfg.eMin, ...
                            sprintf('leader %d has energy below threshold', lid));
                    end
                end
            end

            % 9. Воспроизводимость
            if strcmp(method{1}, 'central')
                r2 = runCentral(cfg, sc);
            else
                r2 = runHybrid(cfg, sc);
            end
            assert(r.messages == r2.messages, 'not reproducible (messages)');
        end
    end

    fprintf('testModel: ALL OK\n');
end
function m = calcMetrics(result)

    tasks = result.tasks;

    finishTicks = [tasks.finishTick];
    deadlines   = [tasks.deadline];

    completed = ~isnan(finishTicks);
    onTime    = completed & (finishTicks <= deadlines);

    m.completedPct = 100 * sum(onTime) / numel(tasks);
    m.completed    = sum(onTime);
    m.messages     = result.messages;

    disrupted = find(~isnan([tasks.disruptedTick]));
    if isempty(disrupted)
        m.reassignmentDelay  = NaN;
        m.recoverySuccessPct = NaN;
    else
        d = [tasks(disrupted).reassignedTick] - [tasks(disrupted).disruptedTick];
        d = d(~isnan(d));
        if isempty(d)
            m.reassignmentDelay = NaN;
        else
            m.reassignmentDelay = mean(d);
        end

        recov = false(size(disrupted));
        for i = 1:numel(disrupted)
            k = disrupted(i);
            recov(i) = completed(k) && finishTicks(k) <= deadlines(k);
        end
        m.recoverySuccessPct = 100 * sum(recov) / numel(disrupted);
    end
end
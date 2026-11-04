function main()

    fprintf('=== Тест модели ===\n');
    testModel();

    scenarios = {'NORMAL', 'NODE_FAILURE', 'LEADER_FAILURE', 'GROUND_OUTAGE'};
    for i = 1:numel(scenarios)
        fprintf('\n=== %s ===\n', scenarios{i});
        tic;
        runExperiment(scenarios{i});
        plotAll(scenarios{i});
        fprintf('  done in %.1f s\n', toc);
    end

    fprintf('\nВсе файлы в results/ и figures/.\n');
end
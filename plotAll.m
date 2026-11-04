function plotAll(scenarioName)

    if nargin < 1
        scenarios = {'NORMAL', 'NODE_FAILURE', 'LEADER_FAILURE', 'GROUND_OUTAGE'};
        for i = 1:numel(scenarios)
            plotAll(scenarios{i});
        end
        return;
    end

    prettyName = strrep(scenarioName, '_', ' ');
    if ~exist('results', 'dir'), mkdir('results'); end
    if ~exist('figures', 'dir'), mkdir('figures'); end

    S = readtable(fullfile('results', sprintf('summary_%s.csv', scenarioName)));
    P = readtable(fullfile('results', sprintf('paired_%s.csv', scenarioName)));

    % === 1. Завершенные задачи ===
    h = figure('Color','w','Position',[100 100 780 480]);
    ax = axes(h); hold(ax,'on');
    b = bar(ax, 1:2, S.completedPct_mean, 0.6);
    b.FaceColor = [0.30 0.50 0.80]; b.EdgeColor = 'k';
    errorbar(ax, 1:2, S.completedPct_mean, S.completedPct_std, ...
             'k.', 'CapSize', 12, 'LineWidth', 1.2);
    set(ax, 'XTick', 1:2, 'XTickLabel', S.method);
    ylim(ax, [0 118]);
    ylabel(ax, 'Доля задач, %');
    title(ax, sprintf('%s: Доля задач, выполненных в срок', prettyName));
    styleAxes(ax);
    for i = 1:2
        yTop = S.completedPct_mean(i) + S.completedPct_std(i) + 4;
        text(ax, i, yTop, ...
            sprintf('%.2f ± %.2f', S.completedPct_mean(i), S.completedPct_std(i)), ...
            'HorizontalAlignment','center', 'VerticalAlignment','bottom', ...
            'FontSize', 12, 'Color', 'k', 'FontWeight', 'bold', ...
            'Interpreter', 'none');
    end
    saveFigure(h, sprintf('fig_%s_completed', scenarioName));

    % === 2. Служебные сообщения ===
    h = figure('Color','w','Position',[100 100 780 480]);
    ax = axes(h); hold(ax,'on');
    b = bar(ax, 1:2, S.messages_mean, 0.6);
    b.FaceColor = [0.80 0.40 0.30]; b.EdgeColor = 'k';
    errorbar(ax, 1:2, S.messages_mean, S.messages_std, ...
             'k.', 'CapSize', 12, 'LineWidth', 1.2);
    set(ax, 'XTick', 1:2, 'XTickLabel', S.method);
    ylabel(ax, 'Количество сообщений, шт.');
    title(ax, sprintf('%s: Количество управляющих сообщений', prettyName));
    styleAxes(ax);
    for i = 1:2
        yTop = S.messages_mean(i) + S.messages_std(i) + ...
               0.05 * max(S.messages_mean + S.messages_std);
        text(ax, i, yTop, ...
            sprintf('%.2f ± %.2f', S.messages_mean(i), S.messages_std(i)), ...
            'HorizontalAlignment','center', 'VerticalAlignment','bottom', ...
            'FontSize', 12, 'Color', 'k', 'FontWeight', 'bold', ...
            'Interpreter', 'none');
    end
    ylim(ax, [0, 1.20 * max(S.messages_mean + S.messages_std)]);
    saveFigure(h, sprintf('fig_%s_messages', scenarioName));

    % === Дополнительные графики для сценариев с отказом ===
    if contains(scenarioName, 'FAILURE')

        % 3. Задержка переназначения
        h = figure('Color','w','Position',[100 100 780 480]);
        ax = axes(h); hold(ax,'on');
        vals = S.reassignmentDelay_mean; vals(isnan(vals)) = 0;
        b = bar(ax, 1:2, vals, 0.6);
        b.FaceColor = [0.55 0.65 0.45]; b.EdgeColor = 'k';
        set(ax, 'XTick', 1:2, 'XTickLabel', S.method);
        ylabel(ax, 'Задержка, такты');
        title(ax, sprintf('%s: Средняя задержка переназначения задач', prettyName));
        styleAxes(ax);
        maxVal = max(vals); if maxVal == 0, maxVal = 1; end
        ylim(ax, [0, maxVal * 1.35]);
        for i = 1:2
            text(ax, i, vals(i) + maxVal * 0.06, ...
                sprintf('%.2f', S.reassignmentDelay_mean(i)), ...
                'HorizontalAlignment','center', 'VerticalAlignment','bottom', ...
                'FontSize', 12, 'Color', 'k', 'FontWeight', 'bold', ...
                'Interpreter', 'none');
        end
        saveFigure(h, sprintf('fig_%s_delay', scenarioName));

        % 4. Успешные восстановления
        h = figure('Color','w','Position',[100 100 780 480]);
        ax = axes(h); hold(ax,'on');
        b = bar(ax, 1:2, S.recoverySuccessPct_mean, 0.6);
        b.FaceColor = [0.55 0.65 0.45]; b.EdgeColor = 'k';
        set(ax, 'XTick', 1:2, 'XTickLabel', S.method);
        ylim(ax, [0 110]);
        ylabel(ax, 'Восстановлено, %');
        title(ax, sprintf('%s: Доля успешно восстановленных задач', prettyName));
        styleAxes(ax);
        for i = 1:2
            yTop = S.recoverySuccessPct_mean(i) + 5;
            text(ax, i, yTop, ...
                sprintf('%.2f', S.recoverySuccessPct_mean(i)), ...
                'HorizontalAlignment','center', 'VerticalAlignment','bottom', ...
                'FontSize', 12, 'Color', 'k', 'FontWeight', 'bold', ...
                'Interpreter', 'none');
        end
        saveFigure(h, sprintf('fig_%s_recovery', scenarioName));
    end

    % === 5. Парные разницы ===
    h = figure('Color','w','Position',[100 100 1100 480]);
    ax1 = subplot(1,2,1); hold(ax1,'on');
    plot(ax1, P.seed, P.d_completedPct, 'o', 'MarkerSize', 8, ...
         'MarkerFaceColor', [0.30 0.50 0.80], 'MarkerEdgeColor','k');
    yline(ax1, mean(P.d_completedPct, 'omitnan'), 'r-', 'LineWidth', 1.5);
    yline(ax1, 0, 'k--');
    xlabel(ax1, 'Номер случайного прогона (seed)');
    ylabel(ax1, 'Разница, п.п.');
    title(ax1, sprintf('%s: разница долей (Гибрид − Центр)', prettyName));
    styleAxes(ax1);
    % Небольшой отступ по Y, чтобы точки не прилипали к рамке
    yl1 = ylim(ax1); pad1 = 0.08 * max(1, yl1(2) - yl1(1));
    ylim(ax1, [yl1(1) - pad1, yl1(2) + pad1]);

    ax2 = subplot(1,2,2); hold(ax2,'on');
    plot(ax2, P.seed, P.d_messages, 'o', 'MarkerSize', 8, ...
         'MarkerFaceColor', [0.80 0.40 0.30], 'MarkerEdgeColor','k');
    yline(ax2, mean(P.d_messages, 'omitnan'), 'r-', 'LineWidth', 1.5);
    yline(ax2, 0, 'k--');
    xlabel(ax2, 'Номер случайного прогона (seed)');
    ylabel(ax2, 'Разница, шт.');
    title(ax2, sprintf('%s: разница сообщений (Гибрид − Центр)', prettyName));
    styleAxes(ax2);
    yl2 = ylim(ax2); pad2 = 0.08 * max(1, yl2(2) - yl2(1));
    ylim(ax2, [yl2(1) - pad2, yl2(2) + pad2]);

    saveFigure(h, sprintf('fig_%s_paired', scenarioName));
end

function styleAxes(ax)
    set(ax, 'Color', 'w', 'XColor', 'k', 'YColor', 'k', ...
            'GridColor', [0.15 0.15 0.15], 'GridAlpha', 0.6, ...
            'FontSize', 12, 'FontName', 'Arial', 'Box', 'on', 'LineWidth', 1);
    set(get(ax,'XLabel'), 'Color', 'k', 'FontWeight', 'bold', 'Interpreter', 'none');
    set(get(ax,'YLabel'), 'Color', 'k', 'FontWeight', 'bold', 'Interpreter', 'none');
    set(get(ax,'Title'),  'Color', 'k', 'FontWeight', 'bold', 'Interpreter', 'none');
    grid(ax, 'on');
end

function saveFigure(h, name)
    if ~exist('figures', 'dir'), mkdir('figures'); end
    set(h, 'Color', 'w', 'InvertHardcopy', 'off');
    axs = findall(h, 'Type', 'axes');
    for i = 1:numel(axs)
        try, axs(i).Toolbar.Visible = 'off'; catch, end
    end
    if exist('exportgraphics', 'file')
        exportgraphics(h, fullfile('figures', [name '.png']), 'Resolution', 300);
    else
        print(h, fullfile('figures', [name '.png']), '-dpng', '-r300');
    end
    savefig(h, fullfile('figures', [name '.fig']));
    close(h);
    drawnow;
end
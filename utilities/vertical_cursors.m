function [hCur,hText] = vertical_cursors(figureObject,allAxes,allLines,hCur,hText)

    % Expansion from post: https://www.mathworks.com/matlabcentral/answers/1758-crosshairs-or-just-vertical-line-across-linked-axis-plots

    % Vertical Cursors function has 3 main part:
    % 1. set up click and unclick function
    % 2. Update The Text box on each line object
    %   When there is a new line, add the textbox. TODO: use 
    % 3. Update Cursor on each axis object
    %   numel(hCur) is equal to numel(allAxes). Each Axis contains 1 cursor
    set(figureObject, ...
       'WindowButtonDownFcn', @clickFcn, ...
       'WindowButtonUpFcn', @unclickFcn);

    % Set up cursor text
%     allLines = findobj(gcf, 'type', 'line');
    update_cursor = false;
    if isempty(hText)
        hText = nan(1, length(allLines));
        for id = 1:length(allLines)
            hText(id) = text(NaN, NaN, '', ...
                'Parent', get(allLines(id), 'Parent'), ...
                'BackgroundColor', 'yellow', ...
                'Color', get(allLines(id), 'Color'));
        end
    elseif length(allLines) > length(hText)
        update_cursor = true;
        for id = length(hText)+1:length(allLines)

            hText(id) = text(NaN, NaN, '', ...
                'Parent', get(allLines(id), 'Parent'), ...
                'BackgroundColor', 'yellow', ...
                'Color', get(allLines(id), 'Color'));
        end

    end

    % Set up cursor lines
%     allAxes = findobj(gcf, 'Type', 'axes');
    if isempty(hCur)
        hCur = nan(1, length(allAxes));
        for id = 1:length(allAxes)
            if isa(xlim(allAxes(id)), 'datetime') == 1
                x_lims = xlim(allAxes(id));
                %default_time = x_lims(1) + diff(x_lims) / 2; % Option A) use mid
                default_time = NaT('TimeZone',x_lims(1).TimeZone); % Option B) don't display at start
                nan_data = [default_time default_time];
            else
                nan_data = [NaN NaN];
            end
            hCur(id) = line(nan_data, ylim(allAxes(id)), ...
                'Color', 'black', 'Parent', allAxes(id));
        end

    elseif update_cursor && (length(allAxes) == length(hCur))

        % Update cursor ylimit
        for id = 1:length(allAxes)
            set(hCur(id),'YData',ylim(allAxes(id)));
        end
    elseif length(allAxes) > length(hCur)

        for id = length(hCur)+1:length(allAxes)
            if isa(xlim(allAxes(id)), 'datetime') == 1
                x_lims = xlim(allAxes(id));
                %default_time = x_lims(1) + diff(x_lims) / 2; % Option A) use mid
                default_time = NaT('TimeZone',x_lims(1).TimeZone); % Option B) don't display at start
                nan_data = [default_time default_time];
            else
                nan_data = [NaN NaN];
            end
            hCur(id) = line(nan_data, ylim(allAxes(id)), ...
                'Color', 'black', 'Parent', allAxes(id));
        end

    end

    function clickFcn(varargin)
        % Initiate cursor if clicked anywhere but the figure
        if strcmpi(get(gco, 'type'), 'figure')
            if isa(xlim(gca), 'datetime') == 1
                x_lims = xlim(gca);
                nan_time = NaT('TimeZone',x_lims(1).TimeZone);
                nan_data = [nan_time nan_time];
            else
                nan_data = [NaN NaN];
            end
            set(hCur, 'XData', nan_data);
            set(hText, 'Position', [NaN NaN]);
        else
            set(gcf, 'WindowButtonMotionFcn', @dragFcn)
            dragFcn()
        end
    end
    function dragFcn(varargin)
        % Get mouse location
        pt = get(gca, 'CurrentPoint');
        % Update cursor line position
        set(hCur, 'XData', [pt(1), pt(1)]);
        % Update cursor text
        idx_to_delete = [];
        for idx = 1:length(allLines)
            if isgraphics(allLines(idx))

                % If there isn't a text graphic, add one
                if ~isgraphics(hText(idx))
                    hText(idx) = text(NaN, NaN, '', ...
                        'Parent', get(allLines(idx), 'Parent'), ...
                        'BackgroundColor', 'yellow', ...
                        'Color', get(allLines(idx), 'Color'));
                end

                xdata = allLines(idx).XData;
                ydata = allLines(idx).YData;
                if isa(xlim(gca), 'datetime') == 1
                    if pt(1) >= get_date_xpos(xdata(1)) && pt(1) <= get_date_xpos(xdata(end))
                        x_lims = xlim(gca);
                        x = pt(1) + x_lims(1);
                        data_index = dsearchn(get_date_xpos(xdata'),get_date_xpos(x));
                        x_nearest = xdata(data_index);
                        y_nearest = ydata(data_index);
                        set(hText(idx), 'Position', [pt(1), y_nearest], ...
                            'String', sprintf('(%s, %0.2f)', datestr(x_nearest), y_nearest));
                        % y = interp1(get_date_xpos(xdata), ydata, pt(1));
                        % set(hText(idx), 'Position', [pt(1), y], ...
                        %     'String', sprintf('(%s, %0.2f)', datestr(pt(1)), y));
                    else
                        set(hText(idx), 'Position', [NaN NaN]);
                    end
                else
                    if pt(1) >= xdata(1) && pt(1) <= xdata(end)
                        y = interp1(xdata, ydata, pt(1));
                        set(hText(idx), 'Position', [pt(1), y], ...
                            'String', sprintf('(%0.2f, %0.2f)', pt(1), y));
                    else
                        set(hText(idx), 'Position', [NaN NaN]);
                    end
                end
            else
                idx_to_delete = [idx_to_delete,idx];
            end
        end

        % Clean up lines and text boxes if lines are deleted
        if ~isempty(idx_to_delete)
            for idx = idx_to_delete
                allLines(idx) = [];
                if isgraphics(hText(idx))
                    delete(hText(idx))
                    hText(idx) = [];
                end
            end
        end

    end
    function unclickFcn(varargin)
        set(gcf, 'WindowButtonMotionFcn', '');
    end

    function xpos = get_date_xpos(x_value)
        ax1 = gca;
        % dx_days = diff(ax1.XLim)/24;
        x_min = ax1.XLim(1);
        xpos = datenum(x_value - x_min);
    end
end
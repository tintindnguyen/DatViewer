classdef TimeSeriesFigure < handle
%
% TimeSeriesFigure handle is a custom figure to help analyzing simulation
% data. The figure can contain up to 6 panels to display data. Each panel 
% has an axis displaying line data and a data display UIPanel.
%
% Usage Example:
%   ts = TimeSeriesFigure(6);
%   return a ts object and a figure with 6 panels

    properties
        NumberPanels (1,1) double % Input number of panels
    end

    properties
        
        hFig  % Output figure handle
        hAxes matlab.graphics.axis.Axes % Output axes handle
        hCursor (1,6) matlab.graphics.chart.decoration.ConstantLine % Output cursor line handle
        hControl matlab.ui.container.Panel % Output UIPanel handle
        hTable matlab.ui.control.Table
        hPanel panel % Output panel class handle
        hLines (6,6) matlab.graphics.chart.primitive.Stair % Output stair line handles (MaxNumberLines,MaxNumberPanels)
        hLegend (1,6) matlab.graphics.illustration.Legend
        
    end

    properties ( GetAccess = public, SetAccess = private )
        MaxNumberPanels = 6;
        MaxNumberLines = 6;
    end
    properties ( Access = private )
        zoomPanel = false(1,6); % (1,MaxNumberPanels)
    end

    properties (Constant = true, Access = private)
        % constants for panels
        DefaultFigurePosition = [40 67 1200 900];
        AxesToControlRatio = 0.7;
        DefaultFontSize = 12;
        DefaultFontWeight = 'bold';

        % UI Control Panel Parameters
        DefaultButtonSize = [80 20];
        DefaultTableSize = [280 135];
        TableCol_Name = 1;
        TableCol_Value = 2;
        DefaultNButtons = 3; % Bad assumptions. TODO: change the button numbers dynamically with TimeSeriesInteractivePanel

        clr_hex = ["#00FF00"
               "#FF00FF"
               "#0072BD"
               "#7E2F8E"
               "#4DBEEE"
               "#A2142F"];
        str_format = {'%.6e','%.6f'};
        time_format = '%.4f';
    end

    properties ( Access=protected )
        % properties for cursor line
        assign_vertical_callback = true;
        tracked_lines = false(6,6); % (MaxNumberLines,MaxNumberPanels)
        hText (6,6) matlab.graphics.primitive.Text
        cursor_pt
        min_time_step (6,1)
        interpF
        last_xdata (6,6) = nan(6,6);
    end

    properties ( GetAccess=public, SetObservable, Hidden = true )
        cursor_status = false;
    end

    methods
       
        function obj = TimeSeriesFigure(NumberPanels)
            % constuctor initializes 1 to 6 panels.

            arguments
                NumberPanels (1,1) double
            end
            
            % Save number of panels
            obj.NumberPanels = NumberPanels;

            % Create a figure handle
            obj.hFig = figure();
            obj.hFig.Visible = 'off';
            obj.hFig.Position = obj.DefaultFigurePosition;
            obj.hFig.Name = "Configuration: " + NumberPanels + " Panels";
            set(obj.hFig,'KeyPressFcn',@obj.key_pressed_fcn);
            set(obj.hFig,'SizeChangedFcn',@obj.resize_figure_callback);
            set(obj.hFig,'CloseRequestFcn',@obj.close_figure_callback);

            % Create a panel handle and pack Time Series Panel and axes
            % onto the panels
            obj.hPanel = panel();
            obj.hPanel.pack(NumberPanels);
            for i = 1:NumberPanels
                obj.hPanel(i).pack('h',{obj.AxesToControlRatio []});
                u = TimeSeriesInteractivePanel();
                obj.hControl(i) = obj.hPanel(i,2).select(u);
            end

            % Set up all the axes
            obj.hAxes = obj.hPanel.select('all');
            linkaxes(obj.hAxes(:),'x'); % Link all axes together
            for i = 1:NumberPanels
                grid(obj.hAxes(i),'on');
                obj.hAxes(i).Tag = num2str(i);
                obj.hPanel(i,1).xlabel('Time (seconds)')
            end

            % save uiTable handle
            obj.hTable = findobj(obj.hControl,'Tag','DataViewer');

            % Set panels' font properties
            obj.hPanel.fontsize = obj.DefaultFontSize;
            obj.hPanel.fontweight = obj.DefaultFontWeight;

            % resize Control Panel
            obj.resize_hcontrol()

            % Turn figure on
            obj.hFig.Visible = 'on';

        end


    end

    methods( Access = public, Hidden = true )
       % public functions that share with other classes

        function update_panel_min_time_step(obj,panel_id)
            min_time_step_ = Inf;
            for i = 1:obj.MaxNumberLines
                if isgraphics(obj.hLines(i,panel_id))
                    delta_time_i = obj.hLines(i,panel_id).XData(2) - obj.hLines(i,panel_id).XData(1);
                    if delta_time_i < min_time_step_
                        min_time_step_ = delta_time_i;
                    end
                end
            end
            obj.min_time_step(panel_id) = min_time_step_;
        end

        function update_cursor_lines(obj)

            if ~isgraphics(obj.hFig) || obj.cursor_status == false
                return;
            end

            % 1. set up click and unclick function
            if obj.assign_vertical_callback == true
                set(obj.hFig, ...
                   'WindowButtonDownFcn', @obj.clickFcn, ...
                   'WindowButtonUpFcn', @obj.unclickFcn);
                obj.assign_vertical_callback = false;
            end

            % Check if there are new lines
            if ~isequal(isgraphics(obj.hLines), obj.tracked_lines)
                update_cursor_ = true;
            else
                update_cursor_ = false;
            end

            if update_cursor_

                % Identify new text boxes
                % 2. Update The Text box on each line object
                %   When there is a new line, add the textbox. TODO: use panel
                [hr,hc] = find(isgraphics(obj.hLines) - obj.tracked_lines);

                % track if new cursor added
                new_cursor = false(1,obj.NumberPanels);
                for i = 1:length(hr)
                    panel_id = hc(i);
                    line_id = hr(i);
%                     obj.hText(line_id,panel_id) = text(NaN, NaN, '', ...
%                         'Parent', get(obj.hLines(line_id,panel_id), 'Parent'), ...
%                         'BackgroundColor', 'w', ...
%                         'EdgeColor','b',...
%                         'Color', get(obj.hLines(line_id,panel_id), 'Color'));

                    % if a cursor hasn't been maded yet
                    % 3. Update Cursor on each axis object
                    %   numel(hCur) is equal to numel(allAxes). Each Axis contains 1 cursor
                    if isa(obj.hCursor(panel_id).Parent,'matlab.graphics.GraphicsPlaceholder')
                        new_cursor(panel_id) = true;
                        x_lims = xlim( obj.hAxes(panel_id) );
                        % check X data type
                        if isa(xlim( obj.hAxes(panel_id) ),'datetime')
                            %default_time = x_lims(1) + diff(x_lims) / 2; % Option A) use mid
                            default_time = NaT('TimeZone',x_lims(1).TimeZone); % Option B) don't display at start
                            default_x_value = [default_time default_time];
                        else
                            default_x_value = x_lims(1);
                        end

                        % Create a cursor
                        obj.hCursor(panel_id) = xline(obj.hAxes(panel_id),default_x_value, ...
                                            'LineWidth',2,...
                                            'Color', 'black');
                    end
                    % Mark tracked lines after created
                    obj.tracked_lines(line_id,panel_id) = true;
                end

                if any(new_cursor)
                    for i = find(new_cursor)
                        legend_str = string(obj.hLegend(i).String);
                        idx = ~contains(legend_str," - ");
                        obj.hLegend(i).String(idx) = [];
                    end
                end

            end

            % update griddied interp function for something special
            for i = 1:obj.NumberPanels
                for j = 1:obj.MaxNumberLines
                    if isvalid(obj.hLines(j,i))
                        idx = 1:length(obj.hLines(j,i).XData);
                        obj.interpF(i,j).idx2time = griddedInterpolant(idx,obj.hLines(j,i).XData,'previous','nearest');
                        obj.interpF(i,j).time2idx = griddedInterpolant(obj.hLines(j,i).XData,idx,'previous','nearest');
                        obj.last_xdata(i,j) = obj.hLines(j,i).XData(end);
                    end
                end
            end

        end

        function update_time_xlim(obj)
            % linkaxes function will set XLimMode to 'manual'
            
            % Find min and max
            min_val = Inf;
            max_val = -Inf;
            for i = 1:obj.NumberPanels

                if ~isempty(obj.hAxes(i).Children) && obj.hAxes(i).Visible == true
                    for ic = 1:length(obj.hAxes(i).Children)
                        if isa(obj.hAxes(i).Children(ic),'matlab.graphics.chart.primitive.Stair')
    
                            % if XData is a time vector, min_val_k and 
                            % max_val_k are the fisrt and last data points
                            min_val_k = obj.hAxes(i).Children(ic).XData(1);
                            max_val_k = obj.hAxes(i).Children(ic).XData(end);
                            if min_val_k < min_val
                                min_val = min_val_k;
                            end
    
                            if max_val_k > max_val
                                max_val = max_val_k;
                            end
                        end
                    end
                end
            end
            
            if min_val == Inf
                min_val = 0;
            end
            if max_val < min_val
                min_val = min_val + 1;
            end
            obj.hAxes(1).XLim = [min_val max_val];
            set(obj.hAxes,'XTickMode','auto');

        end

        function zoom(obj,AxisList)
            % focus on an axis or multiple axes
            %
            %   zoom(obj,AxisList)
            %       Zoom/Unzoom on an axis, multiple axes or reset all axes
            %
            %       AxisList accepts a scalar value, 1-D array, '', "" or []
            %       
            %       AxisList = '', "", or [] --> reset the axis
            %       AxisList = a scalar      --> zoom in on the selected axis
            %       AxisList = 1-D array     --> zoom in on the selected axes
            %
            %       If the axis is already zoomed and the same axis/axes
            %       is/are selected, the figure will unzoom the selected
            %       axis/axes
                
            %----------- Error Handling ------------------
            % Make sure AxisNumber is 1 dimension
            if size(AxisList,1) > 1 && size(AxisList,2) > 1
                error("Invalid input for zoom(): Zoom axis list must be a scalar or a 1-D vector");
            end
            % Make sure the number is inside the available NumberPanels
            if strcmp(AxisList,'') || isempty(AxisList) || (isstring(AxisList) && AxisList == "")
                resetZoom = true;
            else

                for i = 1:length(AxisList)

                    % When a user input a panel that is already zoom,
                    % set the panel's zoom state to false. Otherwise, set
                    % it to true
                    if AxisList(i) <= obj.NumberPanels
                        obj.zoomPanel(AxisList(i)) = ~obj.zoomPanel(AxisList(i));
                    end

                    
                    
                end
                
                % Check if all panels' zoom state are false, trigger reset
                % zoom
                if ~any(obj.zoomPanel)
                    resetZoom = true;
                elseif sum(obj.zoomPanel(1:obj.NumberPanels)) == obj.NumberPanels
                    resetZoom = true;
                    obj.zoomPanel(1:obj.NumberPanels) = false;
                else
                    resetZoom = false;
                end
            end
            %---------- End Error Handling ----------------
            
            % Reset Zoom by repack panels to relative and turn on visible
            if resetZoom
                obj.zoomPanel(1:obj.NumberPanels) = false;
                for i = 1:obj.NumberPanels
                    obj.hPanel(i).repack(1/obj.NumberPanels);
                    obj.hAxes(i).Visible = true;
                    for ic = 1:length(obj.hAxes(i).Children)
                        obj.hAxes(i).Children(ic).Visible = true;
                    end
                    obj.hLegend(i).Visible = true;
                    obj.hControl(i).Visible = true;
                end
            else

                % Turn off all false zoom states
                unzoomPanels = find(obj.zoomPanel == false);
                unzoomPanels(unzoomPanels > obj.NumberPanels) = [];
                for i = unzoomPanels
                    obj.hAxes(i).Visible = false;
                    for ic = 1:length(obj.hAxes(i).Children)
                        obj.hAxes(i).Children(ic).Visible = false;
                    end
                    obj.hLegend(i).Visible = false;
                    obj.hControl(i).Visible = false;
                end

                % Get a list of panels to zoom
                zoomPanels = find(obj.zoomPanel);
                nZoom = length(zoomPanels);

                % if there is only 1 zoom panel, leave no gap             
                if nZoom == 1
                    gap_height = 0;
                else
                    gap_height = 0.05;
                end
                % initialize bottom location and axes' height
                bottom_location = 0;
                height_val = 1 /nZoom - gap_height;
                % Start zooming from bottom up
                for i = flip(zoomPanels)
                    obj.hAxes(i).Visible = true;
                    for ic = 1:length(obj.hAxes(i).Children)
                        obj.hAxes(i).Children(ic).Visible = true;
                    end
                    obj.hLegend(i).Visible = true;
                    obj.hControl(i).Visible = true;
                    obj.hPanel(i).repack([0 bottom_location 1 height_val])
                    bottom_location = bottom_location + height_val + gap_height;
                end

            end

            % resize Control Panel
            obj.resize_hcontrol()
            
            % update xlimit
            obj.update_time_xlim()

        end

        function darkMode(obj)
            darkBackground(obj.hFig,ones(1,3)*0.2);
        end


        function vertical_cursor(obj,state)

            if ~isstring(state) && ~ischar(state)
                error("vertical_cursor's state is either 'on' or 'off'");
            end
            if ischar(state)
                state = string(state);
            end
            if state ~= "on" && state ~= "off"
                error("vertical_cursor's state is either 'on' or 'off'");
            end

            % switch cursor status base on option
            if (state == "on" && obj.cursor_status == true) ||...
                    (state == "off" && obj.cursor_status == false)
                return;
            elseif state == "on"
                obj.cursor_status = true;
            elseif state == "off"
                obj.cursor_status = false;
            end

            obj.update_cursor_lines();

            % Turn things visible on/off
            if obj.cursor_status
                
                set(obj.hCursor,'Visible','on')

            else

                % hide lines
                set(obj.hCursor,'Visible','off')

                % Set UITable values to ''
                for i = 1:obj.NumberPanels
                    for j = 1:obj.MaxNumberLines
                        obj.update_uitable_value(i,j,'','');
                    end
                end
%                 set(obj.hText,'Position',[NaN NaN 0])

            end

        end

        function update_panel_line_name(obj,panel_id,line_id,line_name)
            if isvalid(obj.hTable(panel_id))
                obj.hTable(panel_id).Data{1,obj.TableCol_Name} = 'Time (s)';
                obj.hTable(panel_id).Data{line_id+1,obj.TableCol_Name} = line_name{1};
            end
        end

        function cleanup_panel_line_val(obj,panel_id,line_id)
            if isvalid(obj.hTable(panel_id))
                obj.update_uitable_value(panel_id,line_id,'','')
            end
        end
    end

    methods( Access = private )
        % Private functions for vertical cursor

        %---------- Vertical Curosr Line Functions Begin ------------------

        
        function dragFcn(obj,~,~) % (obj,src,event)

            % Get mouse location
            pt = get(gca, 'CurrentPoint');
            panel_id = str2double(get(gca,'Tag'));
            % Update cursor line position
            obj.update_cursor_position(panel_id,pt(1),false);
        end

        function update_cursor_position(obj,panel_id_in,pt_x,from_key)

            % check line objects containing graphic
            hLines_garphic_check = isgraphics(obj.hLines);

            [hr,hc] = find(hLines_garphic_check);

            % process minimum_time_closest_time value differently when
            % using key press
            h_panel_id_in = hc == panel_id_in;
            if from_key && any(h_panel_id_in)
                hr_ptx = hr(h_panel_id_in);
                hc_ptx = hc(h_panel_id_in);
                
                if pt_x < obj.cursor_pt, nearest_bound_ptx = -Inf;
                elseif pt_x > obj.cursor_pt, nearest_bound_ptx = Inf; end

                % look for a new data point from the data bounds
                for i = 1:length(hr_ptx)

                    % let '---' represents data, 'x' previous point, and
                    % '<' (or '>') current point
                    
                    % |            ------------------   <x        |
                    % if cursor is the left arrow key
                    
                    if pt_x < obj.cursor_pt
                        % only check for lines with the cursor point on the
                        % right hand side
                        if obj.cursor_pt > obj.last_xdata(hc_ptx(i),hr_ptx(i)) &&...
                                obj.last_xdata(hc_ptx(i),hr_ptx(i)) > nearest_bound_ptx
                            nearest_bound_ptx = obj.last_xdata(hc_ptx(i),hr_ptx(i));
                        end
                    % |       x>   ------------------             |
                    elseif pt_x > obj.cursor_pt

                        xdata = obj.hLines(hr_ptx(i),hc_ptx(i)).XData;
                        % only check for lines with the cursor point on the
                        % left hand side
                        if obj.cursor_pt < xdata(1) && xdata(1) < nearest_bound_ptx
                            nearest_bound_ptx = xdata(1);
                        end
                    end

                end
                
                if nearest_bound_ptx == Inf || nearest_bound_ptx == -Inf
                    hr_ptx = hr;
                    hc_ptx = hc;
                    get_to_nearest_bound = false;
                else
                    get_to_nearest_bound = true;
                end

            % process minimum_time_closest_time w/ all lines if mouse drag
            else
                hr_ptx = hr;
                hc_ptx = hc;
                get_to_nearest_bound = false;
            end

            % This block of code needs to be tested thoroughly
            % ---------------------------
            minimum_time_closest_time = Inf;
            panel_current_min_step = obj.min_time_step(panel_id_in);
            % Get a list of minimum time steps that are not the current
            % panel's minimum step
            min_time_steps = obj.min_time_step(obj.min_time_step > 0 & obj.min_time_step ~= panel_current_min_step);

            % If there isn't any, use the current panel's minimum time step
            if isempty(min_time_steps) && panel_current_min_step > 0
                min_time_steps = panel_current_min_step;
            end

            if get_to_nearest_bound
                pt_x = nearest_bound_ptx;
            elseif numel(min_time_steps) > 0
                
                min_time_steps = sort(min_time_steps);
                min_time_steps = [panel_current_min_step;min_time_steps];
                min_time_steps = unique(min_time_steps);

                % calcluate pt_scaling (only applicable for key_press)
                if from_key
                    pt_scale = (pt_x - obj.cursor_pt)/panel_current_min_step;
                else
                    pt_scale = 1;
                end

                for k = 1:length(min_time_steps)
                    
                    % first minimum_time_step is from panel. If no solution
                    % found in the k = 1, pt_x is rescaled to a new
                    % min_time_step (only applicable for key_press)
                    if from_key && k > 1
                        pt_x = pt_x + pt_scale*(min_time_steps(k) - min_time_steps(k-1));
                    end
                    % Iterate through each time step from smallest to
                    % largest
                    for idx = 1:length(hr_ptx)
                        panel_id = hc_ptx(idx);
                        line_id = hr_ptx(idx);
                        
                        % if the panel contains the time step and is within
                        % the data end bound, compute closest time
                        if (obj.min_time_step(panel_id) == min_time_steps(k) ) &&...
                                (pt_x < obj.last_xdata(panel_id,line_id)+min_time_steps(k))

                            prev_idx = obj.interpF(panel_id,line_id).time2idx(pt_x);
                            prev_time = obj.interpF(panel_id,line_id).idx2time(prev_idx);
                            if prev_time < minimum_time_closest_time
                                minimum_time_closest_time = prev_time;
                            end
                        end

                    end
                    % after iterating through all the lines and found a
                    % minimum time, exit out
                    if minimum_time_closest_time ~= Inf && obj.cursor_pt ~= minimum_time_closest_time
                        break
                    end
                end
                 pt_x = minimum_time_closest_time;
            end
            % ----------------------------

            % save the pt value
            obj.cursor_pt = pt_x;
            set(obj.hCursor, 'Value', obj.cursor_pt);

            % Update cursor text
            for idx = 1:length(hr)
                panel_id = hc(idx);
                line_id = hr(idx);
                % If there isn't a text graphic, add one
%                 if ~isgraphics(obj.hText(line_id,panel_id))
%                     obj.hText(line_id,panel_id) = text(NaN, NaN, '', ...
%                         'Parent', get(obj.hLines(line_id,panel_id), 'Parent'), ...
%                         'BackgroundColor', 'yellow', ...
%                         'Color', get(obj.hLines(line_id,panel_id), 'Color'));
%                 end
                % Get x,y coordinate from the line
                xdata = obj.hLines(line_id,panel_id).XData;
                ydata = obj.hLines(line_id,panel_id).YData;
                % TODO: Put value y to the panel
                if pt_x >= xdata(1) && pt_x <= xdata(end)
                    % matlab.internal.math.interp1 skips overhead
                    y = matlab.internal.math.interp1(xdata,ydata,'previous','previous',pt_x);
                    obj.update_uitable_value(panel_id,line_id,pt_x,y);
                elseif pt_x > xdata(end)
                    obj.update_uitable_value(panel_id,line_id,xdata(end),ydata(end));
                elseif pt_x < xdata(1)
                    obj.update_uitable_value(panel_id,line_id,xdata(1),ydata(1));
                else
%                     set(obj.hText(line_id,panel_id), 'Position', [NaN NaN]);
                end

            end


            % Update cursor text
            idx_to_clean = obj.tracked_lines - hLines_garphic_check;
            for panel_id = 1:obj.MaxNumberPanels

                % if there is no line and graphic exists
                if sum(hLines_garphic_check(:,panel_id)) == 0 &&...
                        ~isa(obj.hCursor(panel_id).Parent,'matlab.graphics.GraphicsPlaceholder')
                    delete(obj.hCursor(panel_id))
                    obj.hCursor(panel_id) = matlab.graphics.chart.decoration.ConstantLine;
                end

                for line_id = 1:obj.MaxNumberLines
                    if idx_to_clean(line_id,panel_id)
%                         delete(obj.hText(line_id,panel_id));
%                         obj.hText(line_id,panel_id) = matlab.graphics.primitive.Text;
                        obj.tracked_lines(line_id,panel_id) = false;
                    end
                end
            end
        end

        function xpos = get_date_xpos(obj,x_value)
            ax1 = gca;
            % dx_days = diff(ax1.XLim)/24;
            x_min = ax1.XLim(1);
            xpos = datenum(x_value - x_min);
        end

        function clickFcn(obj,~,~) % (obj,src,event)
            % Initiate cursor if clicked anywhere but the figure
            if strcmpi(get(gco, 'type'), 'figure')
                x_lims = xlim(gca);
                default_x_val = x_lims(1);
                set(obj.hCursor, 'Value', default_x_val);
%                 set(obj.hText,'Position',[NaN NaN 0])

            else
                if obj.cursor_status
                    set(gcf, 'WindowButtonMotionFcn', @obj.dragFcn)
                    obj.dragFcn([],[])
                end
            end
        end
        
        function unclickFcn(obj,~,~) % (obj,src,event)
            % have no idea what it does yet
            obj.hFig.WindowButtonMotionFcn = '';
        end

        function update_uitable_value(obj,panel_id,line_id,time,val)
            
%             colorgen = @(color,text) ['<html><tr>',...
%                 '<td color=',color,' width=9999 align=right"><font size="5">',text,'</font></td>',...
%                 '</tr></html>'];
            
            if ischar(val) && strcmp(val,'')
                obj.hTable(panel_id).Data{line_id+1,obj.TableCol_Value} = '';
            else
                if abs(val) > 1000 || abs(val) < 0.001
                    i = 1;
                else
                    i = 2;
                end
                % Value
                str_val = sprintf(obj.str_format{i},val);
                time_val = sprintf(obj.time_format,time);

                obj.hTable(panel_id).Data{1,obj.TableCol_Value} = ['<html><tr>',...
                '<td color=#000000 width=9999 align=right"><font size="5">',time_val,'</font></td>',...
                '</tr></html>'];

                obj.hTable(panel_id).Data{line_id+1,obj.TableCol_Value} = ['<html><tr>',...
                '<td color=',obj.clr_hex{line_id},' width=9999 align=right"><font size="5">',str_val,'</font></td>',...
                '</tr></html>'];
            end

        end
        
        %---------- Vertical Cursor Line Functions End-- ------------------

    end

    methods( Access = private )

        function key_pressed_fcn(obj,~,eventData)

            if ~isempty(eventData.Modifier)
                modifier_ = string(eventData.Modifier{1});
            else
                modifier_ = "";
            end
            key_ = string(eventData.Key);
            switch modifier_
                case ""
                    switch key_
                        case "rightarrow"
                            panel_id = str2double(get(gca,'Tag'));
                            obj.update_cursor_position(panel_id,obj.cursor_pt+obj.min_time_step(panel_id)*1.1,true)
                        case "leftarrow"
                            panel_id = str2double(get(gca,'Tag'));
                            obj.update_cursor_position(panel_id,obj.cursor_pt-obj.min_time_step(panel_id)*0.8,true)
                        otherwise
                            disp("Pressed: "+modifier_ + "+"+key_);
                    end
                case "shift"
                    disp("Pressed: "+modifier_ + "+"+key_);
                case "alt"
                    key_num = double(key_);
                    if ~isnan(key_num)
                        obj.zoom(key_num);
                    elseif key_ == "backquote"
                        obj.zoom('')
                    end
                case "control"
                    switch key_
                        case "r"
                            obj.resize_hcontrol();
                        otherwise
                            disp("Pressed: "+modifier_ + "+"+key_);
                    end                    
            end
        end
        function resize_hcontrol(obj)
            % Resize control panel

            for i1 = 1:obj.NumberPanels
                % Only resize if the panel is visible
                if strcmp(obj.hControl(i1).Visible,'on')
 
                    % Get the panel's size
                    old_unit_ = obj.hControl(i1).Units;
                    obj.hControl(i1).Units = 'pixels';
                    panel_pos_ = obj.hControl(i1).Position;
                    obj.hControl(i1).Units = old_unit_;

                    % Update Table size
                    table_obj = obj.hControl(i1).findobj('Tag','DataViewer');
                    % Save old properties
                    old_unit_ = table_obj.Units;
                    table_obj.Units = 'pixels';
                    old_pos_ = table_obj.Position;

                    if panel_pos_(4) < (5+obj.DefaultTableSize(2))
                        new_bottom = 0;
                        new_height = panel_pos_(4);
                        new_width = obj.DefaultTableSize(1)+5;
                    else
                        new_bottom = panel_pos_(4)-(5+obj.DefaultTableSize(2));
                        new_height = obj.DefaultTableSize(2);
                        new_width = obj.DefaultTableSize(1);
                    end

                    table_new_pos_ = [old_pos_(1) new_bottom new_width new_height];
                    table_obj.Position = table_new_pos_;
                    table_obj.Units = old_unit_;

                    % Update Buttons' size
%                     button_obj = obj.hControl(i1).findobj('Tag','Button');
%                     for i2 = 1:obj.DefaultNButtons
% 
%                         % Save old properties
%                         old_unit_ = button_obj(i2).Units;
%                         button_obj(i2).Units = 'pixels';
% %                         old_pos_ = button_obj(i2).Position;
%                         
%                         % Calculate new position with a fix width and
%                         % height
%                         new_left_loc = table_new_pos_(1) + table_new_pos_(3);
%                         new_pos_ = [new_left_loc+5 panel_pos_(4)-(5+obj.DefaultButtonSize(2))*i2...
%                                     obj.DefaultButtonSize];
%                         button_obj(i2).Position = new_pos_;
% 
%                         % revert propertis
%                         button_obj(i2).Units = old_unit_;
%                     end

                end
            end
        end

        function resize_figure_callback(obj,src,~)
            
            obj.hPanel.resizeCallback(src);
            obj.resize_hcontrol();
        end

        function close_figure_callback(obj,src,~)
            
            obj.hPanel.closeCallback(src);
            delete(obj.hFig);

        end

    end

end
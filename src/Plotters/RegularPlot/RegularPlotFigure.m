classdef RegularPlotFigure < handle
%
% RegularPlotFigure handle is a custom figure to help analyzing simulation
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
       
        function obj = RegularPlotFigure(NumberPanels)
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
                u = RegularPlotInteractivePanel();
                obj.hControl(i) = obj.hPanel(i,2).select(u);
            end

            % Set up all the axes
            obj.hAxes = obj.hPanel.select('all');
            for i = 1:NumberPanels
                grid(obj.hAxes(i),'on');
                obj.hAxes(i).Tag = num2str(i);
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

        end

        function darkMode(obj)
            darkBackground(obj.hFig,ones(1,3)*0.2);
        end

        function update_panel_axes_label(obj,panel_id,xval_name,yval_name)
            if isvalid(obj.hPanel(panel_id,1))
                obj.hPanel(panel_id,1).xlabel(xval_name);
                obj.hPanel(panel_id,1).ylabel(yval_name);
            end
        end

        function cleanup_panel_line_val(obj,panel_id,line_id)
            if isvalid(obj.hTable(panel_id))
                obj.update_uitable_value(panel_id,line_id,'','')
            end
        end
    end

    methods ( Access = private )

        function key_pressed_fcn(obj,~,eventData)

            if ~isempty(eventData.Modifier)
                modifier_ = string(eventData.Modifier{1});
            else
                modifier_ = "";
            end
            key_ = string(eventData.Key);
            switch modifier_
                case ""
                    disp("Pressed: "+modifier_ + "+"+key_);
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
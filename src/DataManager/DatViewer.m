classdef DatViewer < handle
    % DatViewer class manages all the new time history data,
    % interpret user interface commands and passes to Plotting tool.
    % The class contains a time history property 'th' that is a TimeData class.
    % The property has a size of (Nsource,1)
    %
    % Currently, only 4 sources are managed but can be increased


    properties ( Access = public )
        th TimeData % Array of TimeData struct containing time history data information
        pt TimeSeriesFigure % Panel Handle
    end

    properties( GetAccess = public, SetAccess = private )
        Nsource (1,1) uint16 = 4; % Maximum source number for array struct 'th'
    end

    properties( Access = private )
        % GUI properties
        gui
        MaxNumberPanels = 6;
        MaxNumberLines = 6;
        panel_occupancy % must match with (MaxNumberLines,MaxNumberPanels)
        panel_occupied_variable %
        sourceNames = ["SourceA", "SourceB", "SourceC", "SourceD"];
        clr_rgb = [0 1 0
                   1 0 1
                   0 0.4470 0.7410
                   0.4940 0.1840 0.5560
                   0.3010 0.7450 0.9330
                   0.6350 0.0780 0.1840];

        tplot_NargReq = 4;
        tplot_ArgLine = 5;
        tplot_ArgConversion = 6;
        tplot_ArgFromGUI = 7;
        str_format = {'%.6e','%.6f'};
    end

    properties( Access = private )
        validScalarRealNum = @(x) isscalar(x) && isreal(x);
        validScalarPosNum = @(x) isnumeric(x) && isscalar(x) && (x > 0);
        validScalarPosNumSource = @(x) isnumeric(x) && isscalar(x) && (x > 0) && (x <= obj.Nsource);

        SourceOccupancyStatus
    end
        

    methods( Access = public )
        % Data Manager Main Public Functions
        
        function obj =  DatViewer(varargin)
            % DatViewer Constructor to initialize the tool
            
            obj.th(obj.Nsource) = TimeData;

            % add listener to derivedData, so the variable list is
            % automatically updated when derivedData changes
            for i = 1:obj.Nsource
                addlistener(obj.th(i),'derivedData','PostSet',@(src,event)obj.update_gui_source_variable(src,event));
            end
            obj.SourceOccupancyStatus = zeros(1,obj.Nsource);
            if nargin && isequal(varargin{1}, 'gui')
                obj.gui = DatViewer_GUI(obj);
            end
            obj.panel_occupancy = zeros(obj.MaxNumberLines,obj.MaxNumberPanels);
            obj.panel_occupied_variable = strings(obj.MaxNumberLines,obj.MaxNumberPanels);

        end

        function importNewSource(obj,varargin)
            % Import new data source. If full file path is not supplied, a
            % popup window appears to select data
            %   Current limitation:
            %       The tool currently only supports a rectangular ascii
            %       data that has 2 header lines. The 2nd line provides
            %       variables' name in the data column order.

            % Parse arguments: check for FullPathFile and SourceNumber
            defaultFullPathFile = [];
            EmptySourceIdx = find(obj.SourceOccupancyStatus == 0,1); % Check for vacancy
            if isempty(EmptySourceIdx)
                defaultSourceNumber = 0;
                SourceIsFull = true;
            else
                defaultSourceNumber = EmptySourceIdx;
                SourceIsFull = false;
            end
            p = inputParser;            

            % Parse input arguments
            addOptional(p,"FullPathFile",defaultFullPathFile,@(x) ischar(x) || isstring(x));
            addOptional(p,"SourceNumber",defaultSourceNumber,obj.validScalarPosNumSource);
            parse(p,varargin{:});
            FullPathFile = p.Results.FullPathFile;
            SourceNumber = p.Results.SourceNumber;
            
            % Determine if the user select source replacement when the
            % source is full
            if SourceIsFull && SourceNumber == 0
                warning("All sources are full. Please select a source for replacement.")
            else
                % Check 
                if p.Results.FullPathFile == ""
                    [file,path] = uigetfile({'*.tx, *.txt, *.dat','(*.tx, *.txt, *.dat)';...
                                             '*.mat','MATLAB File (*.mat)';...
                                             '*.*','All Files (*.*)'},...
                                             'Select A File');
                    if file ~= 0
                        FullPathFile = string([path,file]);
                    else
                        FullPathFile = [];
                    end
                end
                
                % If successfully load the data into th, take away empty source slot
                if ~isempty(FullPathFile) && exist(FullPathFile,'file')
                    obj.th(SourceNumber).read_timehistory_file(FullPathFile,SourceNumber);
                    obj.SourceOccupancyStatus(SourceNumber) = true;
                end
            end

        end

    end

    methods( Access = public )
        % Public functions for GUI

        function launchGui(obj)
            % Launch DatViewer Graphical User Interface
            %   No argument is required

            obj.gui = DatViewer_GUI(obj);
            obj.update_gui_grid_tables("all");
            obj.update_gui_vertical_cursor_status([],[])
            if ~isempty(obj.pt) && isgraphics(obj.pt.hFig)
                obj.gui.PanelNumberSelection.Value = obj.gui.PanelNumberSelection.Items(obj.pt.NumberPanels);
            end
        end

    end

    methods( Access = public )
        % Public functions for Panel Figure

        function createPanel(obj,Npanels)
            % create_panel(Npanels) creates a figure with N specified
            % panels. Maximum supported panels is 6. Having more than 6
            % panels at a time to analyzing data is overwhelming.

            % check panel_id parameter to be valid number and within range
            if ~obj.validScalarPosNum(Npanels) || Npanels > obj.MaxNumberPanels
                error("Invalid valid Npanels. panel_id must be between 1 to "+obj.pt.NumberPanels);
            end

            if isempty(obj.pt) || ~ishandle(obj.pt.hFig)
                obj.pt = TimeSeriesFigure(Npanels);
                addlistener(obj.pt,'cursor_status','PostSet',@(src,event)obj.update_gui_vertical_cursor_status(src,event));
            elseif Npanels ~= obj.pt.NumberPanels
                close(obj.pt.hFig)
                obj.pt = TimeSeriesFigure(Npanels);
                addlistener(obj.pt,'cursor_status','PostSet',@(src,event)obj.update_gui_vertical_cursor_status(src,event));
            end
        end

        function darkMode(obj)
            % Enable dark mode if figure is available

            if ~isempty(obj.pt) && ishandle(obj.pt.hFig)
                obj.pt.darkMode();
            end

        end

        function verticalCursor(obj,state)

            if ischar(state)
                state = string(state);
            elseif ~isstring(state) && state ~= "on" && state ~= "off"
                error("vertical_cursor's state is either 'on' or 'off'");
            end

            if ~isempty(obj.pt) && ishandle(obj.pt.hFig)
                obj.pt.vertical_cursor(state);
            end

        end

        function zoom(obj,AxisList)

            if ~isempty(obj.pt) && ishandle(obj.pt.hFig)
                obj.pt.zoom(AxisList)
            end

        end

    end

    methods( Access = public )
        % Public Plotting Functions

        function tplot(obj,panel_id,source_id,data,varargin)
            % tplot(panel_ID,source_ID,data) is time plot. XData is always
            % time from the data source. The data's source and dimension
            % will be validated before it's plotted
            %
            %   tplot(panel_ID,source_ID,data,line_ID,scale_factor)
            %       optional inputs: line_ID, scale_factor
            %       
            %       * add line_ID: tplot(panel_ID,source_ID,data,line_ID)
            %       * add scale_factor: tplot(panel_ID,source_ID,data,[],scale_factor)
            
            if isempty(obj.pt) || ~ishandle(obj.pt.hFig)
                obj.panel_occupancy = zeros(obj.MaxNumberLines,obj.MaxNumberPanels);
                obj.createPanel(min(panel_id,obj.MaxNumberPanels));
            end

            % There must be at least 3  inputs
            % check panel_id parameter to be valid number and within range
            if nargin < obj.tplot_NargReq
                error("Not enough arguments. tplot requires panel_id, source_id and data")
            % check panel_id parameter to be valid number and within range
            elseif ~obj.validScalarPosNum(panel_id) || panel_id > obj.pt.NumberPanels
                error("Invalid panel_id. panel_id must be between 1 to "+obj.pt.NumberPanels);
            % check source_id parameter to be valid number and within range
            elseif ~obj.validScalarPosNum(source_id) || source_id > obj.Nsource
                error("Invalid panel_id. source_id must be between 1 to "+obj.Nsource);
            end

            % get inputs
            call_from_gui = false;
            if nargin >= obj.tplot_ArgFromGUI
                line_ID = varargin{obj.tplot_ArgLine- obj.tplot_NargReq};
                scale_factor = varargin{obj.tplot_ArgConversion - obj.tplot_NargReq};
                 % assume only GUI passes in the flag for from gui
                call_from_gui = varargin{obj.tplot_ArgFromGUI - obj.tplot_NargReq};
            elseif nargin >= obj.tplot_ArgConversion
                line_ID = varargin{obj.tplot_ArgLine- obj.tplot_NargReq};
                scale_factor = varargin{obj.tplot_ArgConversion - obj.tplot_NargReq};
            elseif nargin >= obj.tplot_ArgLine
                line_ID = varargin{obj.tplot_ArgLine- obj.tplot_NargReq};
                scale_factor = 1;
            else
                line_ID = [];
                scale_factor = 1;
            end
            
            % validate data. If data hasn't loaded, load the data
            [data,error_status] = obj.th(source_id).validate_data(data);

            % validate line_ID
            if error_status == 0

                % validate line_ID
                if ~isempty(line_ID)
                    
                    if ~obj.validScalarPosNum(line_ID) || line_ID > obj.MaxNumberLines
                        error("Invalid line_number. source_id must be between 1 to "+obj.MaxNumberLines);
                    end
                    if sum(obj.panel_occupancy(:,panel_id)) == 0
                        obj.pt.hPanel(panel_id,1).hold('on');
                    end

                else
                    if any(obj.panel_occupancy(:,panel_id) == 0)
                        if sum(obj.panel_occupancy(:,panel_id)) == 0
                            obj.pt.hPanel(panel_id,1).hold('on');
                        end
                        available_ids = find(obj.panel_occupancy(:,panel_id) == 0);
                        line_ID = available_ids(1);
                    else
                        warning("Cannot add any more new line to panel " + panel_id+". Please, choose a line to replace")
                        return
                    end
                    
                end

                % validate scale factor
                if scale_factor ~= 1
                    if ~obj.validScalarRealNum(scale_factor)
                        error("Invalid scale_factor. scale_factor must be a real scalar number.")
                    end
                    if abs(scale_factor - pi/180) <1e-4
                        conversion_name = " [D2R]";
                    elseif abs(scale_factor - 180/pi) <1e-4
                        conversion_name = "[R2D]";
                    else
                        if abs(scale_factor) > 10000 || abs(scale_factor) < 0.001
                            i = 1;
                        else
                            i = 2;
                        end
                        conversion_name = " [" + string(num2str(scale_factor,obj.str_format{i})) + "]";
                    end
                else
                    conversion_name = "";
                end
                
                
                % remove the old line
                if ishandle(obj.pt.hLines(line_ID,panel_id))
                    delete(obj.pt.hLines(line_ID,panel_id))
                end
                % plot the new line
                line_idtag = "id_"+panel_id+"_"+line_ID;
                obj.pt.hLines(line_ID,panel_id) =...
                    stairs(obj.pt.hAxes(panel_id),...
                        obj.th(source_id).data.time.value,data.value*scale_factor,...
                        'linewidth',2,'Color',obj.clr_rgb(line_ID,:),...
                        'Tag',line_idtag,...
                        'DeleteFcn',@obj.hline_cleanup_callback);

                % update occupancy
                obj.panel_occupancy(line_ID,panel_id) = source_id;
                obj.panel_occupied_variable(line_ID,panel_id) = obj.sourceNames(source_id) + " - " + data.name + conversion_name;
                
                % Update legend
                plotted_ids = find(obj.panel_occupancy(:,panel_id) ~= 0);
                obj.pt.hLegend(panel_id) =...
                    clickableLegend(obj.pt.hAxes(panel_id),...
                       obj.pt.hLines(plotted_ids,panel_id),...
                       obj.panel_occupied_variable(plotted_ids,panel_id),...
                       'location','northeast','Orientation','vertical');

                % update time step
                obj.pt.update_panel_min_time_step(panel_id);

                % update GUI panel
                if ~call_from_gui
                    obj.update_gui_grid_tables(panel_id,line_ID);
                end

                % update cursor
                obj.pt.update_cursor_lines()
            end

            % Update X Axes limits
            obj.pt.update_xlim();

        end

    end

    methods( Access = public, Hidden = true )
        % Fucntions to support Graphical User Interface App

        function datamanager_please_help(obj)
            % datamanager_please_help() helps GUI App to process the inputs
            % data
            
            % First, parse throught the first 6 grids to extract all the
            % variables for each source
            var_list = cell(obj.MaxNumberLines,obj.MaxNumberPanels);
            for i = 1:obj.MaxNumberPanels
                var_list(:,i) = obj.gui.("Grid_"+i).Data;
            end
            var_list = string(var_list);

            % Second, parse through var_list and load variables from the source
            for i = 1:obj.Nsource
                % if datastore doesn't exist, don't bother
                if isa(obj.th(i).ds,'matlab.io.datastore.TabularTextDatastore')
                    current_source = obj.sourceNames(i);
                    % find all variables match with current source
                    source_variables = var_list(contains(var_list,current_source));
                    if ~isempty(source_variables)

                        % Assumption: variable name does not have '-'
                        % get strings' content that contains '- <any characters>'
                        source_variables = string(regexp(source_variables,"\-(\s+)?\w*",'match'));
                         % Then get string after '-'
                        source_variables = string(regexp(source_variables,"\w*",'match'));
                        
                        % get data
                        obj.th(i).get_data(source_variables);
                    end
                end
            end

            % Third, create a panel figure it doesn't exist
            n_panels = string(obj.gui.PanelNumberSelection.Value);
            n_panels = double(regexp(n_panels,'\d+','match'));
            obj.createPanel(n_panels)

            % Fourth, plot data onto each panel
            for i1 = 1:n_panels
                panel_var_list = var_list(:,i1);
                % Ensure there is no empty cell
                if any(panel_var_list ~= "")
                    for i2 = 1:obj.Nsource
                        current_source = obj.sourceNames(i2);
                        % find all variables match with current source
                        location_id = contains(panel_var_list,current_source);
                        if any(location_id)
                            panel_variables = panel_var_list(location_id);
                            location_id = find(location_id);
                            % split with "-" delimiter
                            source_variables = split(panel_variables,"-");
                            % variable name is on the 2nd column
                            if size(source_variables,2) == 1
                                source_variables = source_variables';
                            end
                            source_variables = strtrim(source_variables(:,2));
                            % Iterate through all the variables to plot
                            for i3 = 1:length(location_id)

                                % source variable name
                                if contains(source_variables(i3),"[")
                                    tmp = split(source_variables(i3),"[");
                                    source_variable_name = char(strtrim(tmp(1)));
                                    % find the following:
                                    %   any group of characters 
                                    %   (specifically R2D and D2R) that can
                                    %   follow with decimal points and any
                                    %   scientific format characters
                                    conversion_name = string(regexp(tmp(2),"\w*(\.\d+)?((e|E)(-|+)?\d+)?",'match'));
                                    if conversion_name == "R2D"
                                        scale_factor = 180/pi;
                                    elseif conversion_name == "D2R"
                                        scale_factor = pi/180;
                                    else
                                        scale_factor = double(conversion_name);
                                    end
                                else
                                    source_variable_name = source_variables{i3};
                                    scale_factor = 1;
                                end

                                % if the values comes from derviedData
                                if any(ismember(obj.th(i2).derivedData_names,source_variable_name))
                                    obj.tplot(i1,i2,... % arg1, arg2
                                              obj.th(i2).derivedData.(source_variable_name),... % arg3
                                              location_id(i3),scale_factor,true); % arg4, arg5, arg6
                                else
                                    obj.tplot(i1,i2,... % arg1, arg2
                                              obj.th(i2).data.(source_variable_name),... % arg3
                                              location_id(i3),scale_factor,true); % arg4, arg5, arg6
                                end
                            end
                        end
                    end
                end
            end

        end

    end

    methods( Access = private )
        % Private Support Functions

        function hline_cleanup_callback(obj,src,~)

            % id_tag format: id_panelID_locationID
            id_tag = split(src.Tag,"_");
            panel_id = str2double(id_tag{2});
            loc_id = str2double(id_tag{3});
            obj.panel_occupancy(loc_id,panel_id) = 0;
            obj.panel_occupied_variable(loc_id,panel_id) = "";
            
        end

        function update_gui_grid_tables(obj,varargin)
            % update_gui_grid_tables() update  the GUI App's grid table
            % when the user's plot data from command line.

            if isa(obj.gui,'DatViewer_GUI') && isvalid(obj.gui)

                panel_id = varargin{1};
                if nargin > 2
                    line_id = varargin{2};
                end
                if panel_id == "all"
                    for i = 1:obj.MaxNumberPanels
                        for j = 1:obj.MaxNumberLines
                            obj.gui.("Grid_"+i).Data{j} = obj.panel_occupied_variable{j,i};
                        end
                    end
                else
                    obj.gui.("Grid_"+panel_id).Data{line_id} = obj.panel_occupied_variable{line_id,panel_id};
                end
            end
        end

        function update_gui_source_variable(obj,src,event)

            % check if gui is available
            if isa(obj.gui,'DatViewer_GUI') && isvalid(obj.gui)

                value  = string(obj.gui.VariableListDropdown.Value);
                gui_current_idx = find(contains(obj.sourceNames,value));
                source_idx = double(event.AffectedObject.source_index);

                % check if the derivedData update and variable list come
                % from the same source
                if source_idx == gui_current_idx
                    % update Original Variable List
                    obj.gui.OriginalVariableList = natsort(...
                            [obj.th(source_idx).AvailableVariablesList(:);...
                             obj.th(source_idx).derivedData_names(:)]);
                    
                    % Check if there is a search on variable list and
                    % update variable list according to the search
                    search_variable = string(obj.gui.VariableListSearch.Value);
                    if search_variable == ""
                        obj.gui.VariableList.Items = obj.gui.OriginalVariableList;
                    else
                        idx = contains(obj.gui.OriginalVariableList,search_variable);
                        obj.gui.VariableList.Items = obj.gui.OriginalVariableList(idx);
                    end
                end
            end

        end

        function update_gui_vertical_cursor_status(obj,~,~)

            % check if gui is available
            if isa(obj.gui,'DatViewer_GUI') && isvalid(obj.gui)
                if obj.gui.VerticalCursorButton.Value ~= obj.pt.cursor_status
                    obj.gui.VerticalCursorButton.Value = obj.pt.cursor_status;
                end
            end
        end

    end

end
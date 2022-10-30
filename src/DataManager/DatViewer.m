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
    end

    properties( Access = private )
        validScalarPosNum = @(x) isnumeric(x) && isscalar(x) && (x > 0);
        validScalarPosNumSource = @(x) isnumeric(x) && isscalar(x) && (x > 0) && (x <= obj.Nsource);

        SourceOccupancyStatus
    end
        

    methods( Access = public )
        % Data Manager Main Public Functions
        
        function obj =  DatViewer(varargin)
            % DatViewer Constructor to initialize the tool
            
            obj.th(obj.Nsource) = TimeData;
            obj.SourceOccupancyStatus = zeros(1,obj.Nsource);
            if nargin && isequal(varargin{1}, 'gui')
                obj.gui = analyzer_gui(obj);
            end
            obj.panel_occupancy = zeros(obj.MaxNumberLines,obj.MaxNumberPanels);
            obj.panel_occupied_variable = strings(obj.MaxNumberLines,obj.MaxNumberPanels);

        end

        function import_new_source(obj,varargin)
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
                    [file,path] = uigetfile({'*.tx','TMSF (*.tx)';...
                                             '*.mat','MATLAB File (*.mat)';...
                                             '*.dat','Common dat file (*.dat)';...
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
        % Supported Public Fucntions

        function launch_gui(obj)
            % Launch DatViewer Graphical User Interface
            %   No argument is required

            obj.gui = DatViewer_GUI(obj);
            obj.update_gui_grid_tables("all");
            if ~isempty(obj.pt) && isgraphics(obj.pt.hFig)
                obj.gui.PanelNumberSelection.Value = obj.gui.PanelNumberSelection.Items(obj.pt.NumberPanels);
            end
        end

        function create_panel(obj,Npanels)
            % create_panel(Npanels) creates a figure with N specified
            % panels. Maximum supported panels is 6. Having more than 6
            % panels at a time to analyzing data is overwhelming.

            % check panel_id parameter to be valid number and within range
            if ~obj.validScalarPosNum(Npanels) || Npanels > obj.MaxNumberPanels
                error("Invalid valid Npanels. panel_id must be between 1 to "+obj.pt.NumberPanels);
            end

            if isempty(obj.pt) || ~ishandle(obj.pt.hFig)
                obj.pt = TimeSeriesFigure(Npanels);
            elseif Npanels ~= obj.pt.NumberPanels
                close(obj.pt.hFig)
                obj.pt = TimeSeriesFigure(Npanels);
            end
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
                        % split with "-" delimiter
                        source_variables = split(source_variables,"-");
                        if size(source_variables,2) == 1
                            source_variables = source_variables';
                        end
                        % variable name is on the 2nd column
                        source_variables = strtrim(source_variables(:,2));
                        % get data
                        obj.th(i).get_data(source_variables);
                    end
                end
            end

            % Third, create a panel figure it doesn't exist
            n_panels = string(obj.gui.PanelNumberSelection.Value);
            n_panels = double(regexp(n_panels,'\d+','match'));
            obj.create_panel(n_panels)

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
                            source_variables = panel_var_list(location_id);
                            location_id = find(location_id);
                            % split with "-" delimiter
                            source_variables = split(source_variables,"-");
                            % variable name is on the 2nd column
                            if size(source_variables,2) == 1
                                source_variables = source_variables';
                            end
                            source_variables = strtrim(source_variables(:,2));
                            % Iterate through all the variables to plot
                            for i3 = 1:length(location_id)
                                % if the values comes from derviedData
                                if any(ismember(obj.th(i2).derivedData_names,source_variables{i3}))
                                    obj.tplot(i1,i2,obj.th(i2).derivedData.(source_variables{i3}),location_id(i3),true);
                                else
                                    obj.tplot(i1,i2,obj.th(i2).data.(source_variables{i3}),location_id(i3),true);
                                end
                            end
                        end
                    end
                end
            end

        end


        function update_gui_grid_tables(obj,varargin)
            % update_gui_grid_tables() update  the GUI App's grid table
            % when the user's plot data from command line.

            if isa(obj.gui,'analyzer_gui') && isvalid(obj.gui)

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

    end

    
    methods( Access = public )
        % Public Plotting Functions

        function tplot(obj,panel_id,source_id,data,varargin)
            % tplot(panel_ID,source_ID,data) is time plot. XData is always
            % time from the data source. The data's source and dimension
            % will be validated before it's plotted 
            
            if isempty(obj.pt) || ~ishandle(obj.pt.hFig)
                obj.panel_occupancy = zeros(obj.MaxNumberLines,obj.MaxNumberPanels);
                obj.pt = TimeSeriesFigure(min(panel_id,obj.MaxNumberPanels));
            end

            % There must be at least 3  inputs
            % check panel_id parameter to be valid number and within range
            if nargin < 4
                error("Not enough arguments. tplot requires panel_id, source_id and data")
            % check panel_id parameter to be valid number and within range
            elseif ~obj.validScalarPosNum(panel_id) || panel_id > obj.pt.NumberPanels
                error("Invalid panel_id. panel_id must be between 1 to "+obj.pt.NumberPanels);
            % check source_id parameter to be valid number and within range
            elseif ~obj.validScalarPosNum(source_id) || source_id > obj.Nsource
                error("Invalid panel_id. source_id must be between 1 to "+obj.Nsource);
            end

            % validate data. If data hasn't loaded, load the data
            [data,error_status] = obj.th(source_id).validate_data(data);

            call_from_gui = false;
            if error_status == 0
                if nargin > 4
                    
                    if ~obj.validScalarPosNum(varargin{1}) || varargin{1} > obj.MaxNumberLines
                        error("Invalid valid line_number. source_id must be between 1 to "+obj.MaxNumberLines);
                    end
                    if sum(obj.panel_occupancy(:,panel_id)) == 0
                        obj.pt.hPanel(panel_id,1).hold('on');
                    end
                    line_id = varargin{1};


                    % this is probably a really bad coding...
                    if nargin > 5
                        call_from_gui = varargin{2}; % assume only GUI passes in the flag for from gui
                    end
                else
                    if any(obj.panel_occupancy(:,panel_id) == 0)
                        if sum(obj.panel_occupancy(:,panel_id)) == 0
                            obj.pt.hPanel(panel_id,1).hold('on');
                        end
                        available_ids = find(obj.panel_occupancy(:,panel_id) == 0);
                        line_id = available_ids(1);
                    else
                        warning("Cannot add any more new line to panel " + panel_id+". Please, choose a line to replace")
                        return
                    end
                    
                end
                
                % remove the old line
                if ishandle(obj.pt.hLines(line_id,panel_id))
                    delete(obj.pt.hLines(line_id,panel_id))
                end
                % plot the new line
                line_idtag = "id_"+panel_id+"_"+line_id;
                obj.pt.hLines(line_id,panel_id) =...
                    stairs(obj.pt.hAxes(panel_id),...
                        obj.th(source_id).data.time.value,data.value,...
                        'linewidth',2,'Color',obj.clr_rgb(line_id,:),...
                        'Tag',line_idtag,...
                        'DeleteFcn',@obj.hline_cleanup_callback);

                % update occupancy
                obj.panel_occupancy(line_id,panel_id) = source_id;
                obj.panel_occupied_variable(line_id,panel_id) = obj.sourceNames(source_id) + " - " + data.name;
                
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
                    obj.update_gui_grid_tables(panel_id,line_id);
                end

                % update cursor
                obj.pt.update_cursor_lines()
            end

            % Update X Axes limits
            obj.pt.update_xlim();

        end

    end

    methods( Access = private )
        % Private Plotting Support Functions

        function hline_cleanup_callback(obj,src,~)

            % id_tag format: id_panelID_locationID
            id_tag = split(src.Tag,"_");
            panel_id = str2double(id_tag{2});
            loc_id = str2double(id_tag{3});
            obj.panel_occupancy(loc_id,panel_id) = 0;
            obj.panel_occupied_variable(loc_id,panel_id) = "";
            
        end

    end

end
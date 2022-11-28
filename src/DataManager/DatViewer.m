classdef DatViewer < handle
    % DatViewer class manages all the new time history data,
    % interpret user interface commands and passes to Plotting tool.
    % The class contains a time history property 'th' that is a TimeData class.
    % The property has a size of (Nsource,1)
    %
    % Currently, only 4 sources are managed but can be increased


    properties ( Access = public )
        th TimeData % Array of TimeData struct containing time history data information
        pt TimeSeriesFigure % Time Plot Panel Handle
        pr RegularPlotFigure  % Regular Plot Panel
    end

    properties( GetAccess = public, SetAccess = private )
        Nsource (1,1) uint16 = 4; % Maximum source number for array struct 'th'
    end

    properties( Access = private )
        % GUI properties
        gui
        MaxNumberPanels = 6;
        MaxNumberLines = 6;
        sourceNames = ["Src1", "Src2", "Src3", "Src4"];
        gridSourceNames = ["Source 1", "Source 2", "Source 3", "Source 4"];
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
        pt_occupancy % must match with (MaxNumberLines,MaxNumberPanels)
        pt_occupied_variable %

        rplot_NargReq = 5;
        rplot_ArgLine = 6;
        rplot_ArgConversion = 7;
        rplot_ArgFromGUI = 8;
        pr_occupancy
        pr_occupied_variable

        str_format = {'%.6e','%.6f'};

        grid_type = ["Grid_t","Grid_r"];
        TGRID = 1;
        RGRID = 2;
        rplot_y_grid_offset = 6;
    end

    properties( Access = private )
        validScalarRealNum = @(x) isscalar(x) && isreal(x);
        validScalarPosNum = @(x) isnumeric(x) && isscalar(x) && (x > 0);
        validScalarPosNumSource = @(x) isnumeric(x) && isscalar(x) && (x > 0) && (x <= 4);

        SourceOccupancyStatus
    end

    properties( Access = private )
        % Plot Figures Properties
        tplot_cursor_source_idx (4,1) double = ones(4,1);
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
            obj.pt_occupancy = zeros(obj.MaxNumberLines,obj.MaxNumberPanels);
            obj.pt_occupied_variable = strings(obj.MaxNumberLines,obj.MaxNumberPanels);

            obj.pr_occupancy = zeros(obj.MaxNumberLines,obj.MaxNumberPanels);
            obj.pr_occupied_variable = strings(obj.MaxNumberLines,obj.MaxNumberPanels);

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
            % Update number of Time Plot Panel
            if ~isempty(obj.pt) && isgraphics(obj.pt.hFig)
                obj.gui.tPanelNumberSelection.Value = obj.gui.tPanelNumberSelection.Items(obj.pt.NumberPanels);
            end
            % Update number of Regular Plot Panel
            if ~isempty(obj.pr) && isgraphics(obj.pr.hFig)
                obj.gui.rPanelNumberSelection.Value = obj.gui.rPanelNumberSelection.Items(obj.pr.NumberPanels);
            end
        end

    end

    methods( Access = public )
        % Public functions for Panel Figure

        function createPanel(obj,Npanels)
            % createPanel(Npanels) creates a figure with N specified
            % panels. Maximum supported panels is 6. Having more than 6
            % panels at a time to analyzing data is overwhelming.

            % Check argument
            if nargin < 2
                error("Error: Please specify number of panels (valid input: 1 to "+obj.MaxNumberPanels+")");
            end

            % check panel_id parameter to be valid number and within range
            if ~obj.validScalarPosNum(Npanels) || Npanels > obj.MaxNumberPanels
                error("Invalid valid Npanels. panel_id must be between 1 to "+obj.pt.NumberPanels);
            end

            if isempty(obj.pt) || ~ishandle(obj.pt.hFig)
                obj.pt = TimeSeriesFigure(Npanels);
                addlistener(obj.pt,'cursor_status','PostSet',@(src,event)obj.update_gui_vertical_cursor_status(src,event));
                addlistener(obj.pt,'cursor_source_idx','PostSet',@(src,event)obj.get_updated_tplot_cursor_src_idx(src,event));
                addlistener(obj.pt,'tplot_cursor_position_changed','PostSet',@(src,event)obj.update_rplot_cursor(src,event));
            elseif Npanels ~= obj.pt.NumberPanels
                close(obj.pt.hFig)
                obj.pt = TimeSeriesFigure(Npanels);
                addlistener(obj.pt,'cursor_status','PostSet',@(src,event)obj.update_gui_vertical_cursor_status(src,event));
                addlistener(obj.pt,'cursor_source_idx','PostSet',@(src,event)obj.get_updated_tplot_cursor_src_idx(src,event));
                addlistener(obj.pt,'tplot_cursor_position_changed','PostSet',@(src,event)obj.update_rplot_cursor(src,event));
            end
        end

        function createRplotPanel(obj,Npanels)
            % create_panel(Npanels) creates a figure with N specified
            % panels. Maximum supported panels is 6. Having more than 6
            % panels at a time to analyzing data is overwhelming.

            % Check argument
            if nargin < 2
                error("Error: Please specify number of panels (valid input: 1 to "+obj.MaxNumberPanels+")");
            end

            % check panel_id parameter to be valid number and within range
            if ~obj.validScalarPosNum(Npanels) || Npanels > obj.MaxNumberPanels
                error("Invalid valid Npanels. panel_id must be between 1 to "+obj.pr.NumberPanels);
            end

            if isempty(obj.pr) || ~ishandle(obj.pr.hFig)
                obj.pr = RegularPlotFigure(Npanels);
                % TODO: make a cursor status for regular plot
%                 addlistener(obj.pr,'cursor_status','PostSet',@(src,event)obj.update_gui_vertical_cursor_status(src,event));
            elseif Npanels ~= obj.pr.NumberPanels
                close(obj.pr.hFig)
                obj.pr = RegularPlotFigure(Npanels);
                % TODO: make a cursor status for regular plot
%                 addlistener(obj.pr,'cursor_status','PostSet',@(src,event)obj.update_gui_vertical_cursor_status(src,event));
            end
        end

        function darkMode(obj)
            % Enable dark mode if figure is available

            if ~isempty(obj.pt) && ishandle(obj.pt.hFig)
                obj.pt.darkMode();
            end

            if ~isempty(obj.pr) && ishandle(obj.pr.hFig)
                obj.pr.darkMode();
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
            % TODO: add cursor status for regular plot

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
                obj.pt_occupancy = zeros(obj.MaxNumberLines,obj.MaxNumberPanels);
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
                line_id = varargin{obj.tplot_ArgLine- obj.tplot_NargReq};
                scale_factor = varargin{obj.tplot_ArgConversion - obj.tplot_NargReq};
                 % assume only GUI passes in the flag for from gui
                call_from_gui = varargin{obj.tplot_ArgFromGUI - obj.tplot_NargReq};
            elseif nargin >= obj.tplot_ArgConversion
                line_id = varargin{obj.tplot_ArgLine- obj.tplot_NargReq};
                scale_factor = varargin{obj.tplot_ArgConversion - obj.tplot_NargReq};
            elseif nargin >= obj.tplot_ArgLine
                line_id = varargin{obj.tplot_ArgLine- obj.tplot_NargReq};
                scale_factor = 1;
            else
                line_id = [];
                scale_factor = 1;
            end

            if numel(scale_factor) ~= 1
                error("Invalid size for scale factor; tplot's scale factor must be a scalar.")
            end
            
            % validate data. If data hasn't loaded, load the data
            [data,error_status] = obj.th(source_id).validate_data(data);

            if error_status == 0

                % validate line_ID
                if ~isempty(line_id)
                    
                    if ~obj.validScalarPosNum(line_id) || line_id > obj.MaxNumberLines
                        error("Invalid line_number. source_id must be between 1 to "+obj.MaxNumberLines);
                    end
                    if sum(obj.pt_occupancy(:,panel_id)) == 0
                        obj.pt.hPanel(panel_id,1).hold('on');
                    end

                else
                    if any(obj.pt_occupancy(:,panel_id) == 0)
                        if sum(obj.pt_occupancy(:,panel_id)) == 0
                            obj.pt.hPanel(panel_id,1).hold('on');
                        end
                        available_ids = find(obj.pt_occupancy(:,panel_id) == 0);
                        line_id = available_ids(1);
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
                if ishandle(obj.pt.hLines(line_id,panel_id))
                    delete(obj.pt.hLines(line_id,panel_id))
                end
                % plot the new line
                line_idtag = "id_"+panel_id+"_"+line_id + "_" + source_id;
                obj.pt.hLines(line_id,panel_id) =...
                    stairs(obj.pt.hAxes(panel_id),...
                        obj.th(source_id).data.time.value,data.value*scale_factor,...
                        'linewidth',2,'Color',obj.clr_rgb(line_id,:),...
                        'Tag',line_idtag,...
                        'DeleteFcn',@obj.tplot_hline_cleanup_callback);

                % update occupancy
                obj.pt_occupancy(line_id,panel_id) = source_id;
                obj.pt_occupied_variable(line_id,panel_id) = obj.gridSourceNames(source_id) + " - " + data.name + conversion_name;
                
                % Update legend (clickablelegend is really slow)
%                 plotted_ids = find(obj.panel_occupancy(:,panel_id) ~= 0);
%                 obj.pt.hLegend(panel_id) =...
%                     clickableLegend(obj.pt.hAxes(panel_id),...
%                        obj.pt.hLines(plotted_ids,panel_id),...
%                        obj.panel_occupied_variable(plotted_ids,panel_id),...
%                        'location','northeast','Orientation','vertical');

                % Update panel line name
                obj.pt.update_panel_line_name(panel_id,line_id,obj.pt_occupied_variable(line_id,panel_id))

                % update time step
                obj.pt.update_panel_min_time_step(panel_id);

                % update GUI panel if tplot is called from command line
                if ~call_from_gui
                    obj.update_gui_grid_tables(obj.grid_type(obj.TGRID),panel_id,line_id);
                end

                % update cursor
                obj.pt.update_cursor_lines()
            end

            % Update X Axes limits
            obj.pt.update_time_xlim();

        end

        function rplot(obj,panel_id,source_id,xdata,ydata,varargin)
            
            
            if isempty(obj.pr) || ~ishandle(obj.pr.hFig)
                obj.pr_occupancy = zeros(obj.MaxNumberLines,obj.MaxNumberPanels);
                obj.createRplotPanel(min(panel_id,obj.MaxNumberPanels));
            end

            % There must be at least 5  inputs
            % check panel_id parameter to be valid number and within range
            if nargin < obj.rplot_NargReq
                error("Not enough arguments. tplot requires panel_id, source_id and data")
            % check panel_id parameter to be valid number and within range
            elseif ~obj.validScalarPosNum(panel_id) || panel_id > obj.pr.NumberPanels
                error("Invalid panel_id. panel_id must be between 1 to "+obj.pr.NumberPanels);
            % check source_id parameter to be valid number and within range
            elseif ~obj.validScalarPosNum(source_id) || source_id > obj.Nsource
                error("Invalid panel_id. source_id must be between 1 to "+obj.Nsource);
            end

            % get varargin inputs
            call_from_gui = false;
            if nargin >= obj.rplot_ArgFromGUI
                line_id = varargin{obj.rplot_ArgLine- obj.rplot_NargReq};
                scale_factor = varargin{obj.rplot_ArgConversion - obj.rplot_NargReq};
                 % assume only GUI passes in the flag for from gui
                call_from_gui = varargin{obj.rplot_ArgFromGUI - obj.rplot_NargReq};
            elseif nargin >= obj.rplot_ArgConversion
                line_id = varargin{obj.rplot_ArgLine- obj.rplot_NargReq};
                scale_factor = varargin{obj.rplot_ArgConversion - obj.rplot_NargReq};
            elseif nargin >= obj.rplot_ArgLine
                line_id = varargin{obj.rplot_ArgLine- obj.rplot_NargReq};
                scale_factor = [1 1];
            else
                line_id = [];
                scale_factor = [1 1];
            end

            if numel(scale_factor) ~= 2
                error("Invalid size for scale factor; tplot's scale factor must be a vector of 2 [xscale, yscale].")
            end

            % validate data. If data hasn't loaded, load the data
            [xdata,xerror_status] = obj.th(source_id).validate_data(xdata);
            [ydata,yerror_status] = obj.th(source_id).validate_data(ydata);

            if xerror_status == 0 && yerror_status == 0

                % validate line_ID
                if ~isempty(line_id)
                    
                    if ~obj.validScalarPosNum(line_id) || line_id > obj.MaxNumberLines
                        error("Invalid line_number. source_id must be between 1 to "+obj.MaxNumberLines);
                    end
                    if sum(obj.pr_occupancy(:,panel_id)) == 0
                        obj.pr.hPanel(panel_id,1).hold('on');
                    end

                else
                    if any(obj.pr_occupancy(:,panel_id) == 0)
                        if sum(obj.pr_occupancy(:,panel_id)) == 0
                            obj.pr.hPanel(panel_id,1).hold('on');
                        end
                        available_ids = find(obj.pr_occupancy(:,panel_id) == 0);
                        line_id = available_ids(1);
                    else
                        warning("Cannot add any more new line to panel " + panel_id+". Please, choose a line to replace")
                        return
                    end
                    
                end

                % validate X scale factor
                if scale_factor(1) ~= 1
                    if ~obj.validScalarRealNum(scale_factor(1))
                        error("Invalid scale_factor(1). scale_factor(1) must be a real scalar number.")
                    end
                    if abs(scale_factor(1) - pi/180) <1e-4
                        xconversion_name = " [D2R]";
                    elseif abs(scale_factor(1) - 180/pi) <1e-4
                        xconversion_name = "[R2D]";
                    else
                        if abs(scale_factor(1)) > 10000 || abs(scale_factor(1)) < 0.001
                            i = 1;
                        else
                            i = 2;
                        end
                        xconversion_name = " [" + string(num2str(scale_factor(1),obj.str_format{i})) + "]";
                    end
                else
                    xconversion_name = "";
                end

                % validate y scale factor
                if scale_factor(2) ~= 1
                    if ~obj.validScalarRealNum(scale_factor(2))
                        error("Invalid scale_factor(2). scale_factor(2) must be a real scalar number.")
                    end
                    if abs(scale_factor(1) - pi/180) <1e-4
                        yconversion_name = " [D2R]";
                    elseif abs(scale_factor(1) - 180/pi) <1e-4
                        yconversion_name = "[R2D]";
                    else
                        if abs(scale_factor(2)) > 10000 || abs(scale_factor(2)) < 0.001
                            i = 1;
                        else
                            i = 2;
                        end
                        yconversion_name = " [" + string(num2str(scale_factor(2),obj.str_format{i})) + "]";
                    end
                else
                    yconversion_name = "";
                end
                
                % remove the old line
                if ishandle(obj.pr.hLines(line_id,panel_id))
                    delete(obj.pr.hLines(line_id,panel_id))
                end
                % plot the new line
                line_idtag = "id_"+panel_id+"_"+line_id + "_" + source_id;
                obj.pr.hLines(line_id,panel_id) =...
                    scatter(obj.pr.hAxes(panel_id),...
                        xdata.value*scale_factor(1),ydata.value*scale_factor(2),500,...
                        'MarkerEdgeColor',obj.clr_rgb(line_id,:),...
                        'Marker','.',...
                        'LineWidth',2,...
                        'Tag',line_idtag,...
                        'DeleteFcn',@obj.rplot_hline_cleanup_callback);

                % update occupancy
                obj.pr_occupancy(line_id,panel_id) = source_id;
                obj.pr_occupied_variable(line_id,panel_id) =...
                    obj.gridSourceNames(source_id) + " - " + xdata.name + xconversion_name + "," +...
                     obj.gridSourceNames(source_id) + " - " + ydata.name + yconversion_name;
                
                % Update panel line name
                line_label = obj.sourceNames(source_id) + ": " + xdata.name + " vs " + ydata.name;
                obj.pr.update_panel_axes_label(panel_id,line_id,line_label,"X","Y")

                % update GUI panel if rplot is called from command line
                if ~call_from_gui
                    obj.update_gui_grid_tables(obj.grid_type(obj.RGRID),panel_id,line_id);
                end

                % update cursor
%                 obj.pr.update_cursor_lines()
            end

        end


    end

    methods( Access = public, Hidden = true )
        % Fucntions to support Graphical User Interface App

        function datamanager_please_help(obj)
            % datamanager_please_help() helps GUI App to process the inputs
            % data
            
            % First, parse throught the first 6 time grids to extract all
            % the variables for each source
            tvar_list = cell(obj.MaxNumberLines,obj.MaxNumberPanels);
            for i = 1:obj.MaxNumberPanels
                tvar_list(:,i) = obj.gui.(obj.grid_type(obj.TGRID)+i).Data;
            end
            tvar_list = string(tvar_list);

            rvar_list = cell(obj.MaxNumberLines,obj.MaxNumberPanels,2); % 2 for x and y
            for i = 1:obj.MaxNumberPanels
                rvar_list(:,i,1) = obj.gui.(obj.grid_type(obj.RGRID)+i).Data;
            end
            for i = 1:obj.MaxNumberPanels
                y_idx = i+obj.rplot_y_grid_offset;
                rvar_list(:,i,2) = obj.gui.(obj.grid_type(obj.RGRID)+y_idx).Data;
            end

            % Second, parse through var_list and load variables from the source
            for i = 1:obj.Nsource
                % if datastore doesn't exist, don't bother
                if isa(obj.th(i).ds,'matlab.io.datastore.TabularTextDatastore')
                    current_source = obj.sourceNames(i);
                    % find all variables match with current source
                    source_variables_tplot = tvar_list(contains(tvar_list,current_source));
                    source_variables_rplot = rvar_list(contains(tvar_list,current_source));
                    source_variables = [source_variables_tplot(:);source_variables_rplot(:)];

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

            % Third, check required type of plots
            plot_time = any(tvar_list ~= "",'all');
            plot_regular = any(rvar_list ~= "",'all');

            % Third, create a panel figure it doesn't exist
            if plot_time
                n_tpanels = string(obj.gui.tPanelNumberSelection.Value);
                n_tpanels = double(regexp(n_tpanels,'\d+','match'));
                obj.createPanel(n_tpanels)
            end
            if plot_regular
                n_rpanels = string(obj.gui.tPanelNumberSelection.Value);
                n_rpanels = double(regexp(n_rpanels,'\d+','match'));
                obj.createRplotPanel(n_rpanels)
            end

            % Fourth, plot data onto each panel
            if plot_time
                for i1 = 1:n_tpanels
                    panel_var_list = tvar_list(:,i1);
                    % Ensure there is no empty cell
                    if any(panel_var_list ~= "")
                        for i2 = 1:obj.Nsource
                            current_source = obj.gridSourceNames(i2);
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
                                end % i3 = 1:length(location_id)
                            end % if any(location_id)
                        end % i2 = 1:obj.Nsource
                    end % if any(panel_var_list ~= "")

                    % remove the old lines
                    line_ids = find(panel_var_list == "");
                    for line_id = line_ids
                        if ishandle(obj.pt.hLines(line_id,i1))
                            delete(obj.pt.hLines(line_id,i1))
                        end
                    end

                end % i1 = 1:n_tpanels
            end % if plot_time

            if plot_regular
                for i1 = 1:n_rpanels
                    panel_xvar_list = rvar_list(:,i1,1);
                    panel_yvar_list = rvar_list(:,i1,2);
                    if any(panel_xvar_list ~= "")
                        for i2 = 1:obj.Nsource
                            current_source = obj.gridSourceNames(i2);
                            % find all variables match with current source
                            location_id = contains(panel_xvar_list,current_source);
                            if any(location_id)

                                % panel_x_variables, panel_y_variables and
                                % location_id have the same length
                                panel_x_variables = string(panel_xvar_list(location_id));
                                panel_y_variables = string(panel_yvar_list(location_id));
                                location_id = find(location_id);
                                
                                % validate y variable's source
                                source_check = contains(panel_y_variables,current_source);
                                % Only process valid sources
                                location_id = location_id(source_check);

                                % split with "-" delimiter
                                source_x_variables = split(panel_x_variables,"-");
                                source_y_variables = split(panel_y_variables,"-");
                                % variable name is on the 2nd column
                                if size(source_x_variables,2) == 1
                                    source_x_variables = source_x_variables';
                                end
                                if size(source_y_variables,2) == 1
                                    source_y_variables = source_y_variables';
                                end
                                source_x_variables = strtrim(source_x_variables(:,2));
                                source_y_variables = strtrim(source_y_variables(:,2));
                                % Iterate through all the variables to plot
                                for i3 = 1:length(location_id)

                                    % source x variable name
                                    if contains(source_x_variables(i3),"[")
                                        tmp = split(source_x_variables(i3),"[");
                                        source_x_variable_name = char(strtrim(tmp(1)));
                                        % find the following:
                                        %   any group of characters 
                                        %   (specifically R2D and D2R) that can
                                        %   follow with decimal points and any
                                        %   scientific format characters
                                        conversion_name = string(regexp(tmp(2),"\w*(\.\d+)?((e|E)(-|+)?\d+)?",'match'));
                                        if conversion_name == "R2D"
                                            xscale_factor = 180/pi;
                                        elseif conversion_name == "D2R"
                                            xscale_factor = pi/180;
                                        else
                                            xscale_factor = double(conversion_name);
                                        end
                                    else
                                        source_x_variable_name = source_x_variables{i3};
                                        xscale_factor = 1;
                                    end

                                    % source y variable name
                                    if contains(source_y_variables(i3),"[")
                                        tmp = split(source_y_variables(i3),"[");
                                        source_y_variable_name = char(strtrim(tmp(1)));
                                        % find the following:
                                        %   any group of characters 
                                        %   (specifically R2D and D2R) that can
                                        %   follow with decimal points and any
                                        %   scientific format characters
                                        conversion_name = string(regexp(tmp(2),"\w*(\.\d+)?((e|E)(-|+)?\d+)?",'match'));
                                        if conversion_name == "R2D"
                                            yscale_factor = 180/pi;
                                        elseif conversion_name == "D2R"
                                            yscale_factor = pi/180;
                                        else
                                            yscale_factor = double(conversion_name);
                                        end
                                    else
                                        source_y_variable_name = source_y_variables{i3};
                                        yscale_factor = 1;
                                    end


                                    % if the values comes from derviedData
                                    if any(ismember(obj.th(i2).derivedData_names,source_x_variable_name)) &&...
                                            any(ismember(obj.th(i2).derivedData_names,source_y_variable_name))
                                        obj.rplot(i1,i2,... % arg1, arg2
                                                  obj.th(i2).derivedData.(source_x_variable_name),... % arg3
                                                  obj.th(i2).derivedData.(source_y_variable_name),... % arg4
                                                  location_id(i3),[xscale_factor, yscale_factor],true); % arg5, arg6, arg7
                                    elseif any(ismember(obj.th(i2).derivedData_names,source_x_variable_name))
                                        obj.rplot(i1,i2,... % arg1, arg2
                                                  obj.th(i2).derivedData.(source_x_variable_name),... % arg3
                                                  obj.th(i2).data.(source_y_variable_name),... % arg4
                                                  location_id(i3),[xscale_factor, yscale_factor],true); % arg5, arg6, arg7
                                    elseif any(ismember(obj.th(i2).derivedData_names,source_y_variable_name))
                                        obj.rplot(i1,i2,... % arg1, arg2
                                                  obj.th(i2).data.(source_x_variable_name),... % arg3
                                                  obj.th(i2).derivedData.(source_y_variable_name),... % arg4
                                                  location_id(i3),[xscale_factor, yscale_factor],true); % arg5, arg6, arg7
                                    else
                                        obj.rplot(i1,i2,... % arg1, arg2
                                                  obj.th(i2).data.(source_x_variable_name),... % arg3
                                                  obj.th(i2).data.(source_y_variable_name),... % arg4
                                                  location_id(i3),[xscale_factor, yscale_factor],true); % arg5, arg6, arg7
                                    end

                                end % i3 = 1:length(location_id)
                            end % if any(location_id)
                        end % i2 = 1:obj.Nsource
                    end % if any(panel_xvar_list ~= "")

                    % remove the old lines
                    line_ids = find(panel_xvar_list == "");
                    for line_id = line_ids'
                        if ishandle(obj.pr.hLines(line_id,i1))
                            delete(obj.pr.hLines(line_id,i1))
                        end
                    end

                end % i1 = 1:n_rpanels
            end % if plot_regular

        end

    end

    methods( Access = private )
        % Private Support Functions

        function tplot_hline_cleanup_callback(obj,src,~)

            % id_tag format: id_panelID_locationID
            id_tag = split(src.Tag,"_");
            panel_id = str2double(id_tag{2});
            loc_id = str2double(id_tag{3});
            obj.pt.update_panel_line_name(panel_id,loc_id,"");
            obj.pt.cleanup_panel_line_val(panel_id,loc_id);
            obj.pt_occupancy(loc_id,panel_id) = 0;
            obj.pt_occupied_variable(loc_id,panel_id) = "";
            
        end

        function rplot_hline_cleanup_callback(obj,src,~)

            % id_tag format: id_panelID_locationID
            id_tag = split(src.Tag,"_");
            panel_id = str2double(id_tag{2});
            loc_id = str2double(id_tag{3});
%             obj.pr.update_panel_line_name(panel_id,loc_id,"");
            obj.pr.cleanup_panel_line_val(panel_id,loc_id);
            obj.pr_occupancy(loc_id,panel_id) = 0;
            obj.pr_occupied_variable(loc_id,panel_id) = "";
            
        end

        function get_updated_tplot_cursor_src_idx(obj,~,~)
            obj.tplot_cursor_source_idx = obj.pt.cursor_source_idx;
        end

        function update_rplot_cursor(obj,~,~)
            % This function is only called when cursor is enabled
            if obj.pt.tplot_cursor_position_changed
                % Call
                % obj.pr.update_rplot_cursor(obj.tplot_cursor_source_idx)
                % here
            end
        end

        function update_gui_grid_tables(obj,varargin)
            % update_gui_grid_tables() update  the GUI App's grid table
            % when the user's plot data from command line.

            if isa(obj.gui,'DatViewer_GUI') && isvalid(obj.gui)
                
                update_all_lines = false;

                grid_type_in = varargin{1};
                grid_id = [];
                if nargin > 3
                    grid_id = varargin{2};
                    line_id = varargin{3};
                elseif nargin > 2
                    grid_id = varargin{2};
                    update_all_lines = true;
                end

                if grid_type_in == obj.grid_type(obj.TGRID) || grid_type_in == "all"
                    if isempty(grid_id)
                        for i = 1:obj.MaxNumberPanels
                            for j = 1:obj.MaxNumberLines
                                if obj.pt_occupied_variable(j,i) ~= ""
                                    obj.gui.(obj.grid_type(obj.TGRID)+i).Data{j} = obj.pt_occupied_variable{j,i};
                                end
                            end
                        end
                    elseif update_all_lines
                        for j = 1:obj.MaxNumberLines
                            obj.gui.(grid_type_in+grid_id).Data{j} = obj.pt_occupied_variable{j,grid_id};
                        end
                    else
                        obj.gui.(grid_type_in+grid_id).Data{line_id} = obj.pt_occupied_variable{line_id,grid_id};
                    end
                end

                if grid_type_in == obj.grid_type(obj.RGRID) || grid_type_in == "all"
                    if isempty(grid_id)
                        for i = 1:obj.MaxNumberPanels
                            for j = 1:obj.MaxNumberLines
                                if obj.pr_occupied_variable(j,i) ~= ""
                                    vars = strtrim(split(obj.pr_occupied_variable(j,i),","));
                                    ygrid_idx = i + obj.rplot_y_grid_offset;
                                    obj.gui.(obj.grid_type(obj.RGRID)+i).Data{j} = vars{1};
                                    obj.gui.(obj.grid_type(obj.RGRID)+ygrid_idx).Data{j} = vars{2};
                                end
                            end
                        end
                    elseif update_all_lines
                        for j = 1:obj.MaxNumberLines
                            if obj.pr_occupied_variable(j,grid_id) ~= ""
                                vars = strtrim(split(obj.pr_occupied_variable(j,grid_id),","));
                                ygrid_idx = grid_id + obj.rplot_y_grid_offset;
                                obj.gui.(grid_type_in+grid_id).Data{line_id} = vars{1};
                                obj.gui.(grid_type_in+ygrid_idx).Data{line_id} = vars{2};
                            end
                        end
                    else
                        vars = strtrim(split(obj.pr_occupied_variable(line_id,grid_id),","));
                        ygrid_idx = grid_id + obj.rplot_y_grid_offset;
                        obj.gui.(grid_type_in+grid_id).Data{line_id} = vars{1};
                        obj.gui.(grid_type_in+ygrid_idx).Data{line_id} = vars{2};
                    end
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
            if isa(obj.gui,'DatViewer_GUI') && isvalid(obj.gui) && ~isempty(obj.pt)
                if obj.gui.VerticalCursorButton.Value ~= obj.pt.cursor_status
                    obj.gui.VerticalCursorButton.Value = obj.pt.cursor_status;
                end
            end
        end

    end

end
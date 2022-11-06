classdef TimeData < handle
    
    % Public properties
    properties( SetAccess=protected, GetAccess=public )
        file_name (1,1) string = "";
        source_index string = "";

        ds  = []; % data store
        AvailableVariablesList string = [];
        
        data_names string = [];
        derivedData_names string = [];

    end

    properties( SetAccess=protected, GetAccess=public, SetObservable )
        data
    end

    properties( SetAccess=public, GetAccess=public, SetObservable )
        % Unlimited Power struct for user
        derivedData
    end
    
    % private properties
    properties( Access = private )
        data_
        PreviousSelectedList string = [];
        data_type (1,1) double;
    end

    properties( Constant=true, Access=private )
        % inialization Enumeration
        INIT_EMPTY_LOAD = 0
        INIT_FILE_LOAD = 1
        INIT_FILE_LOAD_ASSIGN_INDEX = 2
        
        % constants
        SUPPORTED_ASCII_DATA_TYPE = [".tx",".txt",".dat"];
        SUPPORTED_MATLAB_TYPE = ".mat";
        ASCII_TYPE = 1;
        MATLAB_TYPE = 2;
        SUPPORTED_MATLAB_CLASS = "table";
        ASSUMED_LINE_FOR_VARIABLES = 2
        
    end
    
    % Public methods
    methods( Access=public )

        % Constructor
        function obj = TimeData(varargin)
            
            switch nargin
                case 0
                    initialization_type = obj.INIT_EMPTY_LOAD;
                case 1
                    initialization_type = obj.INIT_FILE_LOAD;
                case 2
                    initalization_type = obj.INIT_FILE_LOAD_ASSIGN_INDEX;
                otherwise
                    error("Unsupported number of arguments...Toooo many arguments")
            end
            
            % If minimum 1 argument 
            if initialization_type >= obj.INIT_FILE_LOAD
                
                % Read in the first argument
                timehistory_filename = varargin{1};
                
                % Read data
                obj.read_timehistory_file(timehistory_filename);
                
                if initalization_type == obj.INIT_FILE_LOAD_ASSIGN_INDEX
                    obj.source_index = string(varargin{2});
                end
            end
            
        end
        
        % Read meta-data function
        function read_timehistory_file(obj,TimeHistoryFileName,SourceIndex)
            
            arguments
                obj
                TimeHistoryFileName (1,1) string
                SourceIndex (1,1) string
            end
            % TODO: Need to make SourceIndex an optional argument
            obj.file_name = TimeHistoryFileName;
            obj.source_index = SourceIndex;

            % Check file existence
            if ~exist(obj.file_name,'file')
                error("The file '"+obj.file_name +"' does not exist.")
            end

            if contains(obj.file_name,obj.SUPPORTED_ASCII_DATA_TYPE)

                obj.data_type = obj.ASCII_TYPE;

                % data import type detction
                VariableNames = get_data_variables(obj.file_name);
                obj.AvailableVariablesList = VariableNames;
    
                % create Format array to read data
                read_format = repmat({'%f'},1,length(VariableNames));
                % Try to parse data.
                try
                    obj.ds = tabularTextDatastore(obj.file_name,"FileExtensions",obj.SUPPORTED_ASCII_DATA_TYPE,...
                        "ReadVariableNames",false,...
                        "TextscanFormats",read_format,...
                        "Delimiter",[" ",",","\t"],...
                        "NumHeaderLines",2);
                    obj.ds.VariableNames = VariableNames;
                    obj.ds.SelectedVariableNames = "time";
    
                catch
                    error("Data in file '"+obj.file_name+"' is not rectangular or does not have "+...
                        length(read_format)+" columns");
                end
                
    
                for i = 1:length(VariableNames)
                    obj.data.(VariableNames{i}).value = [];
                end

            elseif contains(obj.file_name,obj.SUPPORTED_MATLAB_TYPE)

                obj.data_type = obj.MATLAB_TYPE;

                tmp = load(obj.file_name);
                varname = fieldnames(tmp);
                
                % Check for number of inputs and validate data type
                if length(varname) > 1 || ~isa(tmp.(varname{1}),obj.SUPPORTED_MATLAB_CLASS)
                    error("Only accept .mat file containing 1 'table' format type data");
                end

                % Check for existence of time
                if ~any(ismember(tmp.(varname{1}).Properties.VariableNames,'time'))
                    error("Table data must contain 'time' variable")
                end

                VariableNames = tmp.(varname{1}).Properties.VariableNames;

                for i = 1:length(VariableNames)
                    obj.data.(VariableNames{i}).value = tmp.(varname{1}).(VariableNames{i});
                end

            else
                error("Unsupported file type. Only accept .tx, .txt, .dat, and .mat")
            end
            
        end

        % Get a list of data using struct format
        function get_data(obj,varargin)

            if obj.data_type == obj.ASCII_TYPE
                InputVariableList = strings(1,nargin-1);
                if nargin == 2 && isstring(varargin{1})
                    InputVariableList = varargin{1};
                    if size(InputVariableList,1) > 1
                        InputVariableList = InputVariableList';
                    end
                else
                    for i = 1:nargin-1
                        tmp = varargin{i};
                        if isempty(tmp.value)
                            InputVariableList(i) = tmp.name;
                        end
                    end
                    InputVariableList(InputVariableList == "") = [];
                end
                InputVariableList = [InputVariableList, obj.PreviousSelectedList];
                obj.select_variables(InputVariableList);
            end
        end

        % Clean up data
        function cleanup_data(obj)

            if obj.data_type == obj.ASCII_TYPE
                DataVariableNames = string(fieldnames(obj.data));
                for i = 1:length(DataVariableNames)
                    if ~isempty(obj.data.(DataVariableNames{i}).value)
                        obj.data.(DataVariableNames{i}).value = [];
                    end
                end
                obj.data_names = [];
            end
        end

        % Clean up derived data
        function cleanup_derived_data(obj)

            DataVariableNames = string(fieldnames(obj.derivedData));
            for i = 1:length(DataVariableNames)
                if ~isempty(obj.derivedData.(DataVariableNames{i}).value)
                    obj.derivedData.(DataVariableNames{i}).value = [];
                end
            end
            obj.derivedData_names = [];

        end

        function [val_struct,error_status] = validate_data(obj,val_struct)

            % Check struct
            if ~isstruct(val_struct)
                error("Invalid data type. Expecting a struct with 'value' and 'name' field")
            end

            % Check 2 fields
            data_field_names = fieldnames(val_struct);
            if any(~contains(data_field_names,{'value','name'}))
                error("Data missing either 'value' or 'name' field")
            end

            % if val_struct belongs to derivedData
            if any(ismember(obj.derivedData_names,val_struct.name))
                % only check existence of data
                if isempty(val_struct.value)
                    error_status = 1;
                % assume 'time' variable always exists in data property
                elseif length(val_struct.value) ~= length(obj.data.time.value)
                    error_status = 2;
                else
                    error_status = 0;
                end
            else
                % check if data exists in obj.data
                if isempty(val_struct.value)
                    obj.get_data(val_struct.name);
                    val_struct = obj.data.(val_struct.name);
                    if isempty(val_struct.value)
                        error_status = 1;
                    else
                        error_status = 0;
                    end
                else
                    if ~contains(obj.AvailableVariablesList,val_struct.name)
                        msg = "Source " + obj.source_index + " does not have " + val_struct.name;
                        warning(msg);
                        error_status = 1;
                    else
                        error_status = 0;
                    end
                end
            end
            
            

        end
    end
    
    % Private methods
    methods( Access=private )


        % Extract only selected variables
        function select_variables(obj,InputVariableList)
            
            arguments
                obj
                InputVariableList string
            end

            % Save the old selected variables
            obj.PreviousSelectedList = obj.ds.SelectedVariableNames;

            %Validate the option with existing list
            InputVariableList = unique(["time",InputVariableList]);

            valid_variables_idx = contains(InputVariableList,obj.AvailableVariablesList);
            if sum(~valid_variables_idx)
                for i = find(~valid_variables_idx)
                    msg = "Source " + obj.source_index + " does not have " + InputVariableList(i);
                    warning(msg);
                end
            end
            
            % If there is at least 1 valid variables, reload data
            if sum(valid_variables_idx) > 0
                % ReLoad data
                obj.ds.reset();
                obj.ds.SelectedVariableNames = InputVariableList(valid_variables_idx);
                obj.data_ = obj.ds.read();
                obj.update_user_data();
            end

        end

        function update_user_data(obj)

            cleanup_indices = ~contains(obj.PreviousSelectedList,obj.ds.SelectedVariableNames);

            % Load data into user's data property
            for i = 1:length(obj.ds.SelectedVariableNames)
                obj.data.(obj.ds.SelectedVariableNames{i}).value = obj.data_.(obj.ds.SelectedVariableNames{i});
            end

            % Remove unused data
            if sum(cleanup_indices) ~= 0
                cleanup_indices = find(cleanup_indices);
                for i = cleanup_indices
                    obj.data.(obj.PreviousSelectedList{i}).value = [];
                end
            end

            obj.PreviousSelectedList = obj.ds.SelectedVariableNames;

        end

        function detect_data_for_vehicle_visualization(obj)
            % TODO: parse through obj.data and obj.derived_data to see if
            % there is enough variable to plot vehicle/airplane/missile
        end

        %--------------------- input validation ---------------------------
        function update_data_names(obj,new_variable_list)
            obj.data_names = new_variable_list;
        end

        function update_derivedData_names(obj,new_variable_list)
            obj.derivedData_names = new_variable_list;
        end

        function updateVar = validate_input(obj,newVariable,VariableName)

            if ~isstruct(newVariable)
                error("New variable must contain at least 'value' field");
            end
            field_names = string(fieldnames(newVariable));
            
            if ~contains(field_names,"value")
                error("New variable must have at least 'value' field");
            end
            updateVar = newVariable;
            if ~contains(field_names,"name")
                updateVar.name = VariableName;
            end
        end
        %--------------------- end input validation -----------------------
    end

    methods

        % ----------------------- data property ---------------------------
        function set.data(obj,val)

            var_names = string(fieldnames(val));
            if ~isempty(obj.data_names)
                idx = ~ismember(var_names,obj.data_names);
                if any(idx)
                    var_name = var_names(idx);
                else
                    var_name = var_names;
                end
            else
                var_name = var_names;
            end
            if length(var_name) == 1
                updateVar = obj.validate_input(val.(var_name),var_name);
                obj.data.(var_name) = updateVar;
                obj.update_data_names(string(fieldnames(obj.data)));
            else
                obj.data = val;
            end

        end

        % --------------------- end data property -------------------------

        % ------------------- derived data property -----------------------
        function set.derivedData(obj,val)

            var_names = string(fieldnames(val));
            if ~isempty(obj.derivedData_names)
                idx = ~ismember(var_names,obj.derivedData_names);
                if any(idx)
                    var_name = var_names(idx);
                else
                    var_name = var_names;
                end
            else
                var_name = var_names;
            end
            if length(var_name) == 1
                updateVar = obj.validate_input(val.(var_name),var_name);
                obj.derivedData.(var_name) = updateVar;
                obj.update_derivedData_names(string(fieldnames(obj.derivedData)));
            else
                obj.derivedData = val;
            end

        end

        % ------------------- end derived data property -------------------

    end
    
end
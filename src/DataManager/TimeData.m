classdef TimeData < handle
    
    % Public properties
    properties( SetAccess=protected, GetAccess=public )
        file_name (1,1) string = "";
        source_index string = "";

        ds  = []; % data store
        data
        data_
        AvailableVariablesList string = [];
        PreviousSelectedList string = [];

    end

    properties( SetAccess=public, GetAccess=public, SetObservable )
        % Unlimited Power struct for user
        derivedData
    end
    
    % private properties
    properties( Access=private )
        % inialization Enumeration
        INIT_EMPTY_LOAD = 0
        INIT_FILE_LOAD = 1
        INIT_FILE_LOAD_ASSIGN_INDEX = 2
        
        % constants
        SUPPORTED_DATA_TYPE = ".tx"
        ASSUMED_LINE_FOR_VARIABLES = 2
        data_format = "%f "
        
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


            % data import type detction
            VariableNames = get_data_variables(obj.file_name);
            obj.AvailableVariablesList = VariableNames;

            % create Format array to read data
%             read_format = string([obj.data_format{ones(1,length(VariableNames))}]);
%             read_format = strtrim(read_format);
%             read_format = strsplit(read_format," ");
            read_format = repmat({'%f'},1,length(VariableNames));
            % Try to parse data.
            try
                obj.ds = tabularTextDatastore(obj.file_name,"FileExtensions",obj.SUPPORTED_DATA_TYPE,...
                    "ReadVariableNames",false,...
                    "TextscanFormats",read_format,...
                    "Delimiter",[" ",",","\t"],...
                    "NumHeaderLines",2);
                obj.ds.VariableNames = VariableNames;
                obj.ds.SelectedVariableNames = "time";
                for i = 1:length(VariableNames)
                    obj.data.(VariableNames{i}).value = [];
                    obj.data.(VariableNames{i}).name = string(VariableNames(i));
                end

            catch
                error("Data in file '"+obj.file_name+"' is not rectangular or does not have "+...
                    length(read_format)+" columns");
            end
            
        end

        % Get a list of data using struct format
        function get_data(obj,varargin)

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

        % Clean up data
        function cleanup_data(obj)
            DataVariableNames = string(fieldnames(obj.data));
            for i = 1:length(DataVariableNames)
                if ~isempty(obj.data.(DataVariableNames{i}).value)
                    obj.data.(DataVariableNames{i}).value = [];
                end
            end
        end

        function [data,error_status] = validate_data(obj,data)

            % Check struct
            if ~isstruct(data)
                error("Invalid data type. Expecting a struct with 'value' and 'name' field")
            end

            % Check 2 fields
            data_field_names = fieldnames(data);
            if any(~contains(data_field_names,{'value','name'}))
                error("Data missing either 'value' or 'name' field")
            end

            % check if data exists
            if isempty(data.value)
                obj.get_data(data.name);
                data = obj.data.(data.name);
                if isempty(data.value)
                    error_status = 1;
                else
                    error_status = 0;
                end
            else
                if ~contains(obj.AvailableVariablesList,data.name)
                    msg = "Source " + obj.source_index + " does not have " + InputVariableList(i);
                    warning(msg);
                    error_status = 1;
                else
                    error_status = 0;
                end
            end

        end
    end
    
    % Private methods
    methods( Access=private )

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

        function detect_data_for_vehicle_visualization(obj)
            % TODO: parse through obj.data and obj.derived_data to see if
            % there is enough variable to plot vehicle/airplane/missile
        end

    end
    
    
end
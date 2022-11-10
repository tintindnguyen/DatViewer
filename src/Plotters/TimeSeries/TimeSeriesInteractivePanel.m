function CustomPanel = TimeSeriesInteractivePanel()

    % Parameters
    Nsignals = 6;
    u = uipanel('units', 'normalized');
    u.BackgroundColor = [0.5 0.5 0.5]; % Temporarily set to black

    % Table to display data
    dummy_data = cell(Nsignals+1,2);
    for i = 1:Nsignals
        dummy_data{i} = '';
    end
    
    t = uitable(u,"Data",dummy_data,...
                    "Unit","normalized",...
                    "Position",[0.01 0.1 1 0.9]);

    % Column name is part of the column width calculation. Add padding to Value to extend the column width
    t.ColumnName = ["               Name               ","              Value              "];
    t.ColumnEditable = false;
    t.Tag = "DataViewer";

%     % Button 1....
%     bConversion = uicontrol(u,"Style","pushbutton",...
%                               "Unit","normalized",...
%                               "Position",[0.76 .3 0.25 0.2]);
%     bConversion.Tag = "Button";
%     bConversion.String = "Button3";
% 
%     % Button 2....
%     bConversion = uicontrol(u,"Style","pushbutton",...
%                               "Unit","normalized",...
%                               "Position",[0.76 .55 0.25 0.2]);
%     bConversion.Tag = "Button";
%     bConversion.String = "Button2";
% 
%     % Button 3....
%     bConversion = uicontrol(u,"Style","pushbutton",...
%                               "Unit","normalized",...
%                               "Position",[0.76 .8 0.25 0.2]);
%     bConversion.Tag = "Button";
%     bConversion.String = "Button1";

    CustomPanel = u;
end
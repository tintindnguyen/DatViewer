function CustomPanel = TimeSeriesInteractivePanel()

    % Parameters
    Nsignals = 6;
%     clr_rgb = [0 1 0
%                1 0 1
%                0 0.4470 0.7410
%                0.4940 0.1840 0.5560
%                0.3010 0.7450 0.9330
%                0.6350 0.0780 0.1840];
%     clr_hex = ["#00FF00"
%                "#FF00FF"
%                "#0072BD"
%                "#7E2F8E"
%                "#4DBEEE"
%                "#A2142F"];
%     colorgen = @(color,text) ['<html><table><TR><TD style="color:',color,...
%                                                           ';font-weight: bold">',text,'</TD></TR> </table></html>'];

    u = uipanel('units', 'normalized');
    u.BackgroundColor = [0.5 0.5 0.5]; % Temporarily set to black

    % Table to display data
    dummy_data = cell(Nsignals,1);
    for i = 1:Nsignals
        dummy_data{i} = '';
    end
    
    t = uitable(u,"Data",dummy_data,...
                    "Unit","normalized",...
                    "Position",[0.01 0.1 0.75 0.9]);
    % Column name is part of the column width calculation. Add padding to Value to extend the column width
    t.ColumnName = ["                Value                "];
    t.ColumnEditable = false;
    t.Tag = "DataViewer";

    % Button 1....
    bConversion = uicontrol(u,"Style","pushbutton",...
                              "Unit","normalized",...
                              "Position",[0.76 .3 0.25 0.2]);
    bConversion.Tag = "Button";
    bConversion.String = "Button3";

    % Button 2....
    bConversion = uicontrol(u,"Style","pushbutton",...
                              "Unit","normalized",...
                              "Position",[0.76 .55 0.25 0.2]);
    bConversion.Tag = "Button";
    bConversion.String = "Button2";

    % Button 3....
    bConversion = uicontrol(u,"Style","pushbutton",...
                              "Unit","normalized",...
                              "Position",[0.76 .8 0.25 0.2]);
    bConversion.Tag = "Button";
    bConversion.String = "Button1";

    CustomPanel = u;
end
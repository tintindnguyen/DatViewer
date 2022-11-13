function CustomPanel = RegularPlotInteractivePanel()

    % Parameters
    Nsignals = 6;
    u = uipanel('units', 'normalized');
    u.BackgroundColor = [0.5 0.5 0.5];

    % Table to display data
    dummy_data = cell(Nsignals+1,2);
    for i = 1:Nsignals
        dummy_data{i} = '';
    end
    
    t = uitable(u,"Data",dummy_data,...
                    "Unit","normalized",...
                    "Position",[0.01 0.1 1 0.9]);

    % Column name is part of the column width calculation. Add padding to Value to extend the column width
    t.ColumnName = ["           X  Value             ","           Y  Value             "];
    t.ColumnEditable = false;
    t.Tag = "DataViewer";


    CustomPanel = u;
end
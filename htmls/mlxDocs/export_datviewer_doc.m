fnames = ["DatViewer_product_page"
             "mytbx_gs_top"
             "mytbx_ug_intro"
             "mytbx_reqts"
             "mytbx_features"
             "mytbx_setup"
             "function_launch_gui"
             "function_create_panel"
             "function_launch_gui"
             "function_create_panel"
             "function_tplot"
             "mytbx_example"
             "helpfuncbycat"
             ];

file_format_from = ".mlx";
file_format_to = ".html";

mlx_files = fnames + file_format_from;
html_files = "../" + fnames + file_format_to;

for i = 1:length(mlx_files)
    if ~exist(mlx_files(i),'file')
        error("File "+mlx_files(i)+" does not exists.")
    end
end


for i = 1:length(mlx_files)
    matlab.internal.liveeditor.openAndConvert(mlx_files{i},html_files{i});
end
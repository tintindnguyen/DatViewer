function data = get_ascii_data(fileName)

arguments
    fileName (1,1) string
end

opt = detectImportOptions(fileName,'FileType','text');
data = readtable(fileName,opt);

end
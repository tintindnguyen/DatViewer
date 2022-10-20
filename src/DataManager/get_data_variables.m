function vars_name = get_data_variables(filename)

arguments
    filename (1,1) string
end

if exist(filename,'file')
    if regexp(filename,'.tx')
        skiplines = 2;
    elseif regexp(filename,'.dat')
        skiplines = 1;
    else
        error("Invalid file type. Please input *.tx or *.dat file.")
    end
else
    error("File doesn't exist. File: " + filename)
end

fid = fopen(filename,'r');
lines = strings(2,1);
for i = 1:skiplines
    lines(i) = fgetl(fid);
end
fclose(fid);
vars_name = strsplit(lines(end),[" ",",","\t"]);
vars_name = regexprep(vars_name,"(\(|\))","");
if vars_name(1) ~= "time"
    vars_name = ["time" vars_name];
end



function vars_name = get_data_variables(filename,skiplines)

arguments
    filename (1,1) string
    skiplines (1,1) double
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



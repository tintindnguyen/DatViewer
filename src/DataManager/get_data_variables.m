function vars_name = get_data_variables(fileName,variableLineNumber)

arguments
    fileName (1,1) string
    variableLineNumber (1,1) double
end


fid = fopen(fileName,'r');
lines = strings(variableLineNumber,1);
for i = 1:variableLineNumber
    lines(i) = fgetl(fid);
end
fclose(fid);
vars_name = strsplit(lines(end),[" ",",","\t"]);
vars_name = regexprep(vars_name,"(\(|\))","");
if vars_name(1) ~= "time"
    vars_name = ["time" vars_name];
end



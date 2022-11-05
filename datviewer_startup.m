full_path = [mfilename('fullpath'),'.m'];
full_path = regexprep(full_path,'\\\w*\.m','');
addpath(genpath(fullfile(full_path,'src')))
addpath(genpath(fullfile(full_path,'utilities')))
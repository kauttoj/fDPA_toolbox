function fsl_bet_skullstrip(input_file,input_opts)

% required software: FSL 5.0, gunzip archiver
global fsl_root_command;

%The -f option in BET is used to set a fractional intensity threshold which determines where the edge of the final segmented brain is located. The default value is 0.5 and the valid range is 0 to 1. A smaller value for this threshold will cause the segmented brain to be larger and should be used when the overall result from BET is too small (inside the brain boundary). Obviously, larger values for this threshold have the opposite effect (making the segmented brain smaller). This parameter does not normally need to be used, but sometimes requires tuning for specific scanners/sequences to get the best results. It is not advisable to tune it for each individual image in general.

%The -g option in BET causes a gradient change to be applied to the previous threshold value. That is, the value of the -f intensity threshold will vary from the top to the bottom of the image, centred around the value specified with the -f option. The default value for this gradient option is 0, and the valid range is -1 to +1. A positive value will cause the intensity threshold to be smaller at the bottom of the image and larger at the top of the image. This will have the effect of increasing the estimated brain size in the bottom slices and reducing it in the top slices.

default_opts.f = 0.25; % fractional threshold; default=0.5
default_opts.f_second = 0.18; % fractional threshold (valid around ~0.15)
default_opts.g = 0; % fractional threshold, vertical gradient (bottom) (-1,1); default=0
default_opts.prefix = 'BET_skullstripped_';
default_opts.do_two_stage = 0;

opts = default_opts;

fprintf('---- FSL bet2 SkullStrip for file ''%s'' ----\n',input_file);

if nargin>1
    
    fprintf('..parsing options struct\n');
    orig_fnames = fieldnames(default_opts);
    input_fnames = fieldnames(input_opts);
    for i=1:length(input_fnames)
        found=0;
        for j=1:length(orig_fnames)
            if strcmp(input_fnames{i},orig_fnames{j})
                opts.(input_fnames{i})=input_opts.(input_fnames{i});
                found=1;
                break;
            end
        end
        if found==0
            opts.(input_fnames{i})=input_opts.(input_fnames{i});
        end
    end
    
end

opts_str= [];
opts_str = [opts_str,' -R'];
opts_str = [opts_str,' -g ',num2str(opts.g)];
prefix = opts.prefix;
if opts.do_two_stage==1
    opts_str = [opts_str,' -f ',num2str(opts.f_second)];
else
    opts_str = [opts_str,' -f ',num2str(opts.f)];
end

%opts_str

if length(input_file)>4 && strcmp(input_file(end-4),'.')
    file_id = input_file(end-3:end);
    input_file = input_file(1:end-4);
else
    if exist([input_file,'.img']) && exist([input_file,'.hdr'])
        file_id = '.img';
    elseif exist([input_file,'.nii'])
        file_id = '.nii';
    else
        error('Proper input file not found (img/hdr or nii)!!!')
    end
end


tic;

new_input_file = input_file;
if opts.do_two_stage==1
    fprintf('..running standard_space_roi...');
    output_file = [prefix,input_file,'_cutted'];
    new_input_file = output_file;
    str = [fsl_root_command,'standard_space_roi ',input_file,' ',output_file,' -b'];
    [status,cmdout] = unix(str);
    if status~=0
        fprintf('failed!\n');
        disp(cmdout)
        error('FSL standard_space_roi failed')
    end
    a=toc;
    fprintf('success! (duration %s)\n',sec2min(a));
    tic
end

fprintf('..running bet...');
output_file = [prefix,input_file];
str = [fsl_root_command,'bet ',new_input_file,' ',output_file,file_id,opts_str];
[status,cmdout] = unix(str);
if status~=0
    fprintf('failed!\n');
    disp(cmdout)
    error('FSL bet failed')
end

a=toc;
fprintf('success! (duration %s)\n',sec2min(a));

%fprintf('..finalizing files...');
%if opts.do_two_stage==1
%    delete([new_input_file,'.nii.gz']);
%end
a=[output_file,'.nii'];
if exist(a)==0
    %str = ['gunzip -f ',a];
     str = [fsl_root_command,'fslchfiletype NIFTI ',output_file];
    [status, result] = unix(str);
    if status~=0
        error(result)
    end
end  

end


function res = sec2min(sec)

sec = round(sec);

for i=1:length(sec)
    min = floor(sec(i)/60);
    a = round(sec(i) - 60*min);
    if a<10
        a=sprintf('%1.0f',a);
        a=['0',a];
    else
        a=sprintf('%2.0f',a);
    end
    if i==1
        str = [num2str(min),':',a];
    else
        str = [str,', ',[num2str(min),':',a]];
    end
end

res = str;

end
function fsl_normalization_part2(skullstrip,structural,functional_mean,all_functional,targetpath)
%FSL_NORMALIZATION Summary of this function goes here
%   Detailed explanation goes here
global fsl_root_command;

base_command = fsl_root_command;

[ProgramPath,~,~] = fileparts(which('fDPA_run.m'));

[a,structural_filename,structural_fileext]=fileparts(structural);
segmentpath = [a,filesep];

fprintf('--------- FSL normalization pipeline part2 -----------\n');

if ~isempty(dir([segmentpath,'my_affine_transf.mat']))
    fprintf(' affine normalization (skullstripped->MNI152) with FLIRT already done, skipping\n');
else
    tic;
    fprintf(' affine normalization (skullstripped->MNI152) with FLIRT...');
    str = [base_command,'flirt -ref "',ProgramPath,filesep,'Templates',filesep,'MNI152_T1_2mm_brain"',' -in "',skullstrip,'" -omat "',segmentpath,'my_affine_transf.mat"'];
    [status, result]=unix(str);
    if status~=0
        error(result)
    end
    a=toc;
    fprintf(' done (%isec)\n',round(a));
    
end

if ~isempty(dir([segmentpath,'my_nonlinear_transf*']))
    fprintf(' nonlinear normalization (T1->MNI152) with FNIRT already done, skipping\n');
else
    tic;
    fprintf(' nonlinear normalization (T1->MNI152) with FNIRT...');
    outfile = [segmentpath,'w',structural_filename,structural_fileext];    
    str = [base_command,'fnirt --in="',structural,'" --aff="',segmentpath,'my_affine_transf.mat" --cout="',segmentpath,'my_nonlinear_transf" --config=T1_2_MNI152_2mm --iout="',outfile,'"'];
    [status, result]=unix(str);
    if status~=0
        error(result)
    end
    a=toc;
    fprintf(' done (%imin)\n',round(a/60));
end

tic;
fprintf(' coregister (skullstripped<->mean functional) with FLIRT...');
str = [base_command,'flirt -ref "',skullstrip,'" -in "',functional_mean,'" -dof 7 -omat "',segmentpath,'func2struct.mat"'];
[status, result]=unix(str);
if status~=0
    error(result)
end
a=toc;
fprintf(' done (%isec)\n',round(a));

% fprintf(' apply transformations to T1 with APPLYWARP...');
% [a,b,c]=fileparts(structural);
% outfile = [a,filesep,'w',b,c];
% str = [base_command,'applywarp --interp=trilinear --ref=',ProgramPath,filesep,'Templates',filesep,'MNI152_T1_1mm',' --in=',structural,' --warp=my_nonlinear_transf --premat=func2struct.mat --out=',outfile];
% [status, result]=unix(str);
% if status~=0
%     error(result)
% end

printint = round(linspace(length(all_functional)/10,9*length(all_functional)/10,9));
printint = unique(printint);
N=length(printint);
k=1;

tic;
fprintf(' normalize functional data with APPLYWARP...');
for i=1:length(all_functional)
    
    if k<(N+1) && i==printint(k)
       fprintf(' %i%%',round(100*i/length(all_functional))) 
       k=k+1;
    end    
    
    infile = all_functional(i).name;
    [~,filename,~]=fileparts(all_functional(i).name);
    outfile = [targetpath,filesep,'w',filename];
    str = [base_command,'applywarp --interp=trilinear --ref="',ProgramPath,filesep,'Templates',filesep,'MNI152_T1_2mm_brain"',' --in="',infile,'" --warp="',segmentpath,'my_nonlinear_transf" --premat="',segmentpath,'func2struct.mat" --out=',outfile];
    [status, result]=unix(str);
    if status~=0
        error(result)
    end
    
    a=[outfile,'.img'];
    if exist(a,'file')==0
        %str = ['gunzip -f ',a];
        str = [base_command,'fslchfiletype NIFTI_PAIR ',outfile];
        [status, result] = unix(str);
        if status~=0
            error(result)
        end
    end
    
end
a=toc;
fprintf(' 100%% (%imin)\n',round(a/60));

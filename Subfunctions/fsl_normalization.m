function fsl_normalization(skullstrip,functional_mean,all_functional,structural)
%FSL_NORMALIZATION Summary of this function goes here
%   Detailed explanation goes here

base_command = 'fsl5.0-';

[ProgramPath, notneeded1, notneeded2] = fileparts(which('fDPA_run.m'));

new_structural = ['biascor_',structural];

fprintf('--------- FSL normalization pipeline -----------\n');

tic;
fprintf(' bias-field correction with FAST...');
str = [base_command,'fast -S 1 -t 1 -o ',new_structural,' -n 3 -B ',structural];
[status, result]=unix(str);
if status~=0
    error(result)
end
delete([new_structural,'_mixeltype.nii.gz']);
delete([new_structural,'_pveseg.nii.gz']);
delete([new_structural,'_pve_0.nii.gz']);
delete([new_structural,'_pve_1.nii.gz']);
delete([new_structural,'_pve_2.nii.gz']);
delete([new_structural,'_seg.nii.gz']);
str = ['gunzip -f ',new_structural,'_restore.nii.gz'];
[status, result] = unix(str);
if status~=0
    error(result)
end
movefile([new_structural,'_restore.nii'],[new_structural,'.nii'])
a=toc;
fprintf(' done (%imin)\n',round(a/60));

tic;
fprintf(' affine transformation (skullstripped) with FLIRT...');
str = [base_command,'flirt -ref ',ProgramPath,filesep,'Templates',filesep,'MNI152_T1_2mm_brain',' -in ',skullstrip,' -omat my_affine_transf.mat'];
[status, result]=unix(str);
if status~=0
    error(result)
end
a=toc;
fprintf(' done (%isec)\n',round(a));

tic;
fprintf(' nonlinear transformation (normalization) with FNIRT...');
str = [base_command,'fnirt --in=',new_structural,' --aff=my_affine_transf.mat --cout=my_nonlinear_transf --config=T1_2_MNI152_2mm'];
[status, result]=unix(str);
if status~=0
    error(result)
end
a=toc;
fprintf(' done (%isec)\n',round(a));

tic;
fprintf(' affine transformation (coregistration) with FLIRT...');
str = [base_command,'flirt -ref ',skullstrip,' -in ',functional_mean,' -dof 7 -omat func2struct.mat'];
[status, result]=unix(str);
if status~=0
    error(result)
end
a=toc;
fprintf(' done (%isec)\n',round(a));

tic;
fprintf(' apply transformation with APPLYWARP...');
for i=1:length(all_functional)
    infile = all_functional(i).name;
    outfile = ['w',all_functional(i).name];
    str = [base_command,'applywarp --interp trilinear --ref=',ProgramPath,filesep,'Templates',filesep,'MNI152_T1_2mm_brain',' --in=',infile,' --warp=my_nonlinear_transf --premat=func2struct.mat --out=',outfile];
    [status, result]=unix(str);
    if status~=0
        error(result)
    end
% str = ['gunzip -f ',new_structural,'_restore.nii.gz'];
% [status, result] = unix(str);
% if status~=0
%     error(result)
% end
% movefile([new_structural,'_restore.nii'],[new_structural,'.nii'])    
end
a=toc;
fprintf(' done (%imin)\n',round(a/60));


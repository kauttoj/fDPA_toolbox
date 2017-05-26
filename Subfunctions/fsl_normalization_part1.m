function fsl_normalization_part1(structural)
%FSL_NORMALIZATION Summary of this function goes here
%   Detailed explanation goes here
global fsl_root_command;

base_command = fsl_root_command;

[ProgramPath, notneeded1, notneeded2] = fileparts(which('fDPA_run.m'));

[filepath,filename,notneeded2]=fileparts(structural);
new_structural = [filepath,filesep,'FAST_biascorrected_',filename];

fprintf('--------- FSL normalization pipeline part1 -----------\n');

tic;
fprintf(' bias-field correction for T1 with FAST...');
str = [base_command,'fast -S 1 -t 1 -o ',new_structural,' -n 3 -B ',structural];
[status, result]=unix(str);
if status~=0
    error(result)
end
%delete([new_structural,'_mixeltype.nii.gz']);
%delete([new_structural,'_pveseg.nii.gz']);
delete([new_structural,'_pve_0.nii.gz']);
delete([new_structural,'_pve_1.nii.gz']);
delete([new_structural,'_pve_2.nii.gz']);
%delete([new_structural,'_seg.nii.gz']);

a=[new_structural,'_restore.nii'];
if exist(a)==0
    %str = ['gunzip -f ',a];
     str = [base_command,'fslchfiletype NIFTI ',a(1:end-4)];
    [status, result] = unix(str);
    if status~=0
        error(result)
    end
end
movefile([new_structural,'_restore.nii'],[new_structural,'.nii'])
a=toc;
fprintf(' done (%imin)\n',round(a/60));


function y_NormalizeWrite(SourceFile,OutFile,RefFile,ParameterFile,Interp)
% FORMAT y_NormalizeWrite(SourceFile,OutFile,RefFile,ParameterFile,Interp)
%   SourceFile - source filename
%   OutFile - output filename
%   RefFile - reference file to get the voxsize and bounding box
%   ParameterFile - the parameter for normalization. Usually *seg_inv_sn.mat genereated by T1 image segmentation
%   Interp - interpolation method. 0: Nearest Neighbour. 1: Trilinear.
%__________________________________________________________________________
% Written by YAN Chao-Gan 101010 for DPARSF.
% State Key Laboratory of Cognitive Neuroscience and Learning, Beijing Normal University, China, 100875
% ycg.yan@gmail.com

if nargin<=4
    Interp=1;
end

[SourcePath, SourceFileName, SourceExtn] = fileparts(SourceFile);
[Data Head]=rest_ReadNiftiImage(SourceFile);
Head.pinfo = [1;0;0];
TempFileName=[tempdir,filesep,SourceFileName,SourceExtn];
rest_WriteNiftiImage(Data,Head,TempFileName);

[ProgramPath, fileN, extn] = fileparts(which('DPARSFA_run.m'));
[SPMversion,c]=spm('Ver');
SPMversion=str2double(SPMversion(end));

load([ProgramPath,filesep,'Jobmats',filesep,'Normalize_Write.mat']);
[mn, mx, voxsize]= y_GetBoundingBox(RefFile);
i=1;
jobs{1,i}.spatial{1,1}.normalise{1,1}.write.subj.matname={ParameterFile};
jobs{1,i}.spatial{1,1}.normalise{1,1}.write.subj.resample={TempFileName};
jobs{1,i}.spatial{1,1}.normalise{1,1}.write.roptions.bb=[mn;mx];
jobs{1,i}.spatial{1,1}.normalise{1,1}.write.roptions.vox=voxsize;
jobs{1,i}.spatial{1,1}.normalise{1,1}.write.roptions.interp=Interp;

if SPMversion==5
    spm_jobman('run',jobs);
elseif SPMversion==8  %YAN Chao-Gan, 090925. SPM8 compatible.
    jobs = spm_jobman('spm5tospm8',{jobs});
    spm_jobman('run',jobs{1});
else
    uiwait(msgbox('The current SPM version is not supported by DPARSF. Please install SPM5 or SPM8 first.','Invalid SPM Version.'));
    return
end


%Rename the warped AAL image
% [SourcePath, SourceFileName, SourceExtn] = fileparts(SourceFile);
% [OutPath, OutName, OutExtn] = fileparts(OutFile);
% movefile([SourcePath,filesep,'w',SourceFileName,'.img'],[OutPath,filesep,OutName,'.img']);
% movefile([SourcePath,filesep,'w',SourceFileName,'.hdr'],[OutPath,filesep,OutName,'.hdr']);
[Path, FileName, Extn] = fileparts(TempFileName);
[Data Head]=rest_ReadNiftiImage([Path,filesep,'w',FileName, Extn]);
Head.pinfo = [1;0;0];
rest_WriteNiftiImage(Data,Head,OutFile);
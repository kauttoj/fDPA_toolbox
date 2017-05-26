function [SkullstrippedList2] = TestingSegmentation_run2 (T1ImageFile)
%this function testingSegmentation (coT1ImageFile) applies different values
%to find the optimal ones for segmentation of the anatomical image in
%question (it presumes the anatomical are close to AC space) and it runs
%variable combinations of variables - the user still has to verify which
%ones gave the optimal results
%Not implemented yet - i should output the list of all produced skullstripped images 


[dirToGoTo,  T1name, T1ext] = fileparts(which(T1ImageFile));% the skull tripped anatomical will be written to the current directory so
%so we have to change to it before performing the job
startingDir = pwd;
% if isempty(dirToGoTo)
%     dirToGoTo = startingDir;
% end
cd (dirToGoTo);
if strcmp(T1ext,'.img')
    dirHDR=dir ([T1name,'.hdr']);
    T1ImageOriginal={fullfile(dirToGoTo,  [T1name T1ext]) ,fullfile([dirToGoTo, filesep, dirHDR(1).name])};
% saving the position of the original anatomical files 
else 
    T1ImageOriginal= {fullfile(dirToGoTo,  [T1name T1ext]) };
end


%Regularization penalties (0 - no regularization)
biasregTestset={0.00001; 0.0001; 0.0010; 0.0100; 0.1}
%FWHM of BIAS FIELD fit (took every second value)
biasfwhmTestset={30;60;90}
%Number of Gaussian clusters per tissue type (default 2,2,2,4)

% ngausTestset{1}= [2;2;2;4];
% ngausTestset{2} = [3;3;3;5];
% ngausTestset{3} = [4;4;4;6];
% ngausTestset{4} = [5;5;5;7];
% ngausTestset{5} = [2;2;2;7];
ngausTestset{1} = [2;2;3;7];
ngausTestset{2} = [2;2;4;7];
ngausTestset{3} = [5;5;2;6];

nrun = length(biasregTestset)*length(biasfwhmTestset)*length(ngausTestset);
[ProgramPath, notneeded1, notneeded2] = fileparts(which('fDPA_run_yh.m'));% notneeded1,2 variable is used for compatibility with Matlab 2009 ...
[SPMPath, notneeded1, notneeded2] = fileparts(which('spm.m'));
jobfile = {[ProgramPath,filesep,'Jobmats',filesep,'TestingSeparateSegmentationSPM8job_job.m']};%this job has 2mm sampling, throrouuch clean and SINC2 interpolation
%Downloading the job into matlabbatch variable which we will modify with
%our test variables
try
fid = fopen(jobfile{1},'rt');
str = fread(fid,'*char');
fclose(fid);
eval(str);
catch
warning('spm:spm_jobman:LoadFailed','Load failed: ''%s''',jobfile{1});
end
if ~(exist('jobs','var') || exist('matlabbatch','var'))
warning('spm:spm_jobman:JobNotFound','No SPM5/SPM8 job found in ''%s''', jobfile{1});
end
jobs = repmat(matlabbatch, 1, nrun)
jobstep= size(matlabbatch,2); % we expect it to be two (the number of modules in the called job)
k=1;
d=1;%newDirectoryName index
%First we need to create the directories and copy the co*.img files into the
%corresponding test-directories
newdirNameList = cell(1,length(biasregTestset)*length(biasfwhmTestset)*length(ngausTestset));
SkullstrippedList2 = cell(1,length(biasregTestset)*length(biasfwhmTestset)*length(ngausTestset));
for i = 1:length(biasregTestset)
    for ii = 1:length(biasfwhmTestset)
        dirPrefix=['Reg',num2str(biasregTestset{i}),'FWHM',num2str(biasfwhmTestset{ii})];
        for iii = 1:length(ngausTestset)
            ClusterPrefix = 'Clust';
            for iiii = 1:4%this loop is to avoid white spaces in the filenames
                ClusterPrefix = [ClusterPrefix num2str(ngausTestset{1,iii}(iiii))];
            end
            newdirName = [dirToGoTo filesep dirPrefix ClusterPrefix];
            newdirNameList{d} = newdirName;
            SkullstrippedList2{d}=[newdirName filesep 'skullstripped.img'];
            d=d+1;
            createFolder(newdirName);
            for j=1:length(T1ImageOriginal)
                copyfile(T1ImageOriginal{1,j},newdirName);
            end
            %next we modify the jobs variable
            jobs{1,k}.spm.spatial.preproc.opts.ngaus=ngausTestset{iii};
            jobs{1,k}.spm.spatial.preproc.opts.biasreg=biasregTestset{i};
            jobs{1,k}.spm.spatial.preproc.opts.biasfwhm=biasfwhmTestset{ii};
            jobs{1,k+2}.spm.util.imcalc.outdir = {newdirName};%this is the output directory for ImCalc (skullstripping)
            k= k + jobstep;            
        end
    end
end
for crun = 1:nrun
    T1Image = fullfile(newdirNameList{1,crun},filesep, [T1name T1ext]);
    inputs{1, crun} = {T1Image}; % Segment: Data - cfg_files
    inputs{2, crun} = {[SPMPath,filesep,'tpm',filesep,'grey.nii'];[SPMPath,filesep,'tpm',filesep,'white.nii'];[SPMPath,filesep,'tpm',filesep,'csf.nii']}; % Segment: Tissue probability maps - cfg_files
end
spm('defaults', 'FMRI');
spm_jobman('serial', jobs, '', inputs{:});
cd (startingDir);
save('SkullstrippedList2');


%     
%             mkdir(['..',filesep,'..',filesep,'T1ImgSegment',filesep,AutoDataProcessParameter.SubjectID{i}])
%             % Check in co* image exist. Added by YAN Chao-Gan 100510.
%             if UseNoCoT1Image==0
%                 copyfile('co*',['..',filesep,'..',filesep,'T1ImgSegment',filesep,AutoDataProcessParameter.SubjectID{i}])
% 
%     
%     
% function segmentT1Image(T1ImageFile, type)% note , this  segmentation uses the defaults values for AMI     centre () GE, European Template)
%             [dirToGoTo,  notneeded1, notneeded2] = fileparts(T1ImageFile);% the skull tripped anatomical will be written to the current directory so
%             %so we have to change to it before performing the job
%             startingDir = pwd;
%             cd (dirToGoTo);
%             if strcmpi(type,'mni')
%                 %segmentjobfile = {[ProgramPath,filesep,'Jobmats',filesep,'Segment2012MNI_job.m']};
%                 segmentjobfile = {[ProgramPath,filesep,'Jobmats',filesep,'Segment2012MNI_skullstrip_job.m']};%creates also the skullstrip version
%                 %which should improve the coregistration considerably,
%                 %the outputfile name
%             else
%                 segmentjobfile = {[ProgramPath,filesep,'Jobmats',filesep,'Segment2012Eastern_skullstrip_job.m']};
%             end
%             segmentjobs = repmat(segmentjobfile, 1, 1);
%             inputs = cell(2, 1);
%                 inputs{1,1} = {[T1ImageFile]}; % Segment: Data - cfg_files
%                 inputs{2,1} = {[SPMPath,filesep,'tpm',filesep,'grey.nii'];[SPMPath,filesep,'tpm',filesep,'white.nii'];[SPMPath,filesep,'tpm',filesep,'csf.nii']};
%                 % Segment: Tissue probability maps - cfg_files            
%             spm('defaults', 'FMRI');
%             spm_jobman('serial', segmentjobs, '', inputs{:});
%             clear segmentjobs % clears the variable segmentjobs
%             cd (startingDir);
% end
% 
% length
% jobs = repmat(jobfile, 1, nrun);
% inputs = cell(1, nrun);
% for crun = 1:nrun
%     inputs{1, crun} = MATLAB_CODE_TO_FILL_INPUT; % Segment: Data - cfg_files
% end
% spm('defaults', 'FMRI');
% spm_jobman('serial', jobs, '', inputs{:});

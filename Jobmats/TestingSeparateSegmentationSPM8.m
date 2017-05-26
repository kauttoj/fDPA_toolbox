function [SkullstrippedList] = testingSegmentation (T1ImageFile)
%this function testingSegmentation (coT1ImageFile) applies different values
%to find the optimal ones for segmentation of the anatomical image in
%question (it presumes the anatomical are close to AC space) and it runs
%variable combinations of variables - the user still has to verify which
%ones gave the optimal results
%Not implemented yet - i should output the list of all produced skullstripped images 


[dirToGoTo,  notneeded1, notneeded2] = fileparts(T1ImageFile);% the skull tripped anatomical will be written to the current directory so
%so we have to change to it before performing the job
startingDir = pwd;
cd (dirToGoTo);

%Regularization penalties (0 - no regularization)
biasregTestset={0; 0.00001; 0.0001; 0.0010; 0.0100; 0.1}
%FWHM of BIAS FIELD fit (took every second value)
biasfwhmTestset={30;60;90}
%Number of Gaussian clusters per tissue type (default 2,2,2,4)

ngausTestset{1}= [2;2;2;4];
ngausTestset{2} = [3;3;3;5];
ngausTestset{3} = [4;4;4;6];
ngausTestset{4} = [5;5;5;7];
ngausTestset{5} = [2;2;2;7];
ngausTestset{6} = [2;2;3;7];
ngausTestset{7} = [2;2;4;7];
ngausTestset{8} = [5;5;2;6];

nrun = length(biasregTestset)*length(biasfwhmTestset)*length(ngausTestset);
[ProgramPath, notneeded1, notneeded2] = fileparts(which('fDPA_run_yh.m'));% notneeded1,2 variable is used for compatibility with Matlab 2009 ...
[SPMPath, notneeded1, notneeded2] = fileparts(which('spm.m'));

jobfile = {[ProgramPath,filesep,'Jobmats',filesep,'separateSegmentationSPM8_job.m']};
%Downloading the job into matlabbatch variable which we will modify with
%our test variables
try
fid = fopen(jobfile{1},'rt');
str = fread(fid,'*char');
fclose(fid);
eval(str);
catch
warning('spm:spm_jobman:LoadFailed','Load failed: ''%s''',filenames{cf});
end
if ~(exist('jobs','var') || exist('matlabbatch','var'))
warning('spm:spm_jobman:JobNotFound','No SPM5/SPM8 job found in ''%s''', filenames{cf});
end

%First we need to create the directories and copy the co*.img files into the
%corresponding test-directories

for i = 1:length(biasregTestset)
    for ii = 1:length(biasfwhmTestset)
        dirPrefix=['Reg',num2str(biasregTestset{i}),'FWHM',num2str(biasfwhmTestset{ii})];
        for iii = 1:length(ngausTestset)
            ClusterPrefix = 'Clust';
            for iiii = 1:4%this loop is to avoid white spaces in the filenames
                ClusterPrefix = [ClusterPrefix num2str(ngausTestset{1,iii}(iiii))];
            end
            newdirName = [dirPrefix ClusterPrefix]
        end
    end
end
    


    
    
function segmentT1Image(T1ImageFile, type)% note , this  segmentation uses the defaults values for AMI     centre () GE, European Template)
            [dirToGoTo,  notneeded1, notneeded2] = fileparts(T1ImageFile);% the skull tripped anatomical will be written to the current directory so
            %so we have to change to it before performing the job
            startingDir = pwd;
            cd (dirToGoTo);
            if strcmpi(type,'mni')
                %segmentjobfile = {[ProgramPath,filesep,'Jobmats',filesep,'Segment2012MNI_job.m']};
                segmentjobfile = {[ProgramPath,filesep,'Jobmats',filesep,'Segment2012MNI_skullstrip_job.m']};%creates also the skullstrip version
                %which should improve the coregistration considerably,
                %the outputfile name
            else
                segmentjobfile = {[ProgramPath,filesep,'Jobmats',filesep,'Segment2012Eastern_skullstrip_job.m']};
            end
            segmentjobs = repmat(segmentjobfile, 1, 1);
            inputs = cell(2, 1);
                inputs{1,1} = {[T1ImageFile]}; % Segment: Data - cfg_files
                inputs{2,1} = {[SPMPath,filesep,'tpm',filesep,'grey.nii'];[SPMPath,filesep,'tpm',filesep,'white.nii'];[SPMPath,filesep,'tpm',filesep,'csf.nii']};
                % Segment: Tissue probability maps - cfg_files            
            spm('defaults', 'FMRI');
            spm_jobman('serial', segmentjobs, '', inputs{:});
            clear segmentjobs % clears the variable segmentjobs
            cd (startingDir);
end

length
jobs = repmat(jobfile, 1, nrun);
inputs = cell(1, nrun);
for crun = 1:nrun
    inputs{1, crun} = MATLAB_CODE_TO_FILL_INPUT; % Segment: Data - cfg_files
end
spm('defaults', 'FMRI');
spm_jobman('serial', jobs, '', inputs{:});

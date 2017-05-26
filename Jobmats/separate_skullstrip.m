function separate_skullstrip(mT1ImageFile,isnii)

if nargin<2
    ending = '.img';
else
    ending = '.nii';
end

[dirToGoTo,  notneeded1, notneeded2] = fileparts(mT1ImageFile);
if isempty(dirToGoTo)
    dirToGoTo=pwd;
end

%so we have to change to it before performing the job
startingDir = pwd;
cd (dirToGoTo);
[ProgramPath, notneeded1, notneeded2] = fileparts(which('fDPA_run.m'));
stripJobfile = {[ProgramPath,filesep,'Jobmats',filesep,'skullstrip_job.m']};
stripjobs = repmat(stripJobfile, 1, 1);
cDir= dir(['c1*',ending]);
c1Img=cDir(1).name;
cDir= dir(['c2*',ending]);
c2Img=cDir(1).name;
cDir= dir(['c3*',ending]);
c3Img=cDir(1).name;
images =cell(4,1);
images{1} = mT1ImageFile;
images{2} = [dirToGoTo filesep c1Img];
images{3} = [dirToGoTo filesep c2Img];
images{4} = [dirToGoTo filesep c3Img];
inputs{1, 1} = images; % Image Calculator: Input Images - cfg_files
%spm('defaults', 'FMRI');
spm_jobman('initcfg');
spm_jobman('serial', stripjobs, '', inputs{:});
clear stripjobs;
cd (startingDir)
end

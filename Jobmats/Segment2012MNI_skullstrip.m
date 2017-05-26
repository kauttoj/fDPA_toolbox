% List of open inputs
% Segment: Data - cfg_files
% Segment: Tissue probability maps - cfg_files
nrun = X; % enter the number of runs here
jobfile = {'/root/matlab/spm8/spm8/toolbox/fDPA_12092012/Jobmats/Segment2012MNI_skullstrip_job.m'};
jobs = repmat(jobfile, 1, nrun);
inputs = cell(2, nrun);
for crun = 1:nrun
    inputs{1, crun} = MATLAB_CODE_TO_FILL_INPUT; % Segment: Data - cfg_files
    inputs{2, crun} = MATLAB_CODE_TO_FILL_INPUT; % Segment: Tissue probability maps - cfg_files
end
spm('defaults', 'FMRI');
spm_jobman('serial', jobs, '', inputs{:});

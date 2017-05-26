% List of open inputs
% Image Calculator: Input Images - cfg_files
nrun = X; % enter the number of runs here
jobfile = {'/root/matlab/spm8/spm8/toolbox/fDPA_12092012/Jobmats/skullstrip_job.m'};
jobs = repmat(jobfile, 1, nrun);
inputs = cell(1, nrun);
for crun = 1:nrun
    inputs{1, crun} = MATLAB_CODE_TO_FILL_INPUT; % Image Calculator: Input Images - cfg_files
end
spm('defaults', 'FMRI');
spm_jobman('serial', jobs, '', inputs{:});

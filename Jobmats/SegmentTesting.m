% List of open inputs
% Segment: Data - cfg_files
% Segment: Tissue probability maps - cfg_files
% Segment: Affine Regularisation - cfg_menu
nrun = X; % enter the number of runs here
jobfile = {'K:\fDPA_12092012\Jobmats\SegmentTesting_job.m'};
jobs = repmat(jobfile, 1, nrun);
inputs = cell(3, nrun);
for crun = 1:nrun
    inputs{1, crun} = MATLAB_CODE_TO_FILL_INPUT; % Segment: Data - cfg_files
    inputs{2, crun} = MATLAB_CODE_TO_FILL_INPUT; % Segment: Tissue probability maps - cfg_files
    inputs{3, crun} = MATLAB_CODE_TO_FILL_INPUT; % Segment: Affine Regularisation - cfg_menu
end
spm('defaults', 'FMRI');
spm_jobman('serial', jobs, '', inputs{:});

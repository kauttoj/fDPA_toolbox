% List of open inputs
nrun = X; % enter the number of runs here
jobfile = {'C:\Program Files\MATLAB\R2010a\toolbox\DPARSF_V2.0_110505\Jobmats\Segment_orig_job.m'};
jobs = repmat(jobfile, 1, nrun);
inputs = cell(0, nrun);
for crun = 1:nrun
end
spm('defaults', 'FMRI');
spm_jobman('serial', jobs, '', inputs{:});

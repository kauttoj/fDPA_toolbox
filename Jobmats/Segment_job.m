%-----------------------------------------------------------------------
% Job configuration created by cfg_util (rev $Rev: 4252 $)
%-----------------------------------------------------------------------
matlabbatch{1}.spm.spatial.preproc.data = {'D:\test\DPARSF\T1ImgSegment\YH_28\co20110517_101355NeuroCine2011yevhen5YH28s005a1001.img,1'};
matlabbatch{1}.spm.spatial.preproc.output.GM = [1 1 1];
matlabbatch{1}.spm.spatial.preproc.output.WM = [1 1 1];
matlabbatch{1}.spm.spatial.preproc.output.CSF = [1 1 1];
matlabbatch{1}.spm.spatial.preproc.output.biascor = 1;
matlabbatch{1}.spm.spatial.preproc.output.cleanup = 2;
matlabbatch{1}.spm.spatial.preproc.opts.tpm = {
                                               'C:\Program Files\MATLAB\R2010a\toolbox\spm8\tpm\grey.nii,1'
                                               'C:\Program Files\MATLAB\R2010a\toolbox\spm8\tpm\white.nii,1'
                                               'C:\Program Files\MATLAB\R2010a\toolbox\spm8\tpm\csf.nii,1'
                                               };
matlabbatch{1}.spm.spatial.preproc.opts.ngaus = [5
                                                 5
                                                 2
                                                 6];
matlabbatch{1}.spm.spatial.preproc.opts.regtype = 'mni';
matlabbatch{1}.spm.spatial.preproc.opts.warpreg = 1;
matlabbatch{1}.spm.spatial.preproc.opts.warpco = 100;
matlabbatch{1}.spm.spatial.preproc.opts.biasreg = 0.01;
matlabbatch{1}.spm.spatial.preproc.opts.biasfwhm = 60;
matlabbatch{1}.spm.spatial.preproc.opts.samp = 3;
matlabbatch{1}.spm.spatial.preproc.opts.msk = {''};

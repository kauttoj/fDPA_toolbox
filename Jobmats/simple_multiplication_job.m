%-----------------------------------------------------------------------
% Job configuration created by cfg_util (rev $Rev: 4252 $)
%-----------------------------------------------------------------------
matlabbatch{1}.spm.util.imcalc.input = {
                                        'image1.nii,1'
                                        'image2.nii,1'
                                        };
matlabbatch{1}.spm.util.imcalc.output = 'output.img';
matlabbatch{1}.spm.util.imcalc.outdir = {''};
matlabbatch{1}.spm.util.imcalc.expression = 'i1.*i2';
matlabbatch{1}.spm.util.imcalc.options.dmtx = 0;
matlabbatch{1}.spm.util.imcalc.options.mask = 0;
matlabbatch{1}.spm.util.imcalc.options.interp = 1;
matlabbatch{1}.spm.util.imcalc.options.dtype = 16;

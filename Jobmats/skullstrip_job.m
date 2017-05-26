%-----------------------------------------------------------------------
% Job configuration created by cfg_util (rev $Rev: 3599 $)
%-----------------------------------------------------------------------
matlabbatch{1}.spm.util.imcalc.input = '<UNDEFINED>';
matlabbatch{1}.spm.util.imcalc.output = 'skullstripped.img';
matlabbatch{1}.spm.util.imcalc.outdir = {''};
matlabbatch{1}.spm.util.imcalc.expression = 'i1.*((i2+i3+i4 )>0.5)'; % i4
matlabbatch{1}.spm.util.imcalc.options.dmtx = 0;
matlabbatch{1}.spm.util.imcalc.options.mask = 0;
matlabbatch{1}.spm.util.imcalc.options.interp = 1;
matlabbatch{1}.spm.util.imcalc.options.dtype = 4;

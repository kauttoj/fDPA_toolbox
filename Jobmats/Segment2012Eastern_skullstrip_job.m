%-----------------------------------------------------------------------
% Job configuration created by cfg_util (rev $Rev: 3599 $)
%-----------------------------------------------------------------------
matlabbatch{1}.spm.spatial.preproc.data = '<UNDEFINED>';
matlabbatch{1}.spm.spatial.preproc.output.GM = [1 1 1];
matlabbatch{1}.spm.spatial.preproc.output.WM = [1 1 1];
matlabbatch{1}.spm.spatial.preproc.output.CSF = [1 1 1];
matlabbatch{1}.spm.spatial.preproc.output.biascor = 1;
matlabbatch{1}.spm.spatial.preproc.output.cleanup = 2;
matlabbatch{1}.spm.spatial.preproc.opts.tpm = '<UNDEFINED>';
matlabbatch{1}.spm.spatial.preproc.opts.ngaus = [5
                                                 5
                                                 2
                                                 6];
matlabbatch{1}.spm.spatial.preproc.opts.regtype = 'eastern';
matlabbatch{1}.spm.spatial.preproc.opts.warpreg = 1;
matlabbatch{1}.spm.spatial.preproc.opts.warpco = 100;
matlabbatch{1}.spm.spatial.preproc.opts.biasreg = 0.01;
matlabbatch{1}.spm.spatial.preproc.opts.biasfwhm = 60;
matlabbatch{1}.spm.spatial.preproc.opts.samp = 3;
matlabbatch{1}.spm.spatial.preproc.opts.msk = {''};
matlabbatch{2}.spm.util.imcalc.input(1) = cfg_dep;
matlabbatch{2}.spm.util.imcalc.input(1).tname = 'Input Images';
matlabbatch{2}.spm.util.imcalc.input(1).tgt_spec{1}(1).name = 'filter';
matlabbatch{2}.spm.util.imcalc.input(1).tgt_spec{1}(1).value = 'image';
matlabbatch{2}.spm.util.imcalc.input(1).tgt_spec{1}(2).name = 'strtype';
matlabbatch{2}.spm.util.imcalc.input(1).tgt_spec{1}(2).value = 'e';
matlabbatch{2}.spm.util.imcalc.input(1).sname = 'Segment: Bias Corr Images';
matlabbatch{2}.spm.util.imcalc.input(1).src_exbranch = substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1});
matlabbatch{2}.spm.util.imcalc.input(1).src_output = substruct('()',{1}, '.','biascorr', '()',{':'});
matlabbatch{2}.spm.util.imcalc.input(2) = cfg_dep;
matlabbatch{2}.spm.util.imcalc.input(2).tname = 'Input Images';
matlabbatch{2}.spm.util.imcalc.input(2).tgt_spec{1}(1).name = 'filter';
matlabbatch{2}.spm.util.imcalc.input(2).tgt_spec{1}(1).value = 'image';
matlabbatch{2}.spm.util.imcalc.input(2).tgt_spec{1}(2).name = 'strtype';
matlabbatch{2}.spm.util.imcalc.input(2).tgt_spec{1}(2).value = 'e';
matlabbatch{2}.spm.util.imcalc.input(2).sname = 'Segment: c1 Images';
matlabbatch{2}.spm.util.imcalc.input(2).src_exbranch = substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1});
matlabbatch{2}.spm.util.imcalc.input(2).src_output = substruct('()',{1}, '.','c1', '()',{':'});
matlabbatch{2}.spm.util.imcalc.input(3) = cfg_dep;
matlabbatch{2}.spm.util.imcalc.input(3).tname = 'Input Images';
matlabbatch{2}.spm.util.imcalc.input(3).tgt_spec{1}(1).name = 'filter';
matlabbatch{2}.spm.util.imcalc.input(3).tgt_spec{1}(1).value = 'image';
matlabbatch{2}.spm.util.imcalc.input(3).tgt_spec{1}(2).name = 'strtype';
matlabbatch{2}.spm.util.imcalc.input(3).tgt_spec{1}(2).value = 'e';
matlabbatch{2}.spm.util.imcalc.input(3).sname = 'Segment: c2 Images';
matlabbatch{2}.spm.util.imcalc.input(3).src_exbranch = substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1});
matlabbatch{2}.spm.util.imcalc.input(3).src_output = substruct('()',{1}, '.','c2', '()',{':'});
matlabbatch{2}.spm.util.imcalc.input(4) = cfg_dep;
matlabbatch{2}.spm.util.imcalc.input(4).tname = 'Input Images';
matlabbatch{2}.spm.util.imcalc.input(4).tgt_spec{1}(1).name = 'filter';
matlabbatch{2}.spm.util.imcalc.input(4).tgt_spec{1}(1).value = 'image';
matlabbatch{2}.spm.util.imcalc.input(4).tgt_spec{1}(2).name = 'strtype';
matlabbatch{2}.spm.util.imcalc.input(4).tgt_spec{1}(2).value = 'e';
matlabbatch{2}.spm.util.imcalc.input(4).sname = 'Segment: c3 Images';
matlabbatch{2}.spm.util.imcalc.input(4).src_exbranch = substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1});
matlabbatch{2}.spm.util.imcalc.input(4).src_output = substruct('()',{1}, '.','c3', '()',{':'});
matlabbatch{2}.spm.util.imcalc.output = 'skullstripped.img';
matlabbatch{2}.spm.util.imcalc.outdir = {''};
matlabbatch{2}.spm.util.imcalc.expression = 'i1.*((i2+i3 + i4)>0.5)';
matlabbatch{2}.spm.util.imcalc.options.dmtx = 0;
matlabbatch{2}.spm.util.imcalc.options.mask = 0;
matlabbatch{2}.spm.util.imcalc.options.interp = 1;
matlabbatch{2}.spm.util.imcalc.options.dtype = 4;

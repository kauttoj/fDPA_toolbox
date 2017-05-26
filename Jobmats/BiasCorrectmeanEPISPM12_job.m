%-----------------------------------------------------------------------
% Job saved on 04-Feb-2015 11:38:56 by cfg_util (rev $Rev: 6134 $)
% spm SPM - SPM12 (6225)
% cfg_basicio BasicIO - Unknown
%-----------------------------------------------------------------------
matlabbatch{1}.spm.tools.oldseg.data = {'G:\Työkansio\Nykyinen\koodit\fDPA\testdata\T1Img\S11\co20140318_104550MPRAGEsagMGHvariantSB11s005a1001.img,1'};
matlabbatch{1}.spm.tools.oldseg.output.GM = [0 0 0];
matlabbatch{1}.spm.tools.oldseg.output.WM = [0 0 0];
matlabbatch{1}.spm.tools.oldseg.output.CSF = [0 0 0];
matlabbatch{1}.spm.tools.oldseg.output.biascor = 1;
matlabbatch{1}.spm.tools.oldseg.output.cleanup = 0;
matlabbatch{1}.spm.tools.oldseg.opts.tpm = {
                                            'G:\Työkansio\Nykyinen\koodit\spm12\toolbox\OldSeg\grey.nii'
                                            'G:\Työkansio\Nykyinen\koodit\spm12\toolbox\OldSeg\white.nii'
                                            'G:\Työkansio\Nykyinen\koodit\spm12\toolbox\OldSeg\csf.nii'
                                            };
matlabbatch{1}.spm.tools.oldseg.opts.ngaus = [2
                                              2
                                              2
                                              4];
matlabbatch{1}.spm.tools.oldseg.opts.regtype = 'mni';
matlabbatch{1}.spm.tools.oldseg.opts.warpreg = 1;
matlabbatch{1}.spm.tools.oldseg.opts.warpco = 25;
matlabbatch{1}.spm.tools.oldseg.opts.biasreg = 0.001;
matlabbatch{1}.spm.tools.oldseg.opts.biasfwhm = 60;
matlabbatch{1}.spm.tools.oldseg.opts.samp = 3;
matlabbatch{1}.spm.tools.oldseg.opts.msk = {''};

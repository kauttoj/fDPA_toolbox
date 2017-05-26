%-----------------------------------------------------------------------
% Job saved on 05-Feb-2015 11:13:41 by cfg_util (rev $Rev: 6134 $)
% spm SPM - SPM12 (6225)
% cfg_basicio BasicIO - Unknown
%-----------------------------------------------------------------------
matlabbatch{1}.spm.spatial.coreg.estimate.ref = {'/scratch/braindata/kauttoj2/code/fDPA_git/testdata/expert_data/small/T1ImgSegment/S3/skullstripped.img,1'};
matlabbatch{1}.spm.spatial.coreg.estimate.source = {'/scratch/braindata/kauttoj2/code/fDPA_git/testdata/expert_data/small/RealignParameter/S3/mmeana20140213_105305EPI64SB3s004a001_04.img,1'};
matlabbatch{1}.spm.spatial.coreg.estimate.other = {'/scratch/braindata/kauttoj2/code/fDPA_git/testdata/expert_data/small/FunImg/S3/a20140213_105305EPI64SB3s004a001_04.img,1'};
matlabbatch{1}.spm.spatial.coreg.estimate.eoptions.cost_fun = 'nmi';
matlabbatch{1}.spm.spatial.coreg.estimate.eoptions.sep = [4 2];
matlabbatch{1}.spm.spatial.coreg.estimate.eoptions.tol = [0.02 0.02 0.02 0.001 0.001 0.001 0.01 0.01 0.01 0.001 0.001 0.001];
matlabbatch{1}.spm.spatial.coreg.estimate.eoptions.fwhm = [7 7];

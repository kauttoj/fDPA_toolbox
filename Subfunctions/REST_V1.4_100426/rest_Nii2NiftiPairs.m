function rest_Nii2NiftiPairs(PI,PO)
% FORMAT rest_Nii2NiftiPairs(PI,PO)
% NIfTI nii to NIfTI pairs (.hdr/.img)
%   PI - input filename: *.nii
%   PO - output filename: *.img
%___________________________________________________________________________
% Written by YAN Chao-Gan 091127. 
% State Key Laboratory of Cognitive Neuroscience and Learning, Beijing Normal University, China, 100875
% ycg.yan@gmail.com


addpath(fullfile(rest_misc('WhereIsREST'), 'rest_spm5_files'));
V = nic_spm_vol(PI);
if length(V)>1
    for i=1:length(V)
        Index=['000',num2str(i)];
        Index=Index(end-3:end);
        [Data, Head] = rest_ReadNiftiImage(PI, i);
        Head.n=[1 1];
        [Path, fileN, extn] = fileparts(PO);
        POout=[Path,filesep,fileN,'_',Index,extn];
        rest_WriteNiftiImage(Data,Head,POout);
    end
else
    [Data, Head] = rest_ReadNiftiImage(PI);
    rest_WriteNiftiImage(Data,Head,PO);
end

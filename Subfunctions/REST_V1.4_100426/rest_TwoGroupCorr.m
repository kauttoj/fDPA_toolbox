function rest_TwoGroupCorr(Group1Dir,Group2Dir,flag,outdir)
% FORMAT rest_TwoGroupCorr(Group1Dir,Group2Dir)
%   Input:
%     Group1Dir - directory of the first group
%     Group2Dir - directory of the the second group
%     flag - identify 'temporal' of 'spatial'
%     outdir - directory of output
%   Output for spatial:
%     rGroup.img - image with Pearson's Correlation Coefficient
%     pGroup.img - image with significance of Pearson's Correlation Coefficient
%   Output for temporal:
%      RandP.txt - r and p value for every point
%___________________________________________________________________________
% Written by YAN Chao-Gan 090302.
% Revised  by Dong Zhangye 091029.
% State Key Laboratory of Cognitive Neuroscience and Learning, Beijing Normal University, China, 100875
% ycg.yan@gmail.com
if strcmp(flag,'temporal')
    temcorr(Group1Dir,Group2Dir,outdir);
else
    spcorr(Group1Dir,Group2Dir,outdir);
end

function spcorr(Group1Dir,Group2Dir,outdir)
olddir=pwd;
[Group1Series, VoxelSize, ImgFileList, Header] =rest_to4d(Group1Dir);
[Group2ConSeries, VoxelSize, ImgFileList, Header] =rest_to4d(Group2Dir);

cd(olddir);
rGroup=zeros(size(Group1Series,1),size(Group1Series,2),size(Group1Series,3));
pGroup=zeros(size(Group1Series,1),size(Group1Series,2),size(Group1Series,3));
rest_waitbar;
%for i=1:size(ImgFileList,1) 
            %[r p]=corrcoef(squeeze(Group1Series(i,:,:,:)),squeeze(Group2ConSeries(i,:,:,:)));
for i=1:size(ImgFileList,1)
    rest_waitbar(i/size(Group1Series,1),'Computing','Computing','Parent');
            [r p]=corrcoef(squeeze(Group1Series(:,:,:,i)),squeeze(Group2ConSeries(:,:,:,i)));
            rGroup(i)=r(1,2);
            pGroup(i)=p(1,2);
end
rGroup(isnan(rGroup))=0;
pGroup(isnan(pGroup))=1;
fid=fopen([outdir,filesep,'R_P.txt'],'w');
if(fid>0)   
     fprintf(fid,'ID\tR\t\tP\n');
     for i=1:size(ImgFileList,1)
         fprintf(fid,'%d\t%f\t%f\n',i,rGroup(i),pGroup(i));
     end
 end





function temcorr(Group1Dir,Group2Dir,outdir)
olddir=pwd;
[Group1Series, VoxelSize, ImgFileList, Header] =rest_to4d(Group1Dir);
[Group2ConSeries, VoxelSize, ImgFileList, Header] =rest_to4d(Group2Dir);

cd(olddir);
rGroup=zeros(size(Group1Series,1),size(Group1Series,2),size(Group1Series,3));
pGroup=zeros(size(Group1Series,1),size(Group1Series,2),size(Group1Series,3));
rest_waitbar;
%for i=1:size(ImgFileList,1) 
            %[r p]=corrcoef(squeeze(Group1Series(i,:,:,:)),squeeze(Group2ConSeries(i,:,:,:)));
for i=1:size(Group1Series,1)
    rest_waitbar(i/size(Group1Series,1),'Computing','Computing','Parent');
    for j=1:size(Group1Series,2)
        for k=1:size(Group1Series,3)
            [r p]=corrcoef(squeeze(Group1Series(i,j,k,:)),squeeze(Group2ConSeries(i,j,k,:)));
            rGroup(i,j,k)=r(1,2);
            pGroup(i,j,k)=p(1,2);
        end
    end
end
rGroup(isnan(rGroup))=0;
pGroup(isnan(pGroup))=1;
rest_WriteNiftiImage(rGroup,Header,[outdir,filesep,'rGroup.img']);
rest_WriteNiftiImage(pGroup,Header,[outdir,filesep,'pGroup.img']);

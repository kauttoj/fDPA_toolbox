function [] = reho(ADataDir, NVoxel, AMaskFilename, AResultFilename)
% Calculate regional homogeneity (i.e. ReHo) from the 3D EPI images.
% FORMAT     function []   = (ADataDir, NVoxel, AMaskFilename, AResultFilename)
% Input:
% 	ADataDir			Where the 3d+time dataset stay, and there should be	3d EPI functional image files. It must not contain / or \ at the end.
%   NVoxel              The number of the voxel for a given cluster during calculating the KCC (e.g. 27, 19, or 7); Recommand: NVoxel=27;
% 	AMaskFilename		the mask file name, I only compute the point within the mask
%	AResultFilename		the output filename
% Output:
%	AResultFilename	the filename of ReHo result

% Written by Yong He, April,2004
% Medical Imaging and Computing Group (MIC), National Laboratory of Pattern Recognition (NLPR),
% Chinese Academy of Sciences (CAS), China.
% E-mail: yhe@nlpr.ia.ac.cn
% Copywrite (c) 2004, 

% Info on the approach based on the reho: 
% Zang YF, Jiang TZ, Lu YL, He Y and Tian LX, Regional Homogeneity Approach
% to fMRI Data Analysis. NeuroImage, Vol.22, No.1, 2004, 394-400.

% Info on the interesting and potential applications about the reho:
% He Y, Zang YF, Jiang TZ, Lu YL and Weng XC, Detection of Functional Networks
% in the Resting Brain. 2nd IEEE International Symposium on Biomedical Imaging:
% From Nano to Macro (ISBI'04), April 15-18, 2004, Arlington, USA. 

% Info on the above can be found in:
% http://www.nlpr.ia.ac.cn/english/mic/YongHe
% ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
%Revised by Xiaowei Song, 20070421
%1.Add another parameter to allow user defined mask, so change some in code of selecting mask
%  user defined mask has priority 
% And delete the old parameter 'bMask', if the AMaskFilename is null(bMask=0) or 'Default'(bMask=1), then I would use 'ones mask' or 'default mask'
%2.Add waitbar for gui waiting and progress showing
%Revised by Xiaowei Song 20070903
% ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
%   Revised by YAN Chao-Gan 080610: NIFTI compatible
%   Revised by YAN Chao-Gan 080808: also support NIFTI images.
%   Revised by YAN Chao-Gan, 090321. Result data will be saved in the format 'single'.
%   Revised by YAN Chao-Gan, 090419. 1. Add Parameters: ADataDir and AResultFilename; Remove the old parameter 'NVolume'. 2. Fixed the bug of computing ReHo with 7 voxels or 19 voxels in a cluster. 
%   Algorithm re-written by YAN Chao-Gan, 090422. The algorithm has been re-written to speed up the calculation of ReHo.
%   Revised by YAN Chao-Gan, 090717: Also calculate the ReHo value of the voxels near the border of the brain mask, users should be cautious when discussing the results near the border.


if nargin~=4
    error(' Error using ==> reho. 4 arguments wanted.');
end
theElapsedTime =cputime;

% Examine the Nvoxel
% --------------------------------------------------------------------------
if NVoxel ~= 27 & NVoxel ~= 19 & NVoxel ~= 7 
    error('The second parameter should be 7, 19 or 27. Please re-exmamin it.');
end

%read the normalized functional images 
% -------------------------------------------------------------------------
fprintf('\n\t Read these 3D EPI functional images.\twait...');
[AllVolume,vsize,theImgFileList, Header] =rest_to4d(ADataDir);
[nDim1 nDim2 nDim3 nDim4]=size(AllVolume);
isize = [nDim1 nDim2 nDim3]; 
mask=rest_loadmask(nDim1, nDim2, nDim3, AMaskFilename);

%Algorithm re-written by YAN Chao-Gan, 090422. Speed up the calculation of ReHo.
%Saving a big 3D+time Dataset to small pieces by its first dimension to make this process run at least
% put pieces of 4D dataset to the temp dir determined by the current time
theTempDatasetDirName =sprintf('ReHo_%d_%s', fix((1e4) *rem(now, 1) ),rest_misc('GetCurrentUser'));
theTempDatasetDir =[tempdir theTempDatasetDirName] ;
ans=rmdir(theTempDatasetDir, 's');%suppress the error msg
mkdir(tempdir, theTempDatasetDirName);	%Matlab 6.5 compatible

Save1stDimPieces(theTempDatasetDir, AllVolume, 'dim1_');
clear AllVolume;%Free large memory

%rank the 3d+time functional images voxel by voxel
% -------------------------------------------------------------------------
fprintf('\n\t Calculate the rank of time series on voxel by voxel');

NumPieces_Dim1=10;	%Constant number to divide the first dimension to "NumPieces_Dim1" pieces
NumComputingCount =ceil(nDim1/NumPieces_Dim1);
for x=1:(NumComputingCount),
    rest_waitbar(x/NumComputingCount, ...
        'Calculate the rank of time series on voxel by voxel. Please wait...', ...
        'REST working','Child','NeedCancelBtn');

    theFilename =fullfile(theTempDatasetDir, sprintf('dim1_%.8d', x));
    theDim1Volume4D =Load1stDimVolume(theFilename);
    theDim1Volume4D =double(theDim1Volume4D);

    % Algorithm re-written by YAN Chao-Gan, 090422. Speed up the calculation of ReHo.
    theDim1Volume4D=permute(theDim1Volume4D,[4,1,2,3]); % Change the Time Course to the first dimention
    [TimePoints,M,N,O]=size(theDim1Volume4D);
    [theDim1Volume4D,SortIndex] = sort(theDim1Volume4D,1);
    db=diff(theDim1Volume4D,1,1);
    clear theDim1Volume4D;
    db = db == 0;
    if x~=NumComputingCount
        mask_x = mask(((x-1)*NumPieces_Dim1+1):(x*NumPieces_Dim1), :,:);
        sumdb=squeeze(sum(db,1)).*mask_x;
    else
        mask_x = mask(((x-1)*NumPieces_Dim1+1):end, :,:);
        sumdb=sum(db,1);
        sumdb=reshape(sumdb,size(mask_x)).*mask_x;
    end
    SortedRanks=reshape(repmat([1:TimePoints]',M*N*O,1),[TimePoints,M,N,O]);
    if any(sumdb(:))
        TieAdjustIndex=find(sumdb);
        for i=1:length(TieAdjustIndex)
            [iM iN iO]=ind2sub([M N O],TieAdjustIndex(i));
            ranks=SortedRanks(:,iM,iN,iO);
            ties=db(:,iM,iN,iO);
            tieloc = [find(ties); TimePoints+2];
            maxTies = numel(tieloc);
            tiecount = 1;
            while (tiecount < maxTies)
                tiestart = tieloc(tiecount);
                ntied = 2;
                while(tieloc(tiecount+1) == tieloc(tiecount)+1)
                    tiecount = tiecount+1;
                    ntied = ntied+1;
                end
                % Compute mean of tied ranks
                ranks(tiestart:tiestart+ntied-1) = ...
                    sum(ranks(tiestart:tiestart+ntied-1)) / ntied;
                tiecount = tiecount + 1;
            end
            SortedRanks(:,iM,iN,iO)=ranks;
        end
    end
    clear db sumdb;
    SortIndexBase=reshape(([1:M*N*O]'-1).*TimePoints,[M,N,O]);
    SortIndexBase=repmat(SortIndexBase,[1,1,1,TimePoints]);
    SortIndexBase=permute(SortIndexBase,[4,1,2,3]);
    SortIndex=SortIndex+SortIndexBase;
    clear SortIndexBase;
    theDim1Volume4D(SortIndex)=SortedRanks;
    theDim1Volume4D=reshape(theDim1Volume4D,size(SortedRanks));
    clear SortIndex SortedRanks;
    theDim1Volume4D=uint16(theDim1Volume4D); % Change to uint16 to get the same results of previous version.
    %Save to file
    theFilename =fullfile(theTempDatasetDir, sprintf('result_%.8d', x));
    save(theFilename, 'theDim1Volume4D');
    fprintf('.');

end

for x=1:(NumComputingCount)
    rest_waitbar(x/(floor(nDim1/NumPieces_Dim1)+1), ...
        'Rank 3D Brain reconstructing. Please wait...', ...
        'REST working','Child','NeedCancelBtn');
    theFilename =fullfile(theTempDatasetDir, sprintf('result_%.8d', x));
    if x==1
        I=Load1stDimVolume(theFilename);
    else
        I=cat(2,I,Load1stDimVolume(theFilename));
    end
    fprintf('.');
end
fprintf('\n');
[TimePoints,M,N,O]=size(I);

ans=rmdir(theTempDatasetDir, 's');%suppress the error msg

% calulate the kcc for the data set
% ------------------------------------------------------------------------
fprintf('\t Calculate the kcc on voxel by voxel for the data set.\n');
K = zeros(M,N,O); 
switch NVoxel
    case 27  
        for i = 2:M-1
            for j = 2:N-1
                for k = 2:O-1                            
                    block = I(:,i-1:i+1,j-1:j+1,k-1:k+1);
                    mask_block = mask(i-1:i+1,j-1:j+1,k-1:k+1);
                    if mask_block(2,2,2)~=0
                        %YAN Chao-Gan 090717, We also calculate the ReHo value of the voxels near the border of the brain mask, users should be cautious when dicussing the results near the border. %if all(mask_block(:))
                        R_block=reshape(block,[],27); %Revised by YAN Chao-Gan, 090420. Speed up the calculation.
                        mask_R_block = R_block(:,reshape(mask_block,1,27) > 0);
                        K(i,j,k) = f_kendall(mask_R_block);  
                    end %end if	
                end%end k 
            end% end j			
			rest_waitbar(i/M, ...
					sprintf('Calculate the kcc\nwait...'), ...
					'ReHo Computing','Child','NeedCancelBtn');
        end%end i
        fprintf('\t The reho of the data set was finished.\n');
        rest_writefile(single(K),AResultFilename,isize,vsize,Header, 'single'); %Revised by YAN Chao-Gan, 090321. Result data will be stored in 'single' format. %'double');
    case 19  
        mask_cluster_19=ones(3,3,3);
        mask_cluster_19(1,1,1) = 0;    mask_cluster_19(1,3,1) = 0;    mask_cluster_19(3,1,1) = 0;    mask_cluster_19(3,3,1) = 0;
        mask_cluster_19(1,1,3) = 0;    mask_cluster_19(1,3,3) = 0;    mask_cluster_19(3,1,3) = 0;    mask_cluster_19(3,3,3) = 0;
        %Revised by YAN Chao-Gan, 090420. The element in the mask could be 1 other than 127. Fixed the bug of computing ReHo with 7 voxels or 19 voxels.
        for i = 2:M-1
            for j = 2:N-1
                for k = 2:O-1                            
                    block = I(:,i-1:i+1,j-1:j+1,k-1:k+1);
                    mask_block = mask(i-1:i+1,j-1:j+1,k-1:k+1);
                    if mask_block(2,2,2)~=0
                        %YAN Chao-Gan 090717, We also calculate the ReHo value of the voxels near the border of the brain mask, users should be cautious when dicussing the results near the border. %if all(mask_block(:))
                        mask_block=mask_block.*mask_cluster_19;
                        %Revised by YAN Chao-Gan, 090419. The element in the mask could be 1 other than 127. Fixed the bug of computing ReHo with 7 voxels or 19 voxels.
                        R_block=reshape(block,[],27);  %Revised by YAN Chao-Gan, 090420. Speed up the calculation.
                        mask_R_block = R_block(:,reshape(mask_block,1,27) > 0); %Revised by YAN Chao-Gan, 090419. The element in the mask could be 1 other than 127. Fixed the bug of computing ReHo with 7 voxels or 19 voxels. %> 2);
                        K(i,j,k) = f_kendall(mask_R_block);  
                    end%end if
                end%end k
            end%end j	
			rest_waitbar(i/M, ...
					sprintf('Calculate the kcc\nwait...'), ...
					'ReHo Computing','Child','NeedCancelBtn');
        end%end i
        fprintf('\t The reho of the data set was finished.\n');
        rest_writefile(single(K),AResultFilename,isize,vsize,Header, 'single'); %Revised by YAN Chao-Gan, 090321. Result data will be stored in 'single' format. %'double');
    case 7   
        mask_cluster_7=ones(3,3,3);
        mask_cluster_7(1,1,1) = 0;    mask_cluster_7(1,2,1) = 0;     mask_cluster_7(1,3,1) = 0;      mask_cluster_7(1,1,2) = 0;
        mask_cluster_7(1,3,2) = 0;    mask_cluster_7(1,1,3) = 0;     mask_cluster_7(1,2,3) = 0;      mask_cluster_7(1,3,3) = 0;
        mask_cluster_7(2,1,1) = 0;    mask_cluster_7(2,3,1) = 0;     mask_cluster_7(2,1,3) = 0;      mask_cluster_7(2,3,3) = 0;
        mask_cluster_7(3,1,1) = 0;    mask_cluster_7(3,2,1) = 0;     mask_cluster_7(3,3,1) = 0;      mask_cluster_7(3,1,2) = 0;
        mask_cluster_7(3,3,2) = 0;    mask_cluster_7(3,1,3) = 0;     mask_cluster_7(3,2,3) = 0;      mask_cluster_7(3,3,3) = 0;
        %Revised by YAN Chao-Gan, 090420. The element in the mask could be 1 other than 127. Fixed the bug of computing ReHo with 7 voxels or 19 voxels.
        for i = 2:M-1
            for j = 2:N-1
                for k = 2:O-1
                    block = I(:,i-1:i+1,j-1:j+1,k-1:k+1);
                    mask_block = mask(i-1:i+1,j-1:j+1,k-1:k+1);
                    if mask_block(2,2,2)~=0
                        %YAN Chao-Gan 090717, We also calculate the ReHo value of the voxels near the border of the brain mask, users should be cautious when dicussing the results near the border. %if all(mask_block(:))
                        mask_block=mask_block.*mask_cluster_7;
                        %Revised by YAN Chao-Gan, 090419. The element in the mask could be 1 other than 127. Fixed the bug of computing ReHo with 7 voxels or 19 voxels.
                        R_block=reshape(block,[],27); %Revised by YAN Chao-Gan, 090420. Speed up the calculation.
                        mask_R_block = R_block(:,reshape(mask_block,1,27) > 0); %Revised by YAN Chao-Gan, 090419. The element in the mask could be 1 other than 127. Fixed the bug of computing ReHo with 7 voxels or 19 voxels. %> 2);
                        K(i,j,k) = f_kendall(mask_R_block);  
                    end%end if
                end%end k
            end%end j		
			rest_waitbar(i/M, ...
					sprintf('Calculate the kcc\nwait...'), ...
					'ReHo Computing','Child','NeedCancelBtn');
        end%end i
        fprintf('\t The reho of the data set was finished.\n');
        rest_writefile(single(K),AResultFilename,isize,vsize,Header,'single'); %Revised by YAN Chao-Gan, 090321. Result data will be stored in 'single' format. %'double');
    otherwise
        error('The second parameter should be 7, 19 or 27. Please re-exmamin it.');
end %end switch
Ken = K;
theElapsedTime =cputime - theElapsedTime;
fprintf('\n\tRegional Homogeneity computation over, elapsed time: %g seconds\n', theElapsedTime);

% calculate kcc for a time series
%---------------------------------------------------------------------------
function B = f_kendall(A)
nk = size(A); n = nk(1); k = nk(2);
SR = sum(A,2); SRBAR = mean(SR);
S = sum(SR.^2) - n*SRBAR^2;
B = 12*S/k^2/(n^3-n);
    
    
function Save1stDimPieces(ATempDir, A4DVolume, AFilenamePrefix)
%Save the 1st dimension of the 4D dataset to files
NumPieces_Dim1=10;	%Constant number to divide the first dimension to "NumPieces_Dim1" pieces 
NumComputingCount =ceil(size(A4DVolume,1)/NumPieces_Dim1);
for x = 1:(NumComputingCount),
    %for x = 1:(floor(size(A4DVolume,1)/NumPieces_Dim1)+1)
    rest_waitbar((x/NumComputingCount), ...
        'Cut one Big 3D+time Dataset into pieces of 3D+time Dataset Before ReHo. Please wait...', ...
        'REST working','Child','NeedCancelBtn');

    theFilename =fullfile(ATempDir, sprintf('%s%.8d',AFilenamePrefix, x));
    if x~=NumComputingCount
        the1stDim = A4DVolume(((x-1)*NumPieces_Dim1+1):(x*NumPieces_Dim1), :,:,:);
    else
        the1stDim = A4DVolume(((x-1)*NumPieces_Dim1+1):end, :,:,:);
    end
    save(theFilename, 'the1stDim');
end

function Result=Load1stDimVolume(AFilename)
%Load the 1st dimension of the 4D dataset from files, return a Matrix not a struct
Result =load(AFilename);
theFieldnames=fieldnames(Result);
% Result =eval(sprintf('Result.%s',the1stField));%remove the struct variable to any named variable with a matrix
Result = Result.(theFieldnames{1});

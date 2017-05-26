function [ResultMaps] = rest_Y_fc(ADataDir,AMaskFilename, AROIDef,AResultFilename)
% Functional connectivity
%AROIList would be treated as a mask in which time courses would be averaged to produce a new time course representing the ROI area
% Input:
% 	ADataDir			where the 3d+time dataset stay, and there should be 3d EPI functional image files. It must not contain / or \ at the end.
% 	AMaskFilename		the mask file name, I only compute the point within the mask
% 	AROIList		the mask list , ROI list definition
%	AResultFilename		the output filename
% Output:
%	AResultFilename	the filename of funtional connectivity result
%-----------------------------------------------------------
%	Copyright(c) 2007~2010
%	State Key Laboratory of Cognitive Neuroscience and Learning in Beijing Normal University
%	Written by Xiao-Wei Song 
%	http://resting-fmri.sourceforge.net
%-----------------------------------------------------------
% 	Mail to Authors:  <a href="Dawnwei.Song@gmail.com">Xiaowei Song</a>; <a href="ycg.yan@gmail.com">Chaogan Yan</a> 
%	Version=1.3;
%	Release=20090321;
%   Revised by YAN Chao-Gan, 080610. NIFTI compatible
%   Last Revised by YAN Chao-Gan, 090321. Result data will be saved in the format 'single'.
%   Revised by YAN Chao-Gan, 101010 for DPARSF's fast FC calculation.

if nargin~=4,
    error(' Error using ==> fc. 4 arguments wanted.');
end

theElapsedTime =cputime;
fprintf('\nComputing functional connectivity with:\t"%s"', ADataDir);
[AllVolume,VoxelSize,theImgFileList, Header] =rest_to4d(ADataDir);
rest_waitbar;
% examin the dimensions of the functional images and set mask
[nDim1, nDim2, nDim3, nDim4]=size(AllVolume);
BrainSize = [nDim1 nDim2 nDim3];
sampleLength = size(theImgFileList,1);

theROITimeCourses =zeros(sampleLength, length(AROIDef));
for x=1:length(AROIDef)
    fprintf('\n\t ROI time courses retrieving through "%s".', AROIDef{x});
    IsDefinedROITimeCourse =0;
    if rest_SphereROI( 'IsBallDefinition', AROIDef{x})
        %The ROI definition is a Ball definition
        maskROI =rest_SphereROI( 'BallDefinition2Mask' , AROIDef{x}, BrainSize, VoxelSize, Header);
    elseif exist(AROIDef{x},'file')==2	% Make sure the Definition file exist
        [pathstr, name, ext] = fileparts(AROIDef{x});
        if strcmpi(ext, '.txt'),
            tmpX=load(AROIDef{x});
            if size(tmpX,2)>1,
                %Average all columns to make sure tmpX only contain one column
                tmpX = mean(tmpX')';
            end
            theROITimeCourses(:, x) =tmpX;
            IsDefinedROITimeCourse =1;
        elseif strcmpi(ext, '.img')
            %The ROI definition is a mask file
            maskROI =rest_loadmask(nDim1, nDim2, nDim3, AROIDef{x});
        else
            error(sprintf('REST doesn''t support the selected ROI definition now, Please check: \n%s', AROIDef{x}));
        end
    else
        error(sprintf('Wrong ROI definition, Please check: \n%s', AROIDef{x}));
    end

    if ~IsDefinedROITimeCourse,% I need retrieving the ROI averaged time course manualy
        % Speed up! YAN Chao-Gan 101010.
        maskROI =find(maskROI);
        AllVolume=reshape(AllVolume,[],nDim4);
        theROITimeCourses(:, x)=mean(AllVolume(maskROI,:),1)';
        AllVolume=reshape(AllVolume,nDim1,nDim2,nDim3,nDim4);
    end%if ~IsDefinedROITimeCourse
end%for

%Save the ROI averaged time course to disk for further study
[pathstr, name, ext] = fileparts(AResultFilename);
theROITimeCourseLogfile =[fullfile(pathstr,['ROI_', name]), '.txt'];
save(theROITimeCourseLogfile, 'theROITimeCourses', '-ASCII', '-DOUBLE','-TABS')

%Apply Mask
fprintf('\n\t Load mask "%s".', AMaskFilename);
mask=rest_loadmask(nDim1, nDim2, nDim3, AMaskFilename);
mask =logical(mask);%Revise the mask to ensure that it contain only 0 and 1
mask =	repmat(mask, [1, 1, 1, sampleLength]);
AllVolume(~mask)=0;
clear mask

%Remove the mean
AllVolume = AllVolume - repmat(mean(AllVolume,4),[1, 1, 1, nDim4]);
theROITimeCourses =theROITimeCourses -repmat(mean(theROITimeCourses,1), size(theROITimeCourses,1), 1);

% For denominator
% ABrainSTDRaw= squeeze(std(AllVolume, 0, 4));
%Divide to pieces to calculate the std for the memory limit
ABrainSTDRaw=zeros(nDim1, nDim2, nDim3);
NumPieces_Dim1 =10;
NumComputingCount =ceil(nDim1/NumPieces_Dim1);
for iPiece=1:(NumComputingCount)
    if iPiece<NumComputingCount
        PieceVolume=AllVolume((iPiece-1)*NumPieces_Dim1+1:iPiece*NumPieces_Dim1,:,:,:);
        ABrainSTDRaw((iPiece-1)*NumPieces_Dim1+1:iPiece*NumPieces_Dim1,:,:)= squeeze(std(PieceVolume, 0, 4));
    else
        PieceVolume=AllVolume((iPiece-1)*NumPieces_Dim1+1:nDim1,:,:,:);
        ABrainSTDRaw((iPiece-1)*NumPieces_Dim1+1:nDim1,:,:)= squeeze(std(PieceVolume, 0, 4));
    end
end
clear PieceVolume


% (1*sampleLength) A matrix * B matrix (sampleLength * VoxelCount)
AllVolume =reshape(AllVolume, nDim1*nDim2*nDim3, nDim4)';

for iROI=1:size(theROITimeCourses, 2)
    AROITimeCourse=theROITimeCourses(:,iROI);
    
    AROITimeCourse =reshape(AROITimeCourse, 1, nDim4);
    CorrBrain = AROITimeCourse * AllVolume /(nDim4 -1);
    CorrBrain =squeeze(reshape(CorrBrain', nDim1, nDim2, nDim3, 1));
    ABrainSTD=ABrainSTDRaw * std(AROITimeCourse);
    ABrainSTD(find(ABrainSTD==0))=inf;%Suppress NaN to zero when denominator is zero
    CorrBrain =CorrBrain ./ABrainSTD;

    if size(theROITimeCourses, 2)>1
        %Save every maps from result maps
        [pathstr, name, ext] = fileparts(AResultFilename);
        theCurrentROIResultFilename =[fullfile(pathstr,['ROI',num2str(iROI),name])];
        fprintf('\n\t Saving Functional Connectivity maps: %s\tWait...', theCurrentROIResultFilename);
        rest_writefile(single(CorrBrain), ...
            theCurrentROIResultFilename, ...
            BrainSize,VoxelSize,Header, 'single'); %Revised by YAN Chao-Gan, 090321. Result data will be stored in 'single' format. %'double');
    elseif size(theROITimeCourses, 2)==1,
        %There will be no y loop, just one saving
        %Save Functional Connectivity image to disk
        fprintf('\n\t Saving Functional Connectivity map.\tWait...');
        rest_writefile(single(CorrBrain), ...
            AResultFilename, ...
            BrainSize,VoxelSize,Header, 'single'); %Revised by YAN Chao-Gan, 090321. Result data will be stored in 'single' format. %'double');
    end%end if
end


theElapsedTime =cputime - theElapsedTime;
fprintf('\n\t Functional Connectivity compution over, elapsed time: %g seconds.\n', theElapsedTime);

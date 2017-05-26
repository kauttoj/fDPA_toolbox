function [theROITimeCourses] = rest_Y_ExtractROITC(ADataDir, AROIDef,OutDir)
% FORMAT [] = rest_Y_ExtractROITC(ADataDir, AROIDef,OutDir)
% Input:
%   ADataDir - where the 3d+time dataset stay, and there should be 3d EPI functional image files. It must not contain / or \ at the end.
%   AROIDef - A cell of the mask list , ROI list definition. AROIDef would be	treated as a mask in which time courses would be averaged to produce a new time course representing the ROI area
%             e.g. {'ROI Center(mm)=(0, 0, 0); Radius=6.00 mm.';'ROI Center(mm)=(5, 9, 20); Radius=6.00 mm.';'D:\Data\ROI.img'}
% Output:
%   *.mat - The extracted time courses and Pierson's correlations would be saved as .mat files in the current directory of MATLAB.
%__________________________________________________________________________
% Written by YAN Chao-Gan 081212 for DPARSF, based on fc.m.
% State Key Laboratory of Cognitive Neuroscience and Learning, Beijing Normal University, China, 100875
% ycg.yan@gmail.com
%__________________________________________________________________________
% Modified by YAN Chao-Gan 091212. Can process text files and add output dir.
% Last Modified by YAN Chao-Gan, 100420. Also transform r to Fisher's z.


theElapsedTime =cputime;
fprintf('\nExtracting ROI time courses:\t"%s"', ADataDir);
[Path, SubID, extn] = fileparts(ADataDir);
[AllVolume,VoxelSize,theImgFileList, Header] =rest_to4d(ADataDir);
% examin the dimensions of the functional images and set mask
nDim1 = size(AllVolume,1); nDim2 = size(AllVolume,2); nDim3 = size(AllVolume,3);
BrainSize = [nDim1 nDim2 nDim3];
sampleLength = size(theImgFileList,1);

AROIList =AROIDef;
if iscell(AROIDef),	%ROI wise, compute corelations between regions
    %ROI time course retrieving, 20070903
    theROITimeCourses =zeros(sampleLength, size(AROIDef,1));
    AdditionalTimeCourse=[];
    for x=1:size(AROIDef,1),
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
                    AdditionalTimeCourse=[AdditionalTimeCourse,tmpX(:,2:end)];
                end
                theROITimeCourses(:, x) =tmpX(:,1);
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
            maskROI =find(maskROI);
            % [rangeX, rangeY, rangeZ] = ind2sub(size(maskROI), find(maskROI));
            % theTimeCourses =zeros(length(unique(rangeX)), length(unique(rangeY)), length(unique(rangeZ)));
            for t=1:sampleLength,
                theTimePoint = squeeze(AllVolume(:,:,:, t));
                theTimePoint = theTimePoint(maskROI);
                if ~isempty(theTimePoint),
                    theROITimeCourses(t, x) =mean(theTimePoint);
                end
            end	%The Averaged Time Course within the ROI now comes out! 20070903
        end%if ~IsDefinedROITimeCourse
    end%for
    
    if ~isempty(AdditionalTimeCourse)
        theROITimeCourses=[theROITimeCourses,AdditionalTimeCourse];
    end
    
    %Save the ROI averaged time course to disk for further study
    save([OutDir,filesep,SubID,'_ROITimeCourses.mat'],'theROITimeCourses');
    save([OutDir,filesep,SubID,'_ROITimeCourses.txt'],'theROITimeCourses', '-ASCII', '-DOUBLE','-TABS');

    ResultCorr =corrcoef(theROITimeCourses);
    save([OutDir,filesep,SubID,'_ResultCorr.mat'],'ResultCorr');
    save([OutDir,filesep,SubID,'_ResultCorr.txt'],'ResultCorr', '-ASCII', '-DOUBLE','-TABS');
    
    ResultCorr_FisherZ = 0.5 * log((1 +ResultCorr)./(1- ResultCorr));   %Added by YAN Chao-Gan, 100420. Also transform r to Fisher's z.
    save([OutDir,filesep,SubID,'_ResultCorr_FisherZ.mat'],'ResultCorr_FisherZ');
    save([OutDir,filesep,SubID,'_ResultCorr_FisherZ.txt'],'ResultCorr_FisherZ', '-ASCII', '-DOUBLE','-TABS');
end%ROI wise


theElapsedTime =cputime - theElapsedTime;
fprintf('\n\t Extracting ROI time courses over, elapsed time: %g seconds.\n', theElapsedTime);
function [ResultMaps] = fc(ADataDir,AMaskFilename, AROIDef,AResultFilename, ACovariablesDef)
% Functional connectivity
%AROIList would be treated as a mask in which time courses would be averaged to produce a new time course representing the ROI area
% Input:
% 	ADataDir			where the 3d+time dataset stay, and there should be 3d EPI functional image files. It must not contain / or \ at the end.
% 	AMaskFilename		the mask file name, I only compute the point within the mask
% 	AROIList		the mask list , ROI list definition
%	AResultFilename		the output filename
%	ACovariablesDef
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

	if nargin~=5,
        error(' Error using ==> fc. 4 arguments wanted.'); 
    end
		
	theElapsedTime =cputime;
	fprintf('\nComputing functional connectivity with:\t"%s"', ADataDir);
	[AllVolume,VoxelSize,theImgFileList, Header] =rest_to4d(ADataDir);
	% examin the dimensions of the functional images and set mask 
	nDim1 = size(AllVolume,1); nDim2 = size(AllVolume,2); nDim3 = size(AllVolume,3);
	BrainSize = [nDim1 nDim2 nDim3]; 
	sampleLength = size(theImgFileList,1);
	
	%20070512	Saving a big 3D+time Dataset to small pieces by its first dimension to make this process run at least
	% put pieces of 4D dataset to the temp dir determined by the current time
	theTempDatasetDirName =sprintf('fc_%d_%s', fix((1e4) *rem(now, 1) ),rest_misc('GetCurrentUser'));	
	theTempDatasetDir =[tempdir theTempDatasetDirName] ;
	ans=rmdir(theTempDatasetDir, 's');%suppress the error msg
	mkdir(tempdir, theTempDatasetDirName);	%Matlab 6.5 compatible
	
	AROIList =AROIDef;	
	if iscell(AROIDef),	%ROI wise, compute corelations between regions	
		%ROI time course retrieving, 20070903	
		theROITimeCourses =zeros(sampleLength, size(AROIDef,1));
		for x=1:size(AROIDef,1),
			fprintf('\n\t ROI time courses retrieving through "%s".', AROIDef{x});				
			IsDefinedROITimeCourse =0;
			if rest_SphereROI( 'IsBallDefinition', AROIDef{x})
				%The ROI definition is a Ball definition
				maskROI =rest_SphereROI( 'BallDefinition2Mask' , AROIDef{x}, BrainSize, VoxelSize, Header);
			elseif exist(AROIDef{x},'file')==2	% Make sure the Definition file exist
				[pathstr, name, ext, versn] = fileparts(AROIDef{x});
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
		%Save the ROI averaged time course to disk for further study
		[pathstr, name, ext, versn] = fileparts(AResultFilename);
		theROITimeCourseLogfile =[fullfile(pathstr,['ROI_', name]), '.txt'];
		save(theROITimeCourseLogfile, 'theROITimeCourses', '-ASCII', '-DOUBLE','-TABS')
		
		%If there are covariables
		theCovariables =[];
		if exist(ACovariablesDef.ort_file, 'file')==2,
			theCovariables =load(ACovariablesDef.ort_file);
			%Add polynomial in the baseline model according to 3dfim+.pdf
			thePolOrt=[];
			if ACovariablesDef.polort>=0,
				thePolOrt =(1:sampleLength)';
				thePolOrt =repmat(thePolOrt, [1, (1+ACovariablesDef.polort)]);
				for x=1:(ACovariablesDef.polort+1),
					thePolOrt(:, x) =thePolOrt(:, x).^(x-1) ;
				end
			end
			
			%Regress out the covariables
			theCovariables =[thePolOrt, theCovariables];
			theROITimeCourses =Brain1D_RegressOutCovariables(theROITimeCourses, theCovariables);
			
		elseif ~isempty(ACovariablesDef.ort_file) && ~all(isspace(ACovariablesDef.ort_file)),
			warning(sprintf('\n\nCovariables definition text file "%s" doesn''t exist, please check! I won''t regress out the covariables this time.', ACovariablesDef.ort_file));
		end
		
		
		%Calcute the corelation matrix and save to a text file
		ResultMaps =corrcoef(theROITimeCourses);
		save([AResultFilename, '.txt'], 'ResultMaps', '-ASCII', '-DOUBLE','-TABS')
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%	 
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%	 
	else		%Voxel wise, compute corelations between one ROI time course and the whole brain
		%ROI time course retrieving, 20070903	
		fprintf('\n\t ROI time course retrieving through "%s".', AROIDef);		
		AROITimeCourse = zeros(sampleLength, 1);
		IsDefinedROITimeCourse =0;
		if rest_SphereROI( 'IsBallDefinition', AROIDef)
			%The ROI definition is a Ball definition
			maskROI =rest_SphereROI( 'BallDefinition2Mask' , AROIDef, BrainSize, VoxelSize, Header);
		elseif exist(AROIDef,'file')==2	% Make sure the Definition file exist
			[pathstr, name, ext, versn] = fileparts(AROIDef);
			if strcmpi(ext, '.txt'),
				tmpX=load(AROIDef);
				if size(tmpX,2)>1,
					%Average all columns to make sure tmpX only contain one column
					tmpX = mean(tmpX')';
				end
				AROITimeCourse =tmpX;
				IsDefinedROITimeCourse =1;
			elseif strcmpi(ext, '.img')
				%The ROI definition is a mask file
				maskROI =rest_loadmask(nDim1, nDim2, nDim3, AROIDef);		
			else
				error(sprintf('REST doesn''t support the selected ROI definition now, Please check: \n%s', AROIDef));
			end
		else
			error(sprintf('Wrong ROI definition, Please check: \n%s', AROIDef));
		end
		if ~IsDefinedROITimeCourse,% I need retrieving the ROI averaged time course manualy
			maskROI =find(maskROI);
			% [rangeX, rangeY, rangeZ] = ind2sub(size(maskROI), find(maskROI));
			% theTimeCourses =zeros(length(unique(rangeX)), length(unique(rangeY)), length(unique(rangeZ)));	
			for t=1:sampleLength,
				theTimePoint = squeeze(AllVolume(:,:,:, t));
				theTimePoint = theTimePoint(maskROI);
				AROITimeCourse(t) =mean(theTimePoint);
			end	%The Averaged Time Course within the ROI now comes out! 20070903
			%Make sure the ROI averaged time course is an col vector
			AROITimeCourse =reshape(AROITimeCourse, sampleLength,1);
		end
		%Save the ROI averaged time course to disk for further study
		[pathstr, name, ext, versn] = fileparts(AResultFilename);
		theROITimeCourseLogfile =[fullfile(pathstr,['ROI_', name]), '.txt'];
		save(theROITimeCourseLogfile, 'AROITimeCourse', '-ASCII', '-DOUBLE','-TABS')
		
		%Save 3D+time Dataset's pieces to disk after ROI time course retrieved
		Save1stDimPieces(theTempDatasetDir, AllVolume, 'dim1_');
		clear AllVolume;%Free large memory
		
		%mask selection, added by Xiaowei Song, 20070421
		fprintf('\n\t Load mask "%s".', AMaskFilename);	
		mask=rest_loadmask(nDim1, nDim2, nDim3, AMaskFilename);
		
		fprintf('\n\t Build functional connectivity mask.\tWait...');
		mask =logical(mask);%Revise the mask to ensure that it contain only 0 and 1	
		mask =	repmat(mask, [1, 1, 1, sampleLength]);	
		%Save mask pieces to disk to make this program at least run
		Save1stDimPieces(theTempDatasetDir, mask, 'mask_');	
		
		fprintf('\n\t Build Covariables time course.\tWait...');
		%If there are covariables, 20071002
		theCovariables =[];
		if exist(ACovariablesDef.ort_file, 'file')==2,
			theCovariables =load(ACovariablesDef.ort_file);
			%Add polynomial in the baseline model according to 3dfim+.pdf
			thePolOrt=[];
			if ACovariablesDef.polort>=0,
				thePolOrt =(1:sampleLength)';
				thePolOrt =repmat(thePolOrt, [1, (1+ACovariablesDef.polort)]);
				for x=1:(ACovariablesDef.polort+1),
					thePolOrt(:, x) =thePolOrt(:, x).^(x-1) ;
				end
			end
			% switch ACovariablesDef.polort,
			% case 0,
				% thePolOrt =ones(sampleLength, 1);
			% case 1,
				% thePolOrt =[ones(sampleLength, 1), (1:sampleLength)'];
			% case 2,
				% thePolOrt =[ones(sampleLength, 1), (1:sampleLength)', (1:sampleLength)'.^2];
			% otherwise
			% end
			%Regress out the covariables
			theCovariables =[thePolOrt, theCovariables];		
			
		elseif ~isempty(ACovariablesDef.ort_file) && ~all(isspace(ACovariablesDef.ort_file)),
			warning(sprintf('\n\nCovariables definition text file "%s" doesn''t exist, please check! I won''t regress out the covariables this time.', ACovariablesDef.ort_file));
		end
			
		fprintf('\n\t Functional connectivity is computing.\tWait...');		
	    NumPieces_Dim1 =4;	%Constant number to divide the first dimension to "NumPieces_Dim1" pieces
		NumComputingCount =floor(nDim1/NumPieces_Dim1);
		if NumComputingCount< (nDim1/NumPieces_Dim1),
			NumComputingCount =NumComputingCount +1;
		else
		end
		for x=1:(NumComputingCount),	%20071129
		%for x=1:(floor(nDim1/NumPieces_Dim1) +1)
			rest_waitbar(x/(floor(nDim1/NumPieces_Dim1) +1), ...
						'Computing Functional connectivity. Please wait...', ...
						'REST working','Child','NeedCancelBtn');
						
			%Load cached pieces of Datasets
			theFilename =fullfile(theTempDatasetDir, sprintf('dim1_%.8d', x));
			theDim1Volume4D =Load1stDimVolume(theFilename);
			theDim1Volume4D =double(theDim1Volume4D);
					
			%Load and Apply the pieces' mask
			theFilename =fullfile(theTempDatasetDir, sprintf('mask_%.8d', x));
			theDim1Mask4D =Load1stDimVolume(theFilename);
			theDim1Volume4D(~theDim1Mask4D)=0;

			
			%I support multiple reference time course, and I will give each Ideals a Pearson correlation brain
			for y=1:size(AROITimeCourse, 2),
				%Revise the dataset with covariables at first
				if ~isempty(theCovariables),
					AROITimeCourse(:, y) =Brain1D_RegressOutCovariables(AROITimeCourse(:, y), theCovariables);
					theDim1Volume4D =Brain4D_RegressOutCovariables(theDim1Volume4D, theCovariables);
				end
				
				%Compute the Pearson coeffecient of ROI with a 3D+time Brain, return a 3D brain whose elements are the coefficients between the ROI averaged time course and the full 3D+time Brain
				theCorrResult =PearsonCorrWithROI(AROITimeCourse(:, y), theDim1Volume4D);
				
				%Save to file
				theFilename =fullfile(theTempDatasetDir, sprintf('result%.2d_%.8d', y, x));		
				save(theFilename, 'theCorrResult');
			end
			fprintf('.');
		end
		clear theDim1Volume4D   theDim1Mask4D	theCorrResult;
		
		%Construct the 3D+time Dataset from files again
		fprintf('\n\t ReConstructing 3D Dataset Functional Connectivity.\tWait...');
		%Construct the correlation map's filenames, 20070905
		[pathstr, name, ext, versn] = fileparts(AResultFilename);
		ResultMaps =[];
		for  y=1:size(AROITimeCourse, 2),
			ResultMaps =[ResultMaps;{[pathstr, filesep ,name, sprintf('%.2d',y), ext]}];
		end
		%Reconstruct the Result correlation map from pieces
		for  y=1:size(AROITimeCourse, 2),
			theDataset3D=zeros(nDim1, nDim2, nDim3);
			for x=1:(NumComputingCount)
				rest_waitbar(x/(floor(nDim1/NumPieces_Dim1)+1), ...
							'Functional Connectivity 3D Brain reconstructing. Please wait...', ...
							'REST working','Child','NeedCancelBtn');
				
				theFilename =fullfile(theTempDatasetDir, sprintf('result%.2d_%.8d', y, x));
				%fprintf('\t%d',x);% Just for debugging
				if x~=(floor(nDim1/NumPieces_Dim1)+1)
					theDataset3D(((x-1)*NumPieces_Dim1+1):(x*NumPieces_Dim1),:,:)=Load1stDimVolume(theFilename);
				else
					theDataset3D(((x-1)*NumPieces_Dim1+1):end,:,:)=Load1stDimVolume(theFilename);
				end		
				fprintf('.');
			end
			
			if size(AROITimeCourse, 2)>1,
				%Save every maps from result maps
				fprintf('\n\t Saving Functional Connectivity maps: %s\tWait...', ResultMaps{y, 1});	
				rest_writefile(single(theDataset3D), ...
					ResultMaps{y, 1}, ...
					BrainSize,VoxelSize,Header, 'single'); %Revised by YAN Chao-Gan, 090321. Result data will be stored in 'single' format. %'double');
			elseif size(AROITimeCourse, 2)==1,
				%There will be no y loop, just one saving
				%Save Functional Connectivity image to disk
				fprintf('\n\t Saving Functional Connectivity map.\tWait...');	
				rest_writefile(single(theDataset3D), ...
					AResultFilename, ...
					BrainSize,VoxelSize,Header, 'single'); %Revised by YAN Chao-Gan, 090321. Result data will be stored in 'single' format. %'double');
			end%end if
		end%end for	
	end%voxel/region wise
	

	theElapsedTime =cputime - theElapsedTime;
	fprintf('\n\t Functional Connectivity compution over, elapsed time: %g seconds.\n', theElapsedTime);
	

	%After Band pass filter, remove the temporary files
	ans=rmdir(theTempDatasetDir, 's');%suppress the error msg
%end

%Save the 1st dimension of the 4D dataset to files
function Save1stDimPieces(ATempDir, A4DVolume, AFilenamePrefix)
    NumPieces_Dim1 =4;	%Constant number to divide the first dimension to "NumPieces_Dim1" pieces
	NumComputingCount =floor(size(A4DVolume,1)/NumPieces_Dim1);
	if NumComputingCount< (size(A4DVolume,1)/NumPieces_Dim1),
		NumComputingCount =NumComputingCount +1;
	else
	end
	for x = 1:(NumComputingCount),
	%for x = 1:(floor(size(A4DVolume,1)/NumPieces_Dim1)+1)
		rest_waitbar(x/(floor(size(A4DVolume,1)/NumPieces_Dim1)+1), ...
					'Cut one Big 3D+time Dataset into pieces of 3D+time Dataset Before Functional Connectivity. Please wait...', ...
					'REST working','Child','NeedCancelBtn');
					
		theFilename =fullfile(ATempDir, sprintf('%s%.8d',AFilenamePrefix, x));
		if x~=(floor(size(A4DVolume,1)/NumPieces_Dim1)+1)
			the1stDim = A4DVolume(((x-1)*NumPieces_Dim1+1):(x*NumPieces_Dim1), :,:,:);
		else
			the1stDim = A4DVolume(((x-1)*NumPieces_Dim1+1):end, :,:,:);
		end
		save(theFilename, 'the1stDim'); 		
	end	

%Load the 1st dimension of the 4D dataset from files, return a Matrix not a struct
function Result=Load1stDimVolume(AFilename)	
	Result =load(AFilename);
	theFieldnames=fieldnames(Result);	
	% Result =eval(sprintf('Result.%s',the1stField));%remove the struct variable to any named variable with a matrix
	Result = Result.(theFieldnames{1});

%Compute the Pearson coeffecient of ROI with a 3D+time Brain, return a 3D brain whose elements are the coefficients between the ROI averaged time course and the full 3D+time Brain
%Dawnwei.Song, 20070903
function ResultCorrCoef3DBrain=PearsonCorrWithROI(AROITimeCourse, ABrain4D);
	[nDim1, nDim2, nDim3, nDim4]=size(ABrain4D);
	%Remove the mean
	ABrain4D = ABrain4D - repmat(sum(ABrain4D,4)/nDim4,[1, 1, 1, nDim4]);
	AROITimeCourse =AROITimeCourse -repmat(sum(AROITimeCourse)/nDim4, [size(AROITimeCourse,1), size(AROITimeCourse,2)]);
	% For denominator
	ABrainSTD= squeeze(std(ABrain4D, 0, 4));
	ABrainSTD=ABrainSTD * std(AROITimeCourse);
	
	% (1*sampleLength) A matrix * B matrix (sampleLength * VoxelCount)
	ABrain4D =reshape(ABrain4D, nDim1*nDim2*nDim3, nDim4)';
	AROITimeCourse =reshape(AROITimeCourse, 1, nDim4);
	ABrain4D = AROITimeCourse * ABrain4D /(nDim4 -1);
	ABrain4D =squeeze(reshape(ABrain4D', nDim1, nDim2, nDim3, 1));
	
	% oldState =warning('query', 'MATLAB:divideByZero');
	% warning('off', 'MATLAB:divideByZero');
	ABrainSTD(find(ABrainSTD==0))=inf;%Suppress NaN to zero when denominator is zero
	ResultCorrCoef3DBrain =ABrain4D ./ABrainSTD;
	% ResultCorrCoef3DBrain(find(ABrainSTD==0)) =0; %Suppress NaN to zero when denominator is zero
	% warning(oldState.state, 'MATLAB:divideByZero');
	
function Result =Brain4D_RegressOutCovariables(ABrain4D, ABasisFunc)
%20070926, Regress some covariables out first	
	%Result =( E - X(X'X)~X')Y
	[nDim1, nDim2, nDim3, nDim4]=size(ABrain4D);
	
	%Make sure the 1st dim of ABasisFunc is nDim4 long
	if size(ABasisFunc,1)~=nDim4, error('The length of Covariables don''t match with the volume.'); end
	
	% (1*sampleLength) A matrix * B matrix (sampleLength * VoxelCount)
	ABrain4D =reshape(ABrain4D, nDim1*nDim2*nDim3, nDim4)';
	Result =(eye(nDim4) - ABasisFunc * inv(ABasisFunc' * ABasisFunc)* ABasisFunc') * ABrain4D;
	%20071102 Bug fixed squeeze must not be excluded because nDim1 may be ONE !!!
	%Result =squeeze(reshape(Result', nDim1, nDim2, nDim3, nDim4));
	Result =reshape(Result', nDim1, nDim2, nDim3, nDim4);

function Result =Brain1D_RegressOutCovariables(ABrain1D, ABasisFunc)
%20070926, Regress some covariables out first	
	%Result =( E - X(X'X)~X')Y
	%Make sure the input is a column vector
	% ABrain1D =reshape(ABrain1D, prod(size(ABrain1D)), 1);
	
	%Make sure the 1st dim of ABasisFunc is nDim4 long
	if size(ABasisFunc,1)~=length(ABrain1D), error('The length of Covariables don''t match with the volume.'); end
	
	% (1*sampleLength) A matrix * B matrix (sampleLength * VoxelCount)	
	Result =(eye(size(ABrain1D, 1)) - ABasisFunc * inv(ABasisFunc' * ABasisFunc)* ABasisFunc') * ABrain1D;
	
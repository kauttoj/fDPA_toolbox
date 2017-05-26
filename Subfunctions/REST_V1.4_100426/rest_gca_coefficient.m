function [ResultMap1,ResultMap2] = rest_gca_coefficient(DataDir,AMaskFilename, AROIDef,AResultFilename, ACovariablesDef,Order)
% Granger Causality Analysis on Coefficient
% AROIList would be treated as a mask in which time courses would be averaged to produce a new time course representing the ROI area
% Input:
% 	ADataDir			where the 3d+time dataset stay, and there should be 3d EPI functional image files. It must not contain / or \ at the end.
% 	AMaskFilename		the mask file name, I only compute the point within the mask
% 	AROIList		the mask list , ROI list definition
%	AResultFilename		the output filename
%	ACovariablesDef
%   Order: the number of time points that needed to be deleted  
% Output:
%	AResultFilename	the filename of GCA result
%-----------------------------------------------------------
%	Copyright(c) 2007~2010
%	State Key Laboratory of Cognitive Neuroscience and Learning in Beijing Normal University
%	Written by Zhenxiang Zang 
%	http://www.restfmri.net
%-----------------------------------------------------------
% 	Mail to Authors:  <a href="zangzx416@gmail.com">Zhenxiang Zang</a>; <a href="ycg.yan@gmail.com">Chaogan Yan</a> 
%	


	theElapsedTime =cputime;
	fprintf('\nComputing GCA with:\t"%s"',DataDir);
	[AllVolume,VoxelSize,theImgFileList, Header] =rest_to4d(DataDir);
	% examin the dimensions of the functional images and set mask 
	nDim1 = size(AllVolume,1); nDim2 = size(AllVolume,2); nDim3 = size(AllVolume,3);nDim4 = size(AllVolume,4);
	BrainSize = [nDim1 nDim2 nDim3]; 
	sampleLength = size(theImgFileList,1);%sampleLength = 230
	
	%20070512	Saving a big 3D+time Dataset to small pieces by its first dimension to make this process run at least
	% put pieces of 4D dataset to the temp dir determined by the current time
	theTempDatasetDirName =sprintf('GCA_%d_%s', fix((1e4) *rem(now, 1) ),rest_misc('GetCurrentUser'));%fc_creattime
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
        else
            theCovariables=ones(nDim4,1);
        end
				
		%Calcute the corelation matrix and save to a text file
            if size(theROITimeCourses,2)~=2,
               error ('Two ROI series needed. Please recheck');
            else
               [ResultMap1,ResultMap2] = restgca_CROI(theROITimeCourses,Order,theCovariables);
            end
            AResultFilename1 = [AResultFilename,sprintf('resultx2y')];
            AResultFilename2 = [AResultFilename,sprintf('resulty2x')];
            save([AResultFilename1, '.txt'], 'ResultMap1', '-ASCII', '-DOUBLE','-TABS');
            save([AResultFilename2, '.txt'], 'ResultMap2', '-ASCII', '-DOUBLE','-TABS');
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
		
		fprintf('\n\t Build GCA mask.\tWait...');
		mask =logical(mask);%Revise the mask to ensure that it contain only 0 and 1	
		mask =	repmat(mask, [1, 1, 1, sampleLength]);	
		%Save mask pieces to disk to make this program at least run
		Save1stDimPieces(theTempDatasetDir, mask, 'mask_');	
		
		fprintf('\n\t Build Covariables time course.\tWait...');
		%If there are covariables, 20071002
		theCovariables =[];
		if exist(ACovariablesDef.ort_file, 'file')==2,
			theCovariables =load(ACovariablesDef.ort_file);
        else
            theCovariables=ones(nDim4,1);
        end
        
		fprintf('\n\t GCA is computing.\tWait...');		
	    NumPieces_Dim1 =4;	%Constant number to divide the first dimension to "NumPieces_Dim1" pieces
		NumComputingCount =floor(nDim1/NumPieces_Dim1);
		if NumComputingCount< (nDim1/NumPieces_Dim1),
			NumComputingCount =NumComputingCount +1;
		else
		end
		for x=1:(NumComputingCount),	%20071129
		%for x=1:(floor(nDim1/NumPieces_Dim1) +1)
			rest_waitbar(x/(floor(nDim1/NumPieces_Dim1) +1), ...
						'Computing GCA. Please wait...', ...
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
				
				%Compute the Granger Causality of ROI with a 3D+time Brain, return a 3D brain whose elements are the coefficients between the ROI averaged time course and the full 3D+time Brain
				[ResultMap1,ResultMap2,ResultMap3,ResultMap4]=restgca_coefficient(AROITimeCourse(:, y), theDim1Volume4D,Order,theCovariables);
				
				%Save to file
				theFilename1 =fullfile(theTempDatasetDir, sprintf('resultx2y%.2d_%.8d', y, x));
                theFilename2 =fullfile(theTempDatasetDir, sprintf('resulty2x%.2d_%.8d', y, x));
                theFilename3 =fullfile(theTempDatasetDir, sprintf('resultx2y_AR%.2d_%.8d', y, x));
                theFilename4 =fullfile(theTempDatasetDir, sprintf('resulty2x_AR%.2d_%.8d', y, x));
                for i = 1:Order,
                    ResultMapX2Y = single(cell2mat(ResultMap1(i)));
                    ResultMapY2X = single(cell2mat(ResultMap2(i)));
                    ResultMapX2Y_AR = single(cell2mat(ResultMap3(i)));
                    ResultMapY2X_AR = single(cell2mat(ResultMap4(i)));
                    save([theFilename1,num2str(Order-i+1)], 'ResultMapX2Y');
                    save([theFilename2,num2str(Order-i+1)], 'ResultMapY2X');
                    save([theFilename3,num2str(Order-i+1)], 'ResultMapX2Y_AR');
                    save([theFilename4,num2str(Order-i+1)], 'ResultMapY2X_AR');
                    clear ResultMapX2Y ResultMapY2X ResultMapX2Y_AR ResultMapY2X_AR
                end
			end
			fprintf('.');
		end
		clear theDim1Volume4D theDim1Mask4D ResultMap1 ResultMap2 ResultMap3 ResultMap4;
		
		%Construct the 3D+time Dataset from files again
		fprintf('\n\t ReConstructing 3D Dataset GCA.\tWait...');
		%Construct the correlation map's filenames, 20070905
		[pathstr, name, ext, versn] = fileparts(AResultFilename);
		ResultMap1 =[];
        ResultMap2 =[];
        ResultMap3 =[];
        ResultMap4 =[];
		for  y=1:size(AROITimeCourse, 2),
			ResultMap1 =[ResultMap1;{[pathstr, filesep ,name, sprintf('%.2d',y), ext]}];
            ResultMap2 =[ResultMap2;{[pathstr, filesep ,name, sprintf('%.2d',y), ext]}];
            ResultMap3 =[ResultMap3;{[pathstr, filesep ,name, sprintf('%.2d',y), ext]}];
            ResultMap4 =[ResultMap4;{[pathstr, filesep ,name, sprintf('%.2d',y), ext]}];
		end
		%Reconstruct the Result correlation map from pieces
        for  i=1:Order
		     for  y=1:size(AROITimeCourse, 2),
			      theDataset3D1=zeros(nDim1, nDim2, nDim3);
                  theDataset3D2=zeros(nDim1, nDim2, nDim3);
                  theDataset3D3=zeros(nDim1, nDim2, nDim3);
                  theDataset3D4=zeros(nDim1, nDim2, nDim3);
			      for x=1:(NumComputingCount)
				      rest_waitbar(x/(floor(nDim1/NumPieces_Dim1)+1), ...
							'GCA 3D Brain reconstructing. Please wait...', ...
							'REST working','Child','NeedCancelBtn');
				
				      theFilename1 =fullfile(theTempDatasetDir, sprintf('resultx2y%.2d_%.8d', y, x));
                      theFilename2 =fullfile(theTempDatasetDir, sprintf('resulty2x%.2d_%.8d', y, x));
                      theFilename3 =fullfile(theTempDatasetDir, sprintf('resultx2y_AR%.2d_%.8d', y, x));
                      theFilename4 =fullfile(theTempDatasetDir, sprintf('resulty2x_AR%.2d_%.8d', y, x));

                      if x~=(floor(nDim1/NumPieces_Dim1)+1)
					     theDataset3D1(((x-1)*NumPieces_Dim1+1):(x*NumPieces_Dim1),:,:)=Load1stDimVolume([theFilename1,num2str(Order-i+1)]);
                         theDataset3D2(((x-1)*NumPieces_Dim1+1):(x*NumPieces_Dim1),:,:)=Load1stDimVolume([theFilename2,num2str(Order-i+1)]);
                         theDataset3D3(((x-1)*NumPieces_Dim1+1):(x*NumPieces_Dim1),:,:)=Load1stDimVolume([theFilename3,num2str(Order-i+1)]);
                         theDataset3D4(((x-1)*NumPieces_Dim1+1):(x*NumPieces_Dim1),:,:)=Load1stDimVolume([theFilename4,num2str(Order-i+1)]);
                      else
					     theDataset3D1(((x-1)*NumPieces_Dim1+1):end,:,:)=Load1stDimVolume([theFilename1,num2str(Order-i+1)]);
                         theDataset3D2(((x-1)*NumPieces_Dim1+1):end,:,:)=Load1stDimVolume([theFilename2,num2str(Order-i+1)]);
                         theDataset3D3(((x-1)*NumPieces_Dim1+1):end,:,:)=Load1stDimVolume([theFilename3,num2str(Order-i+1)]);
                         theDataset3D4(((x-1)*NumPieces_Dim1+1):end,:,:)=Load1stDimVolume([theFilename4,num2str(Order-i+1)]);
                      end		
				      fprintf('.');
                  end
			
			      if size(AROITimeCourse, 2)>1,
				  %Save every maps from result maps
	
				    rest_writefile(single(theDataset3D1), ...
					   ResultMap1{y, 1}, ...
					   BrainSize,VoxelSize,Header, 'single'); %Revised by YAN Chao-Gan, 090321. Result data will be stored in 'single' format. %'double');
                    rest_writefile(single(theDataset3D2), ...
					   ResultMap2{y, 1}, ...
					   BrainSize,VoxelSize,Header, 'single'); 
                   rest_writefile(single(theDataset3D3), ...
					   ResultMap3{y, 1}, ...
					   BrainSize,VoxelSize,Header, 'single');
                   rest_writefile(single(theDataset3D4), ...
					   ResultMap4{y, 1}, ...
					   BrainSize,VoxelSize,Header, 'single');
			     elseif size(AROITimeCourse, 2)==1,
				        %There will be no y loop, just one saving
				    fprintf('\n\t Saving GCA map.\tWait...');	
                    AResultFilename1=[AResultFilename,'x2y_',num2str(Order-i+1)];
                    AResultFilename2=[AResultFilename,'y2x_',num2str(Order-i+1)];    
                    AResultFilename3=[AResultFilename,'x2y_AR_',num2str(Order-i+1)]; 
                    AResultFilename4=[AResultFilename,'y2x_AR_',num2str(Order-i+1)]; 
				    rest_writefile(single(theDataset3D1), ...
					      AResultFilename1, ...
					      BrainSize,VoxelSize,Header, 'single'); 
                    rest_writefile(single(theDataset3D2), ...
					      AResultFilename2, ...
					      BrainSize,VoxelSize,Header, 'single'); 
                    rest_writefile(single(theDataset3D3), ...
					      AResultFilename3, ...
					      BrainSize,VoxelSize,Header, 'single');
                    rest_writefile(single(theDataset3D4), ...
					      AResultFilename4, ...
					      BrainSize,VoxelSize,Header, 'single');
                %Revised by YAN Chao-Gan, 090321. Result data will be stored in 'single' format. %'double');
			    end%end if
		     end%end for	
	      end%voxel/region wise
      end
	

	theElapsedTime =cputime - theElapsedTime;
	fprintf('\n\t GCA compution over, elapsed time: %g seconds.\n', theElapsedTime);
	

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
		     rest_waitbar(x/(floor(size(A4DVolume,1)/NumPieces_Dim1)+1), ...
					'Cut one Big 3D+time Dataset into pieces of 3D+time Dataset Before GCA. Please wait...', ...
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

%rest_regress
function beta = rest_regress(y,X)
         [n,ncolX] = size(X);
         [Q,R,perm] = qr(X,0);
         p = sum(abs(diag(R)) > max(n,ncolX)*eps(R(1)));
         if p < ncolX,
            R = R(1:p,1:p);
            Q = Q(:,1:p);
            perm = perm(1:p);
         end
         beta = zeros(ncolX,1);
         beta(perm) = R \ (Q'*y);

% voxel-wise computation
function [ResultMap1,ResultMap2,ResultMap3,ResultMap4]=restgca_coefficient(AROITimeCourse, ABrain4D,Order,theCovariables)
         ResultMap1={};ResultMap2={};ResultMap3={};ResultMap4={};
         
         [nDim1, nDim2, nDim3, nDim4]=size(ABrain4D);
         AROITimeCourse = reshape(AROITimeCourse, 1, nDim4)';
         AROITimeCourse_now = AROITimeCourse(Order+1:nDim4);
   
         ABrain4D = reshape(ABrain4D, nDim1*nDim2*nDim3, nDim4)';
         
         theCovariables = [theCovariables(Order+1:end,:),ones(nDim4-Order,1)];

         AX = ones(nDim4-Order,Order);
         BY = ones(nDim4-Order,Order);
   
         AllResultX2Y = ones(Order,nDim1*nDim2*nDim3);AllResultX2Y_AR = ones(Order,nDim1*nDim2*nDim3);
         AllResultY2X = ones(Order,nDim1*nDim2*nDim3);AllResultY2X_AR = ones(Order,nDim1*nDim2*nDim3);
         
         for i = 1:nDim1*nDim2*nDim3,
             Y_TimeCourse = ABrain4D(:,i);
             Y_TimeCourse_now = Y_TimeCourse(Order+1:nDim4);
             theJudgment = sum(Y_TimeCourse_now.^2);
             
             for k = 1:Order,%set order       
                 AX(:,k)=AROITimeCourse(k:nDim4-Order+k-1);
                 BY(:,k)=Y_TimeCourse(k:nDim4-Order+k-1);
             end
             
             Regressors = [AX,BY,theCovariables];
             ResultX2Y = rest_regress(Y_TimeCourse_now,Regressors);
             ResultY2X = rest_regress(AROITimeCourse_now,Regressors);
             AllResultX2Y(:,i) = ResultX2Y(1:Order)';
             AllResultY2X(:,i) = ResultY2X(Order+1:Order*2)';
             AllResultX2Y_AR(:,i) = ResultX2Y(Order+1:Order*2)';
             
             if theJudgment < 10,
                AllResultY2X_AR(:,i) = zeros(Order,1);
             else
                AllResultY2X_AR(:,i) = ResultY2X(1:Order)';
             end
             
         end
         
         for j = 1:Order,
             ResultMap1 = [ResultMap1,{reshape(AllResultX2Y(j,:),nDim1,nDim2,nDim3)}];
             ResultMap2 = [ResultMap2,{reshape(AllResultY2X(j,:),nDim1,nDim2,nDim3)}];
             ResultMap3 = [ResultMap3,{reshape(AllResultX2Y_AR(j,:),nDim1,nDim2,nDim3)}];
             ResultMap4 = [ResultMap4,{reshape(AllResultY2X_AR(j,:),nDim1,nDim2,nDim3)}];       
         end
 
% ROI-wise computaion
function [ResultMap1,ResultMap2] = restgca_CROI(theROITimeCourses,Order,theCovariables)
         nDim4 = length(theROITimeCourses);
         AX = ones(nDim4-Order,Order);
         BY = ones(nDim4-Order,Order);
           
         theCovariables = [theCovariables(Order+1:end,:),ones(nDim4-Order,1)];
            
         AROITimeCourse_1=theROITimeCourses(:,1);
         AROITimeCourse_2=theROITimeCourses(:,2);
         AROITimeCourse_1now=AROITimeCourse_1(Order+1:nDim4);        
         AROITimeCourse_2now=AROITimeCourse_2(Order+1:nDim4);
            
          for k = 1:Order,
              AX(:,k)=AROITimeCourse_1(k:nDim4-Order+k-1);
              BY(:,k)=AROITimeCourse_2(k:nDim4-Order+k-1);
          end
          
          Regressors1 = [AX,BY,theCovariables];
          Regressors2 = [BY,AX,theCovariables];
          ResultX2Y = rest_regress(AROITimeCourse_2now,Regressors1);
          ResultY2X = rest_regress(AROITimeCourse_1now,Regressors2);
          ResultMap1 = reshape(ResultX2Y(1:Order*2),Order,2);
          ResultMap2 = reshape(ResultY2X(1:Order*2),Order,2);
          
	
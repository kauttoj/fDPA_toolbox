function [] = alff(ADataDir,ASamplePeriod, ALowPass_HighCutoff, AHighPass_LowCutoff, AMaskFilename,AResultFilename)
% Use ALFF method to compute the brain and return a ALFF brain map which reflects the "energy" of the voxels' BOLD signal
% FORMAT    function [] = alff(ADataDir,ASamplePeriod, ALowPass_HighCutoff, AHighPass_LowCutoff, AMaskFilename,AResultFilename)
% Input:
% 	ADataDir			where the 3d+time dataset stay, and there should be 3d EPI functional image files. It must not contain / or \ at the end.
% 	ASamplePeriod		TR, or like the variable name
% 	AHighPass_LowCutoff			the low edge of the pass band
% 	ALowPass_HighCutoff			the High edge of the pass band
% 	AMaskFilename		the mask file name, I only compute the point within the mask
%	AResultFilename		the output filename
% Output:
%	AResultFilename	the filename of ALFF result
%-----------------------------------------------------------
%	Copyright(c) 2007~2010
%	State Key Laboratory of Cognitive Neuroscience and Learning in Beijing Normal University
%	Written by Xiao-Wei Song 
%	http://resting-fmri.sourceforge.net
%-----------------------------------------------------------
% 	Mail to Authors:  <a href="Dawnwei.Song@gmail.com">Xiaowei Song</a>; <a href="ycg.yan@gmail.com">Chaogan Yan</a> 
%	Version=1.4;
%	Release=100420;
%   Revised by YAN Chao-Gan, 080610. NIFTI compatible
%   Revised by YAN Chao-Gan, 090321. Result data will be saved in the format 'single'.
%   Last Revised by YAN Chao-Gan, 100420. Fixed a bug in calculating the frequency band.


	if nargin~=6
        error(' Error using ==> alff. 6 arguments wanted.'); 
    end
		
	theElapsedTime =cputime;
	fprintf('\nComputing ALFF with:\t"%s"', ADataDir);
	[AllVolume,vsize,theImgFileList, Header] =rest_to4d(ADataDir);
	
	% examin the dimensions of the functional images and set mask 
	[nDim1 nDim2 nDim3 nDim4]=size(AllVolume);
	%nDim1 = size(AllVolume,1); nDim2 = size(AllVolume,2); nDim3 = size(AllVolume,3);
	isize = [nDim1 nDim2 nDim3]; 
	
	%20070512	Saving a big 3D+time Dataset to small pieces by its first dimension to make this process run at least
	% put pieces of 4D dataset to the temp dir determined by the current time
	theTempDatasetDirName =sprintf('ALFF_%d_%s', fix((1e4) *rem(now, 1) ),rest_misc('GetCurrentUser'));	
	theTempDatasetDir =[tempdir theTempDatasetDirName] ;
	ans=rmdir(theTempDatasetDir, 's');%suppress the error msg
	mkdir(tempdir, theTempDatasetDirName);	%Matlab 6.5 compatible
	
	Save1stDimPieces(theTempDatasetDir, AllVolume, 'dim1_');
	clear AllVolume;%Free large memory
%mask selection, added by Xiaowei Song, 20070421
	fprintf('\n\t Load mask "%s".', AMaskFilename);	
	mask=rest_loadmask(nDim1, nDim2, nDim3, AMaskFilename);
	
	fprintf('\n\t Build ALFF filtered mask.\tWait...');
	sampleFreq 	 = 1/ASamplePeriod; 
	sampleLength = size(theImgFileList,1);
	paddedLength = rest_nextpow2_one35(sampleLength); %2^nextpow2(sampleLength);		
	freqPrecision= sampleFreq/paddedLength;
		
	mask =logical(mask);%Revise the mask to ensure that it contain only 0 and 1	
	maskLowPass =	repmat(mask, [1, 1, 1, paddedLength]);
	maskHighPass=	maskLowPass;
	clear mask;
	
	%20071226 ALFF parameters
    %Revised by YAN Chao-Gan, 100420. Fixed the bug in calculating the frequency band.
	%idxLowPass_HighCutoff	=round(ALowPass_HighCutoff *paddedLength *ASamplePeriod);
	%% GENERATE LOW PASS WINDOW	20070514, reference: fourior_filter.c in AFNI
	if (ALowPass_HighCutoff>=sampleFreq/2)||(ALowPass_HighCutoff==0)		
		maskLowPass(:,:,:,:)=1;	%All pass
	elseif (ALowPass_HighCutoff>0)&&(ALowPass_HighCutoff< freqPrecision)		
		maskLowPass(:,:,:,:)=0;	% All stop
	else
		% Low pass, such as freq < 0.08 Hz
		idxLowPass_HighCutoff	=round(ALowPass_HighCutoff *paddedLength *ASamplePeriod + 1); %Revised by YAN Chao-Gan, 100420. Fixed the bug in calculating the frequency band. %idxLowPass_HighCutoff	=round(ALowPass_HighCutoff *paddedLength *ASamplePeriod);
		idxLowPass_HighCutoff2	=paddedLength+2 -idxLowPass_HighCutoff;				%Center Index =(paddedLength/2 +1)
		%maskLowPass(:,:,:,1:idxCutoff)=1;			%Low pass, contain DC
		maskLowPass(:,:,:,idxLowPass_HighCutoff+1:idxLowPass_HighCutoff2-1)=0; %High eliminate
		%maskLowPass(:,:,:,idxCutoff2:paddedLength)=1;	%Low pass
	end
	
	%ALFF parameters 20071226
% 	idxHighPass_LowCutoff	=round(AHighPass_LowCutoff *paddedLength *ASamplePeriod);
	%%GENERATE HIGH PASS WINDOW	
	if (round(AHighPass_LowCutoff *paddedLength *ASamplePeriod)==0) %Revised by YAN Chao-Gan, 100420. Fixed the bug in calculating the frequency band. %if (AHighPass_LowCutoff < freqPrecision)	
		maskHighPass(:,:,:,:)=1;	%All pass
	elseif (AHighPass_LowCutoff >= sampleFreq/2)
		maskHighPass(:,:,:,:)=0;	% All stop
	else
		% high pass, such as freq > 0.01 Hz
		idxHighPass_LowCutoff	=round(AHighPass_LowCutoff *paddedLength *ASamplePeriod + 1); %Revised by YAN Chao-Gan, 100420. Fixed the bug in calculating the frequency band. %idxHighPass_LowCutoff	=round(AHighPass_LowCutoff *paddedLength *ASamplePeriod);
		idxHighPass_LowCutoff2	=paddedLength+2 -idxHighPass_LowCutoff;				%Center Index =(paddedLength/2 +1)
		maskHighPass(:,:,:,1:idxHighPass_LowCutoff-1)=0;	%Low eliminate
		%maskHighPass(:,:,:,idxCutoff:idxCutoff2)=1;	%High Pass
		maskHighPass(:,:,:,idxHighPass_LowCutoff2+1:paddedLength)=0;	%Low eliminate
	end	
	%Combine the low pass mask and the high pass mask
	%(~maskHighPass)=0;	%Don't combine because filter will not work when I only want low-pass or high-pass after combination, 20070517
	%Save mask pieces to disk to make this program at least run
	Save1stDimPieces(theTempDatasetDir, maskLowPass, 'fmLow_');	
	Save1stDimPieces(theTempDatasetDir, maskHighPass, 'fmHigh_');	
	clear maskLowPass maskHighPass; %Free large memory

	%20070513	remove trend --> FFT --> filter --> inverse FFT --> retrend 	
	if rest_misc( 'GetMatlabVersion')>=7.3
		fftw('dwisdom');
	end	
	fprintf('\n\t ALFF computing.\tWait...');		
    NumPieces_Dim1 =4;	%Constant number to divide the first dimension to "NumPieces_Dim1" pieces
	NumComputingCount =floor(nDim1/NumPieces_Dim1);
	if NumComputingCount< (nDim1/NumPieces_Dim1),
		NumComputingCount =NumComputingCount +1;
	else
	end
	for x=1:(NumComputingCount),
%	for x=1:(floor(nDim1/NumPieces_Dim1) +1)
		rest_waitbar(x/(floor(nDim1/NumPieces_Dim1) +1), ...
					'Computing ALFF. Please wait...', ...
					'REST working','Child','NeedCancelBtn');
					
		%%Remove the linear trend first, ref: fourier_filter.c in AFNI, 20070509
		%Get every slope and intercept within the mask
		theFilename =fullfile(theTempDatasetDir, sprintf('dim1_%.8d', x));
		theDim1Volume4D =Load1stDimVolume(theFilename);
		theDim1Volume4D =double(theDim1Volume4D);
				
		%Save the linear trend
		% theTrend_Intercept=theDim1Volume4D(:,:,:, 1);
		% theTrend_Slope= (theDim1Volume4D(:,:,:, end) -theTrend_Intercept) /double(sampleLength-1);
		% for y=1:sampleLength % Does ALFF need this routine?
			% remove the linear trend first
			% theDim1Volume4D(:,:,:, y)=theDim1Volume4D(:,:,:, y) -(theTrend_Intercept + y*theTrend_Slope);
		% end
		
		%I must Detrend it first, 20070703
		% for xx=1:size(theDim1Volume4D,1), for yy=1:size(theDim1Volume4D,2),
			% dim3PlusTimeCourse =squeeze( theDim1Volume4D(xx, yy, :, :) );
			% detrend only support 2-D operations at most, so I have to do like this
			% dim3PlusTimeCourse =detrend(dim3PlusTimeCourse');
			% I didn't add the mean back this time, 20070703
			% theDim1Volume4D(xx, yy, :, :) =dim3PlusTimeCourse';
		% end;end;
		%20071110
		for xx=1:size(theDim1Volume4D,1),
			oneAxialSlice =double(theDim1Volume4D(xx, :, :, :));
			oneAxialSlice =reshape(oneAxialSlice, 1*nDim2*nDim3, nDim4)';
			oneAxialSlice =detrend(oneAxialSlice);% +repmat(mean(oneAxialSlice), [size(oneAxialSlice,1), 1]);
			oneAxialSlice =reshape(oneAxialSlice', 1,nDim2,nDim3, nDim4);
			theDim1Volume4D(xx, :, :, :) =(oneAxialSlice);
		end;
				
		theDim1Volume4D =cat(4,theDim1Volume4D,zeros(size(theDim1Volume4D,1),nDim2,nDim3,paddedLength -sampleLength));	%padded with zero
		
		%FFT	
		theDim1Volume4D =fft(theDim1Volume4D, [], 4);
		%Low-pass Filter mask
		theFilename =fullfile(theTempDatasetDir, sprintf('fmLow_%.8d', x));
		theDim1FilterMask4D =Load1stDimVolume(theFilename);	        
		%Apply the filter Low Pass
		theDim1Volume4D(~theDim1FilterMask4D)=0;
		
		%High-pass Filter mask
		theFilename =fullfile(theTempDatasetDir, sprintf('fmHigh_%.8d', x));
		theDim1FilterMask4D =Load1stDimVolume(theFilename);	        
		%Apply the filter High Pass
		theDim1Volume4D(~theDim1FilterMask4D)=0;
		
		%Get the amplitude only in one of the symmetric sides after FFT
		theDim1Volume4D =theDim1Volume4D(:, :, :, 2:(paddedLength/2+1));
		theDim1Volume4D =abs(theDim1Volume4D);
		%Get the Power Spectrum, double it because I only want one side of both sides
		theDim1Volume4D =2*(theDim1Volume4D .* theDim1Volume4D) /sampleLength;
		theDim1Volume4D(:,:,:, end) =theDim1Volume4D(:,:,:, end) /2;
		%The DC component didn't double because it didn't have its symetric side
		%theDim1Volume4D(:,:,:,1) =theDim1Volume4D(:,:,:,1)/2;
		%Get the Square root of the power spectrum between 0.01 and 0.08, i.e., ALFF
		theDim1Volume4D =sqrt(theDim1Volume4D);
		%Averaged ALFF across 0.01~0.08
		theDim1Volume4D =sum(theDim1Volume4D,4);
		theDim1Volume4D =theDim1Volume4D /(idxLowPass_HighCutoff -idxHighPass_LowCutoff +1);
		
		%Save to file
		theFilename =fullfile(theTempDatasetDir, sprintf('result_%.8d', x));		
		save(theFilename, 'theDim1Volume4D'); 		
		fprintf('.');
	end
	clear theDim1Volume4D theTrend_Intercept theTrend_Slope theDim1FilterMask4D oneAxialSlice;
	
	%Construct the 3D+time Dataset from files again
	fprintf('\n\t ReConstructing 3D Dataset ALFF.\tWait...');
	theDataset3D=zeros(nDim1, nDim2, nDim3);
	for x=1:(NumComputingCount)
		rest_waitbar(x/(floor(nDim1/NumPieces_Dim1)+1), ...
					'ALFF 3D Brain reconstructing. Please wait...', ...
					'REST working','Child','NeedCancelBtn');
		
		theFilename =fullfile(theTempDatasetDir, sprintf('result_%.8d', x));
		%fprintf('\t%d',x);% Just for debugging
		if x~=(floor(nDim1/NumPieces_Dim1)+1)
			theDataset3D(((x-1)*NumPieces_Dim1+1):(x*NumPieces_Dim1),:,:)=Load1stDimVolume(theFilename);
		else
			theDataset3D(((x-1)*NumPieces_Dim1+1):end,:,:)=Load1stDimVolume(theFilename);
		end		
		fprintf('.');
	end
	
	%Save ALFF image to disk
	fprintf('\n\t Saving ALFF map.\tWait...');	
	rest_writefile(single(theDataset3D), ...
		AResultFilename, ...
		isize,vsize,Header, 'single'); %Revised by YAN Chao-Gan, 090321. Result data will be stored in 'single' format. %'double');

	theElapsedTime =cputime - theElapsedTime;
	fprintf('\n\t ALFF compution over, elapsed time: %g seconds.\n', theElapsedTime);

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
					'Cut one Big 3D+time Dataset into pieces of 3D+time Dataset Before ALFF. Please wait...', ...
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

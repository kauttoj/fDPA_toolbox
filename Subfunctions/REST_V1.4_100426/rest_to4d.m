function [AllVolume, VoxelSize, ImgFileList, Header] =rest_to4d(ADataDir)
%Build a 4D matrix for REST from series of Brain's volume/(time point). By Xiao-Wei Song
%------------------------------------------------------------------------------------------------------------------------------
%	Copyright(c) 2007~2010
%	State Key Laboratory of Cognitive Neuroscience and Learning in Beijing Normal University
%	Written by Xiao-Wei Song 
%	http://resting-fmri.sourceforge.net
% 	Mail to Authors:  <a href="Dawnwei.Song@gmail.com">Xiaowei Song</a>; <a href="ycg.yan@gmail.com">Chaogan Yan</a> 
%	Version=1.3;
%	Release=20090321;
%   Revised by YAN Chao-Gan 080610: NIFTI compatible
%   Revised by YAN Chao-Gan, 090321. Data in processing will not be converted to the format 'int16'.
%   Last revised by YAN Chao-Gan, 091001. If data has too huge or too many volumes, then it will be loaded into memory in 'single' format.

    theFileList = dir(ADataDir);	
	ImgFileList ={};
	for x = 3:size(struct2cell(theFileList),2)
	    if strcmpi(theFileList(x).name(end-3:end), '.hdr') 
	        if strcmpi(theFileList(x).name(1:end-4), theFileList(x+1).name(1:end-4))
				ImgFileList=[ImgFileList; {theFileList(x).name(1:end-4)}];
            else
                error('*.{hdr,img} should be pairwise. Please re-examin them.');
            end
	    end
	end
	clear theFileList;
	
	if size(ImgFileList,1)<10,
		warning('There are too few time points.(i.e. The number of the time points is less than 10)');
	end
	
	%read the normalized functional images 
	% -------------------------------------------------------------------------
	fprintf('\n\t Read 3D EPI functional images: "%s".', ADataDir);
	theDataType ='double';	%Default data-type I assumed!
	for x = 1:size(ImgFileList,1),    		

		theFilename = fullfile(ADataDir,ImgFileList{x});
		[theOneTimePoint, VoxelSize, Header] = rest_readfile(theFilename);
		%AllVolume(:,:,:,x) = uint16(theOneTimePoint);	%Dynamic decision of which data-type I choose! 20071031
		if theDataType=='uint16',
			AllVolume(:,:,:,x) = uint16(theOneTimePoint);
        elseif	theDataType=='single',
			AllVolume(:,:,:,x) = single(theOneTimePoint);
		elseif	theDataType=='double',
			AllVolume(:,:,:,x) = (theOneTimePoint);
		else
			rest_misc('ComplainWhyThisOccur');
		end
		if x==1,			
			tmpData=theOneTimePoint(0~=theOneTimePoint);
			if 0 %Revised by YAN Chao-Gan, 090321. Data will not be converted to the format 'int16'. %length(tmpData)>1000 && mean(abs(tmpData))>100,
				theDataType ='uint16';
                AllVolume =uint16(AllVolume);
				AllVolume(:,:,:,x) = uint16(theOneTimePoint);
				clear tmpData
				AllVolume =repmat(AllVolume, [1,1,1, size(ImgFileList,1)]);
            elseif prod([size(AllVolume), size(ImgFileList,1),8])>1024*1024*1024 % YAN Chao-Gan 091001, If data is with two many volumes, then it will be converted to the format 'single'.
                theDataType ='single';
                AllVolume=single(AllVolume);
                AllVolume =repmat(AllVolume, [1,1,1, size(ImgFileList,1)]);
			else
				%Double!
				theDataType ='double';
				AllVolume =repmat(AllVolume, [1,1,1, size(ImgFileList,1)]);
			end
		end
		if ~mod(x,5)
			fprintf('.');		
		end
    end     
	VoxelSize = VoxelSize';
	fprintf('\n');

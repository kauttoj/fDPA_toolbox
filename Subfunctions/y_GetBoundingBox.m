function [mn, mx, voxsize]= y_GetBoundingBox(PP)
% FORMAT [mn, mx, voxsize]= y_GetBoundingBox(PP)
% Input:
%   PP - input filename
% Output:
%   mn,mx - image dimention
%   voxsize -  vox size.
%___________________________________________________________________________
% Written by YAN Chao-Gan 090306.
% State Key Laboratory of Cognitive Neuroscience and Learning, Beijing Normal University, China, 100875
% ycg.yan@gmail.com

% Get information about the image volumes
VV = spm_vol(PP);

for V=VV', % Loop over images
	% The corners of the current volume
	d = V.dim(1:3);
	c = [	1    1    1    1
		1    1    d(3) 1
		1    d(2) 1    1
		1    d(2) d(3) 1
		d(1) 1    1    1
		d(1) 1    d(3) 1
		d(1) d(2) 1    1
		d(1) d(2) d(3) 1]';
	% The corners of the volume in mm space
    tc = V.mat(1:3,1:4)*c;
    % Max and min co-ordinates for determining a bounding-box
    mx = (max(tc,[],2)');
    mn = (min(tc,[],2)');
    % YAN Chao-Gan, 101015. No round.
    %mx = round(max(tc,[],2)');
    %mn = round(min(tc,[],2)');
end; % End loop over images

[Data,voxsize, Header] = rest_readfile(PP);
return; % Done
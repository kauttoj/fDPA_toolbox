function dvars=compute_dvars(epi_files,mask)
% BRAMILA_DVARS - Computes Derivative VARiance across voxels as defined in
% Power et al. (2012) doi:10.1016/j.neuroimage.2011.10.018
%   - Usage:
%   dvars=bramila_dvars(cfg) Returns a time series 'dvars' with a value of
%   RMS for each time point. First time point is set to 0.
%   - Input:
%   cfg is a struct with following parameters
%       Possible input formats
%       cfg.nii = 'path/to/a/nifti/file' - insert the full path to a nifti
%           file with 4D fMRI data
%       cfg.vol = vol - a matlab 4D volume with fMRI data, time on the
%           4th dimension
%       cfg.ts = ts - a two dimensional vector of time series, time on the
%           1st dimension
%       cfg.plot = 0 or 1 - set to 1 if you want to output a plot like in
%           Power et al. (2014) doi:10.1016/j.neuroimage.2013.08.048 (defult 0)
%       cfg.mask = a 3D matlab volume mask of voxels to consider for RMS computation
%           (the parameter is ignored if cfg.ts is specified)
%   - Note:
%   if more than one input format is specified matlab will give
%   priority to cfg.ts > cfg.vol > cfg.nii
%
%   Last edit: EG 2014-01-10

%% loading the data
dvars = [];
% the nii case
fprintf('..loading data\n');
for j=1:length(epi_files)
    struct = load_nii(epi_files{j});
    if j==1
        img = zeros([size(struct.img), length(epi_files)], 'single');% the FMRI data were single precision anyway..YH 2013/03/29
    end
    img(:,:,:,j) = struct.img;
end

sz=size(img);
T=sz(4);

if nargin>1
    
    if(~any(size(mask)==sz(1:3)))
        warning(['The specified mask has a different size than the fMRI data. Quitting.'])
        return;
    end
    
else
    
    mask = ones(sz(1:3));
    for t=1:T
        temp=squeeze(img(:,:,:,t));
        mask=mask.*(temp>0.1*quantile(temp(:),.98));
    end
    
end

mask_ind = find(mask>0);

% doing a reshape if needed
fprintf('..computing dvars (mask size %i)\n',length(mask_ind));

img=reshape(img,[],T);
img=img';   % Time in first dimension

img=bramila_bold2perc(img); % convert bold to percentage signal
di=diff(img);
di=[
    zeros(1,size(di,2)) % adding a zero as first sample of the derivate
    di
    ];

dvars=sqrt(mean(di(:,mask_ind>0).^2,2)); % Root Mean Square across voxels

function [y,m]=bramila_bold2perc(ts)
% BRAMILA_BOLD2PERC - Converts a time series with mean into a time series of percentage changes.
%   - Usage:
%   ts_perc = bramila_bold2perc(ts) ts is a matrix NxM where N is the
%   number of time points. Values returned are in percentages
%   - Notes:
%   If the mean is zero, then the absolute maximum is used.
%
%   The formula used follows the SPM convention, i.e. we first normalize the
%   time series so that they have 100 as mean value.

%	EG 2014-10-01
    m=mean(ts,1);
    T=size(ts,1);
    
    % if we have a signal with zero mean, we need to treat it in a special
    % way. Zero in our case is 1e5*eps i.e. roughly 10^-11
    if(any(m<1e5*eps))
        ids=find(m<1e5*eps);
        m(ids)=max(abs(ts(:,ids)));
        ts(:,ids)=ts(:,ids)+repmat(m(ids),T,1);
    end
    y=100*(ts./repmat(m,T,1))-100;
    y(isnan(y))=0;
        

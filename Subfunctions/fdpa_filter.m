function [vol,cfg]=fdpa_filter(cfg)

% cfg.filtertype = 'butter' 'highpass'
% cfg.filter_limits = [0,0.01,0.08,0.09]
% cfg.TR =
% cfg.mask =

if(isfield(cfg,'vol'))
    data=cfg.vol;
    % add check that it's a 4D vol
elseif(isfield(cfg,'infile'))
    nii=load_nii(cfg.infile);
    data=nii.img;
end

if(~isfield(cfg,'TR'))
    error('cfg.TR is a mandatory field')
end
TR=cfg.TR;
FS=1/TR;

% cut offs in Hz, default values [double check Power code]

%HPF=0.01;
%LPF=0.08;
A = [0 1 0];
DEV=[0.05 0.01 0.05];

F = [0,0.01,0.08,0.09];
if(isfield(cfg,'filter_limits'))
    %HPF=cfg.HPF;
    F = cfg.filter_limits;
end

HPF = F(2);
LPF = F(3);

% FIR or BUTTER filters
FILTERTYPE='butter';
if(isfield(cfg,'filtertype'))
    FILTERTYPE=cfg.filtertype;
    % add check that it can only be 'butter' or 'fir' case insensitive
end

switch FILTERTYPE
    case 'butter'
        FILTERORDER=2;
        if(isfield(cfg,'filterorder'))
            FILTERORDER=cfg.filterorder;
        end
        hipasscutoff=HPF/(0.5/TR);
        lowpasscutoff=LPF/(0.5/TR);
                
        if hipasscutoff>0.0001 && lowpasscutoff>0.9999
            fprintf('  Design: f>%f High-pass Butter\n',HPF);
            [b,a]=butter(FILTERORDER,hipasscutoff,'high');
        elseif hipasscutoff<0.0001 && lowpasscutoff<0.9999
            [b,a]=butter(FILTERORDER,lowpasscutoff,'low');
            fprintf('  Design: f<%f Low-pass Butter\n',LPF);
        else
            [b,a]=butter(FILTERORDER,[hipasscutoff,lowpasscutoff]);
            fprintf('  Design: %f<f<%f Band-pass Butter\n',HPF,LPF);
        end        
        
        cfg.filter.butterfreq=[hipasscutoff,lowpasscutoff];
        cfg.filter.butterorder=FILTERORDER;
        cfg.filter.b=b;
        cfg.filter.a=a;
    case 'fir'
        [N,Fo,Ao,W] = firpmord(F,A,DEV,Fs);
        if(mod(N,2)==1)
            N=N+1;
        end
        % Design filter
        b=firpm(N,Fo,Ao,W);
        a=1;
        cfg.filter.b=b;
        cfg.filter.a=a;
        % store here in the cfg.filter other FIR specific parameters
    case 'SPM_highpass'
        ;
    otherwise
        error('Unknown filter type (only ''butter'' and ''FIR'' allowed)');
end



% prepare the 4D data to be filtered
siz=size(data);
temp=reshape(data,prod(siz(1:3)),siz(4));
tsdata=double(temp');

T = size(tsdata,1);
m=mean(tsdata,1);	% storing the mean
%m=repmat(m,T,1);
for row = 1:T
    tsdata(row,:)=tsdata(row,:)-m;
end

fprintf('  Filtering data...')
if strcmp(FILTERTYPE,'SPM_highpass')
    
    blocklim = [1:round(size(tsdata,2)/100):size(tsdata,2),size(tsdata,2)];
    blocklim = unique(blocklim);
    K.RT   =  cfg.TR;% - observation interval in seconds
    K.HParam =  1/HPF;%cut-off period in seconds
    
    tsdata=tsdata';
    for i=1:(length(blocklim)-1)
        K.row  =  blocklim(i):blocklim(i+1);%- row of Y constituting block/partition s
        tsdata = spm_filter(K,tsdata);
    end
    %tsdataout(:,maskID)=filtfilt(b,a,tsdata(:,maskID));
else
    tsdata=filtfilt(b,a,tsdata);
end
fprintf(' done\n');

% NOTE: Power code applies filter in bordered data (removing stuff at beginning and end): border data is better than no data, we keep it now but later for the FC measure we use only the inside data
for row = 1:T
    tsdata(row,:)=tsdata(row,:)+m;
end
tsdata=tsdata';
vol=reshape(tsdata,size(data));

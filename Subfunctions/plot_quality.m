function plot_quality()

home = pwd;

if ~exist('RealignParameter','dir')
    error('Cannot find folder ''RealignParameter''')
end

figure('Position',[252          80         987        1014]);

cd('RealignParameter');
d = dir('*');
nam=[];
for i=1:length(d)
    if strcmp(d(i).name,'.') || strcmp(d(i).name,'..') || d(i).isdir~=1
        
    else
        cd(d(i).name)
        a = load('dvars.mat');
        b=a.dvars(2:end);
        
        col = 0.1+0.8*rand(1,3);
        subplot(3,1,1);
        plot(2:length(a.dvars),zscore(b),'Color',col);
        hold on;
        axis tight;
        
        xlabel('volume nr.');
        ylabel('dvars');
        nam{end+1}=d(i).name;
        
        temp_cfg=[];
        ts = get_realign_data();
        ts=detrend(ts,'linear');   % demean and detrend as specified in Power et al 2014
        
        if(size(ts,2)~=6)
            error(['The motion time series must have 6 motion parameters in 6 columns; the size of the input given is ' num2str(size(ts))])
        end
        prepro_suite='fsl-fs'; % 1 is FSL, 2 is SPM

        
        radius=50; % default radius
        

            % convert degrees into motion in mm;
            temp=ts(:,4:6);
            temp=(2*radius*pi/360)*temp;
            ts(:,4:6)=temp;
        
        dts=diff(ts);
        dts=[
            zeros(1,size(dts,2));
            dts
            ];  % first element is a zero, as per Power et al 2014
        fwd=sum(abs(dts),2);
        rms=sqrt(mean(ts'.^2));    % root mean square for each column        
        
        subplot(3,1,2);
        plot(1:length(rms),rms,'Color',col);
        hold on;
        axis tight;
        xlabel('volume nr.');
        ylabel('rms');
        
        subplot(3,1,3);
        plot(1:length(fwd),fwd,'Color',col);      
        hold on;
        axis tight;
        xlabel('volume nr.');
        ylabel('fwd');
        
        cd ..
    end
end
legend(nam,'location','best');
axis tight;
title(home,'interpreter','none');


cd(home);




end

function res = get_realign_data()

    in = dir(pwd);
    L = length(in);
    
    k=0;
    for i=1:L,
       
        if in(i).isdir==0
           a = in(i).name;
           if k==0 && strcmp('.txt',a((end-3):end))
               k=k+1;
                delimiterIn = ' ';
                headerlinesIn = 0;
                data = importdata(a,delimiterIn,headerlinesIn);              
           end
        end        
    end

    res = data;
    
    
end
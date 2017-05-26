function [] = showNskullstripped (skullStrippedList, N, VolumeToStart)
%N is number of volumes per figure (max is 15)
if nargin<=2
    VolumeToStart=1;   
elseif VolumeToStart>=length(skullStrippedList)
    VolumeToStart=1;
end

if nargin<2 || N >=15
    N=15;% spm_coregister can show only 15 volumes at a time
end
%startvolume = 1;
while VolumeToStart<=(length(skullStrippedList)-N)
    checkIMAGES=cell(N,1);
    for i=1:N
        checkIMAGES{i}=skullStrippedList{1,VolumeToStart+i-1};
    end
    spm_check_registration(char(checkIMAGES{:}));
    changeSPMFigureTag();
    VolumeToStart=VolumeToStart + N;
end

checkIMAGES=cell(length(skullStrippedList)-VolumeToStart+1,1);
for i=VolumeToStart:length(skullStrippedList)    
    checkIMAGES{i-VolumeToStart+1}=skullStrippedList{1,i};
end
spm_check_registration(char(checkIMAGES{:}));

function fig1 = changeSPMFigureTag()
fig1 = spm_figure('FindWin','Graphics');
spm_figure('NewPage',fig1)
%set(fig1,{'Tag'},{'PreviousFigure'});%changing tag did not help...the
%previous figure was cleared and a new figure window was created (thought 
%to do it through the pagination but haven't figured it out yet.... 
%so using debug stop...)




 
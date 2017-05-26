function varargout = rest(AOperation, varargin)
%RESTing state fMRI data analysis toolkit by Xiao-Wei Song
%-----------------------------------------------------------
%	Copyright(c) 2007~2010
%	State Key Laboratory of Cognitive Neuroscience and Learning in Beijing Normal University
%	Written by Xiao-Wei Song 
%	http://resting-fmri.sourceforge.net
% 	Mail to Authors:  <a href="Dawnwei.Song@gmail.com">SONG Xiao-Wei</a>; <a href="ycg.yan@gmail.com">YAN Chao-Gan</a>; <a href="dongzy08@gmail.com">DONG Zhang-Ye</a> 
%	Version=1.4;
%	Release=20100426;
%   Revised by YAN Chao-Gan 090321, added the fALFF module. Thank Dr. CHENG Wen-Lian for the helpful work.
%   Revised by YAN Chao-Gan and DONG Zhang-Ye 091103, added the Utilities module. 
%   Revised by YAN Chao-Gan, 091126. Checking and fixing the error of reading and writing NIfTI images when REST starts.
%   Revised by YAN Chao-Gan, 091215. Close any Utilities when quit REST. 
%   Revised by YAN Chao-Gan, DONG Zhang-Ye and ZANG Zhen-Xiang 100401. Added the Statistical Analysis and Granger Causality Analysis modules. 
%   Last revised by YAN Chao-Gan, 100426. Fixed a reading and writing bug of compatibility with SPM8.
%-----------------------------------------------------------
 
if isappdata(0, 'Rest_Cfg'),
	Rest_Cfg =getappdata(0, 'Rest_Cfg'); % run-time persistent config
else
	Rest_Cfg =[];
end	

if nargin<1, AOperation='Init'; end	%Revise the Start

switch upper(AOperation),
case 'INIT',		%Init
	if isempty(Rest_Cfg) || ~rest_misc( 'ForceCheckExistFigure' , Rest_Cfg.hFig);,
		% the first time to run this program
		% Initialize the Matlab envionment		
		clear all;
		clc;
		QuitAll;
		% Initialize self				
		Rest_Cfg =[];
		Rest_Cfg =InitControls(Rest_Cfg);
		%rest_misc( 'SetFigViewStyle', gcf);
	end
	if ~isempty(Rest_Cfg) && rest_misc( 'ForceCheckExistFigure' , Rest_Cfg.hFig),
		figure(Rest_Cfg.hFig);
	end
	if nargout>0,
		varargout{1} =Rest_Cfg.hFig;
	end
	setappdata(0, 'Rest_Cfg', Rest_Cfg);
	
	%Forcely delete the last log file to make sure there will be only one log content for one run of REST
	%recycle on;
	if 2==exist(fullfile(rest_misc('WhereIsREST'), 'rest.log'),'file'),
		delete(fullfile(rest_misc('WhereIsREST'), 'rest.log'));
	end
	diary(fullfile(rest_misc('WhereIsREST'), 'rest.log'));
    %Initialize the log file
	diary on;
    
	[theVer, theRelease] =rest_misc( 'GetRestVersion');
	disp(sprintf('Welcome: %s, %s \nREST Version: %s, Release: %s', rest_misc('GetCurrentUser'),rest_misc( 'GetDateTimeStr'), theVer, theRelease));
	
    % Added by YAN Chao-Gan, 091126. Checking and fixing the error of reading and writing NIfTI images when REST starts.
    try
        addpath(fullfile(rest_misc('WhereIsREST'), 'rest_spm5_files'));
        VTest = rest_spm_vol(fullfile(rest_misc('WhereIsREST'), 'mask','BrainMask_05_61x73x61.img'));
        DataTest = zeros([VTest(1).dim(1:3), 1]);
        DataTest(:, :, :,1) = rest_spm_read_vols(VTest(1));
        rmpath(fullfile(rest_misc('WhereIsREST'), 'rest_spm5_files'));
    catch
        rest_Fix_Read_Write_Error;
    end
	
case 'RESTART', 	%Restart	
	if nargin~=1, error('Usage: rest(''Restart'');'); end
	clear all;
	clc;	
	QuitAll;
	% Initialize self
	Rest_Cfg =[];
	Rest_Cfg =InitControls(Rest_Cfg);
	figure(Rest_Cfg.hFig);
	if nargout>0,
		varargout{1} =Rest_Cfg.hFig;
	end
	
	setappdata(0, 'Rest_Cfg', Rest_Cfg);
	
case 'QUITALL',		%QuitAll
	if nargin~=1, error('Usage: rest(''QuitAll'');'); end
	QuitAll;
	%At the end, I quit
	if ~isempty(Rest_Cfg) && rest_misc( 'ForceCheckExistFigure' , Rest_Cfg.hFig),
		delete(Rest_Cfg.hFig);
	end
	if isappdata(0, 'Rest_Cfg'),
		rmappdata(0, 'Rest_Cfg');
	end	
	clc;
	[theVer, theRelease] =rest_misc( 'GetRestVersion');
	disp(sprintf('Good Bye: %s, %s \nREST Version: %s, Release: %s', rest_misc('GetCurrentUser'),rest_misc( 'GetDateTimeStr'), theVer, theRelease));
	%Force stop the log file, 20071127
	diary off;
	%recycle off;
	
case 'STARTREHO', 	%StartReHo
	StartReHo;
case 'STARTALFF', 	%StartALFF
	StartALFF;
case 'STARTFALFF', 	%StartfALFF  --Revised by YAN Chao-Gan, 090321
	StartfALFF;
case 'UTILITIES',
    Utilities;
case 'MAILTOZANG', 	%MailToZang
	MailToZang;
case 'MAILTOSONG', 	%MailToSong
	MailToSong;
case 'OPENHELP', 	%OpenHelp
	OpenHelp;
case 'FUNCTIONALCONNECTIVITYNOTREADY',		%FunctionalConnectivityNotReady
	% msgbox(sprintf('Functional Connectivity analysis is not ready.\n\nIt would be born in the next version.'), ...
					% 'Resting State Toolkit' ,'help');
	StartFunctionalConnectivity;
case 'REST_STATISTIC',
    rest_Statistic;
case 'REST_GCA',
    rest_GCA;
otherwise	
end

function Result =InitControls(AConfig)	
	DefaultColorBackground =[1 1 1]*.5;
    offsetup=50;
	theFig =figure('Units', 'pixel', 'Toolbar', 'none', 'MenuBar', 'none', ...
					'NumberTitle', 'off', 'Visible', 'off', ... %'Name', sprintf('REST %s - %s',rest_misc( 'GetRestVersion') ,rest_misc('GetCurrentUser')) , ...					
					'Name', sprintf('REST %s',rest_misc( 'GetRestVersion')), ...
					'Position', [0,0,500, 330+offsetup], 'Resize','off', ...
					'Color', DefaultColorBackground , ...
					'DeleteFcn', sprintf('rest(''QuitAll'');')  );
	movegui(theFig, 'northwest'); 
	
	uicontrol(theFig,'Style','Text','Position',[0 286+offsetup 500 36],...
		'String','Resting State fMRI Data Analysis Toolkit',...
		'FontSize',18, ...		
		'FontWeight','Bold',...
		'ForegroundColor',[1 1 1]*.7,'BackgroundColor', DefaultColorBackground);
		
	logoPos =[10, 135+offsetup, 0,0];	
	theLogo = fullfile(rest_misc( 'WhereIsREST'), 'logo.jpg');
	if (exist(theLogo,'file')==2),
		theLogo = imread(theLogo);
		logoPos(3) =size(theLogo, 2);
		logoPos(4) =size(theLogo, 1);
		for x=1:3,	%Revise the coordinate to make it same with MATLAB
			theLogo(:, :, x) =flipud(theLogo(:, :, x));
		end
		
		hAxesLogo =axes('Parent', theFig, 'Box', 'on', ...
					  'Units', 'pixel', 'DrawMode','normal', ...
					  'Position', logoPos, ...
					  'YDir','normal', 'XTickLabel',[],'XTick',[], ...
					  'YTickLabel',[],'YTick',[], 'DataAspectRatio',[1 1 1]);
		hImgLogo =image('Tag','LogoImage', 'Parent', hAxesLogo);
		set(hAxesLogo,'YDir','normal','XTickLabel',[],'XTick',[], 'YTickLabel',[],'YTick',[]);
				
		set(hImgLogo, 'CData', theLogo);
		set(hAxesLogo, 'XLim', [1 logoPos(3)], 'YLim', [1 logoPos(4)]);
	else
		error('Please re-install REST');
	end
	
	
	uicontrol(theFig,'Style','Frame','Position', ...
			[logoPos(1)+logoPos(3)+2, logoPos(2), 500-logoPos(3)-20 ,logoPos(4)], ...
			'BackgroundColor', [1 1 1]*.0);
	uicontrol(theFig,'Style','Text','String','REST',...
		'ToolTipString',sprintf('\nby the ZangYF neuroimaging methods group of BNU\n'),...
		'Position', ...
		[logoPos(1)+logoPos(3)+12, logoPos(2)+logoPos(4)-56, 500-logoPos(3)-40 , 36], ...
		'BackgroundColor', [1 1 1]*.0, ...
		'FontSize',24,'FontWeight','Bold',...
		'ForegroundColor','b')
	% uicontrol(theFig,'Style','Text','Position',[171+40 260 250 20],...
		% 'String','developed by Song Xiaowei, He Yong',...
		% 'ToolTipString','', 'BackgroundColor', [1 1 1]*.8, ...
		% 'FontSize',10,'FontAngle','Italic')	
	% uicontrol(theFig,'Style','Text','Position',[40 180 440 80],...
		% 'String',sprintf('Ref:\n\tZang YF et.al. Neuroimage. 2004 May;22(1):394-400\n\tZang YF et.al. Brain Dev. 2007 Mar;29(2):83-91. Epub 2006 Aug 17\n\tetc.'),...
		% 'HorizontalAlignment', 'left', ...
		% 'FontSize',10,'FontAngle','Italic')	
	uicontrol(theFig,'Style','Text', 'Position', ...		
		[logoPos(1)+logoPos(3)+12, logoPos(2)+20*3, 500-logoPos(3)-40 , 20], ...
		'String','State Key Laboratory of',...
		'BackgroundColor', [1 1 1]*.0, ...
		'ToolTipString','', 'ForegroundColor', [1 1 1]*1, ...
		'FontSize',12);	
	uicontrol(theFig,'Style','Text', 'Position',...
		[logoPos(1)+logoPos(3)+12, logoPos(2)+20*2, 500-logoPos(3)-40 , 20], ...
		'String','Cognitive Neuroscience and Learning',...
		'BackgroundColor', [1 1 1]*.0, ...
		'ToolTipString','', 'ForegroundColor', 'w', ...
		'FontSize',12);	
	uicontrol(theFig,'Style','Text', 'Position',...
		[logoPos(1)+logoPos(3)+12, logoPos(2)+20, 500-logoPos(3)-40 , 20], ...
		'BackgroundColor', [1 1 1]*.0, ...
		'String','Beijing Normal University', 'ForegroundColor', [1 1 1]*1, ...
		'ToolTipString','',...
		'FontSize',12);
		
	uicontrol(theFig,'Style','Frame','Position',[10 10 480 115+offsetup], 'BackgroundColor', [0.9 0.8 0.6]);
% 	uicontrol(theFig,'Style','pushbutton', 'Position',[30 70 150 40],...
% 		'String','ReHo','ToolTipString','Regional homogeneity approach to fMRI data analysis', ...
% 		'Callback', sprintf('rest(''StartReHo'');'), ...
% 		'FontSize',16, 'FontWeight','Bold', 'ForegroundColor','m')
% 	uicontrol(theFig,'Style','pushbutton', 'Position',[200 70 150 40],...
% 		'String','ALFF', 'ToolTipString','Amplitude of low-frequency fluctuation',...		 
% 		'Callback', sprintf('rest(''StartALFF'');'), ...		
% 		'FontSize',16, 'FontWeight','Bold', ...		
% 		'ForegroundColor','m')
	uicontrol(theFig,'Style','pushbutton', 'Position',[30 70+offsetup 100 40],...
		'String','ReHo','ToolTipString','Regional homogeneity approach to fMRI data analysis', ...
		'Callback', sprintf('rest(''StartReHo'');'), ...
		'FontSize',16, 'FontWeight','Bold', 'ForegroundColor','m')
	uicontrol(theFig,'Style','pushbutton', 'Position',[140 70+offsetup 100 40],...
		'String','ALFF', 'ToolTipString','Amplitude of low-frequency fluctuation',...		 
		'Callback', sprintf('rest(''StartALFF'');'), ...		
		'FontSize',16, 'FontWeight','Bold', ...		
		'ForegroundColor','m')
	uicontrol(theFig,'Style','pushbutton', 'Position',[250 70+offsetup 100 40],...       %Revised by YAN Chao-Gan, 090321
		'String','fALFF', 'ToolTipString','fractional ALFF',...		 
		'Callback', sprintf('rest(''StartfALFF'');'), ...		
		'FontSize',16, 'FontWeight','Bold', ...		
		'ForegroundColor','m')
    uicontrol(theFig,'Style','pushbutton', 'Position',[250 20 100 40],...       %Revised by Dong,091029
		'String','Utilities',...		 
		'Callback', sprintf('rest(''Utilities'');'), ...		
		'FontSize',16, 'FontWeight','Bold', ...		
		'ForegroundColor','m')
    uicontrol(theFig,'Style','pushbutton', 'Position',[30 20 210 40],...       %Revised by Dong,091029
        'String','Statistical Analysis',...
        'Callback', sprintf('rest(''rest_Statistic'');'), ...
        'FontSize',16, 'FontWeight','Bold', ...
        'ForegroundColor','m')

	uicontrol(theFig,'Style','pushbutton', 'Position',[370 70+offsetup 100 40],...
		'String','Help',...		
		'Callback', sprintf('rest(''OpenHelp'');'), ...
		'FontSize',16, 'FontWeight','Bold', 'ForegroundColor','g')	
	uicontrol(theFig,'Style','pushbutton', 'Position',[370 20 100 40],...
		'String','Quit',...		
		'Callback', sprintf('rest(''QuitAll'');'), ...
		'FontSize',16, 'FontWeight','Bold', 'ForegroundColor','r')
	uicontrol(theFig,'Style','pushbutton', 'Position',[250 20+offsetup 100 40],...
		'String','GCA','ToolTipString','Granger Causality Analysis',...	%'FontName', 'FixedWidth', ...		
		'Callback', sprintf('rest(''rest_GCA'');'), ...
		'FontSize',16, 'FontWeight','Bold', 'ForegroundColor','m')
	% uicontrol(theFig,'Style','pushbutton', 'Position',[30 40 150 20],...
		% 'String','Mailto: Zang YuFeng',...		
		% 'Callback', sprintf('rest(''MailToZang'');'), ...
		% 'FontSize',10, 'ForegroundColor','k')
	% uicontrol(theFig,'Style','pushbutton', 'Position',[30 20 150 20],...
		% 'String','Mailto: Song XiaoWei',...
		% 'Callback', sprintf('rest(''MailToSong'');'), ...
		% 'FontSize',10, 'ForegroundColor','k')
	uicontrol(theFig,'Style','pushbutton', 'Position',[30 20+offsetup 210 40],...
		'String','Fun. Connectivity','ToolTipString','Functional  Connectivity',...	%'FontName', 'FixedWidth', ...		
		'Callback', sprintf('rest(''FunctionalConnectivityNotReady'');'), ...
		'FontSize',16, 'FontWeight','Bold', 'ForegroundColor','m')
	
	%Save Hanldes
	AConfig.hFig =theFig;
	
	Result =AConfig;
	
	set(theFig, 'Visible', 'on');
	
function QuitAll()
	%Force stopping current Callback
	delete(gcbf);
	%Close any progressbar
	rest_waitbar;
	%Close any SliceViewer
	rest_sliceviewer('QuitAllSliceViewer');
	%Close any PowerSpectrum
	rest_powerspectrum('QuitAllPowerSpectrum');
	%Close any ReHo figure
	theFig =findobj(allchild(0),'flat','Tag','figRehoMain');
	if ~isempty(theFig) && rest_misc( 'ForceCheckExistFigure' , theFig),
		delete(theFig);
	end
	%Close any ALFF figure
	theFig =findobj(allchild(0),'flat','Tag','figAlffMain');
	if ~isempty(theFig) && rest_misc( 'ForceCheckExistFigure' , theFig),
		delete(theFig);
    end
    %Close any fALFF figure   % Revised by YAN Chao-Gan, 090321
	theFig =findobj(allchild(0),'flat','Tag','figfAlffMain');
	if ~isempty(theFig) && rest_misc( 'ForceCheckExistFigure' , theFig),
		delete(theFig);
	end
	%Close any functional connectivity figure
	theFig =findobj(allchild(0),'flat','Tag','figFCMain');
	if ~isempty(theFig) && rest_misc( 'ForceCheckExistFigure' , theFig),
		delete(theFig);
    end
    
    %Close any Utilities YAN Chao-Gan 091215.
    theFig =findobj(allchild(0),'flat','Tag','figUtilities');
    if ~isempty(theFig) && rest_misc( 'ForceCheckExistFigure' , theFig),
        delete(theFig);
    end
    
    %Close any Utilities YAN Chao-Gan 091215.
    theFig =findobj(allchild(0),'flat','Tag','figAlphaSim');
    if ~isempty(theFig) && rest_misc( 'ForceCheckExistFigure' , theFig),
        delete(theFig);
    end
    
    %Close any Utilities YAN Chao-Gan 091215.
    theFig =findobj(allchild(0),'flat','Tag','figIC');
    if ~isempty(theFig) && rest_misc( 'ForceCheckExistFigure' , theFig),
        delete(theFig);
    end
    
    %Close any Utilities YAN Chao-Gan 091215.
    theFig =findobj(allchild(0),'flat','Tag','figCSMain');
    if ~isempty(theFig) && rest_misc( 'ForceCheckExistFigure' , theFig),
        delete(theFig);
    end
    
    %Close any Utilities YAN Chao-Gan 091215.
    theFig =findobj(allchild(0),'flat','Tag','rest_ExtractROITC_gui');
    if ~isempty(theFig) && rest_misc( 'ForceCheckExistFigure' , theFig),
        delete(theFig);
    end
    
    %Close any Utilities YAN Chao-Gan 091215.
    theFig =findobj(allchild(0),'flat','Tag','rest_ResliceImage_gui');
    if ~isempty(theFig) && rest_misc( 'ForceCheckExistFigure' , theFig),
        delete(theFig);
    end
    
    %Close any Utilities YAN Chao-Gan 091215.
    theFig =findobj(allchild(0),'flat','Tag','rest_Nii2NiftiPairs_gui');
    if ~isempty(theFig) && rest_misc( 'ForceCheckExistFigure' , theFig),
        delete(theFig);
    end
    
    %Close any Utilities YAN Chao-Gan 091215.
    theFig =findobj(allchild(0),'flat','Tag','rest_DicomSorter_gui');
    if ~isempty(theFig) && rest_misc( 'ForceCheckExistFigure' , theFig),
        delete(theFig);
    end
    
    %Close any Utilities YAN Chao-Gan 100201.
    theFig =findobj(allchild(0),'flat','Tag','figGCAMain');
    if ~isempty(theFig) && rest_misc( 'ForceCheckExistFigure' , theFig),
        delete(theFig);
    end
    
    theFig =findobj(allchild(0),'flat','Tag','figANCOVA1');
    if ~isempty(theFig) && rest_misc( 'ForceCheckExistFigure' , theFig),
        delete(theFig);
    end
    
    theFig =findobj(allchild(0),'flat','Tag','figTTest1');
    if ~isempty(theFig) && rest_misc( 'ForceCheckExistFigure' , theFig),
        delete(theFig);
    end
    
    theFig =findobj(allchild(0),'flat','Tag','figTTest2');
    if ~isempty(theFig) && rest_misc( 'ForceCheckExistFigure' , theFig),
        delete(theFig);
    end
    
    theFig =findobj(allchild(0),'flat','Tag','figttestpaired');
    if ~isempty(theFig) && rest_misc( 'ForceCheckExistFigure' , theFig),
        delete(theFig);
    end
    
    theFig =findobj(allchild(0),'flat','Tag','figStatisticalAnalysis');
    if ~isempty(theFig) && rest_misc( 'ForceCheckExistFigure' , theFig),
        delete(theFig);
    end
    
    theFig =findobj(allchild(0),'flat','Tag','figCorrelationAnalysis');
    if ~isempty(theFig) && rest_misc( 'ForceCheckExistFigure' , theFig),
        delete(theFig);
    end
 
	%Clear mem
	rest_misc('UnlockRestFiles');
	clear all
	
	%Clear temp files
	rest_misc( 'ClearTempFiles');
	
	
function StartReHo()
	theFig =findobj(allchild(0),'flat','Tag','figRehoMain');
	if ~isempty(theFig) && rest_misc( 'ForceCheckExistFigure' , theFig),
		figure(theFig);
	else
		reho_gui;
	end
	
	
function StartALFF()
	theFig =findobj(allchild(0),'flat','Tag','figAlffMain');
	if ~isempty(theFig) && rest_misc( 'ForceCheckExistFigure' , theFig),
		figure(theFig);
	else
		alff_gui;
    end
function Utilities()
    theFig =findobj(allchild(0),'flat','Tag','figUtilities');
	if ~isempty(theFig) && rest_misc( 'ForceCheckExistFigure' , theFig),
		figure(theFig);
	else
		rest_Utilities_gui;
    end

function StartfALFF()
     theFig =findobj(allchild(0),'flat','Tag','figfAlffMain');
     if ~isempty(theFig) && rest_misc( 'ForceCheckExistFigure' , theFig),
        figure(theFig);
     else
        f_alff_gui;
     end
    
function StartFunctionalConnectivity()
	theFig =findobj(allchild(0),'flat','Tag','figFCMain');
	if ~isempty(theFig) && rest_misc( 'ForceCheckExistFigure' , theFig),
		figure(theFig);
	else
		fc_gui;
	end
	
function MailToZang()
	web('mailto:zangyf@gmail.com');
function MailToSong()
	web('mailto:dawnwei.song@gmail.com');
	
function OpenHelp()
	web('www.restfmri.net');
function rest_Statistic()
rest_Statistic_gui;
function rest_GCA()
rest_gca_gui;

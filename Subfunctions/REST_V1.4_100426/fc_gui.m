function varargout = fc_gui(varargin)
%Functional Connectivity GUI by Xiaowei Song
%-----------------------------------------------------------
%	Copyright(c) 2007~2010
%	State Key Laboratory of Cognitive Neuroscience and Learning in Beijing Normal University
%	Written by Xiao-Wei Song 
%	http://resting-fmri.sourceforge.net
% $mail     =dawnwei.song@gmail.com
% $Version =1.2
% $Date    =20080808
%-----------------------------------------------------------
% 	<a href="Dawnwei.Song@gmail.com">Mail to Author</a>: Xiaowei Song
%	Version=1.2;
%	Release=20080808;
% Modified by GUIDE v2.5 02-Oct-2007 10:20:30
% Revised by YAN Chao-Gan 080808, in order to process multiple subjects with different covaribles in batch mode.
% Revised by YAN Chao-Gan 080903, in order to fix the bug that with no Covariables.
% Revised by YAN Chao-Gan 091104, in order to process multiple subjects with different seed time courses (.txt) in batch mode.
% Last revised by YAN Chao-Gan 100130, fixed the bug in ROI-wise functional connectivity calculation.

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @fc_gui_OpeningFcn, ...
                   'gui_OutputFcn',  @fc_gui_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before fc_gui is made visible.
function fc_gui_OpeningFcn(hObject, eventdata, handles, varargin)			
	%Matlab -Linux compatible, Initialize controls' default properties, dawnsong , 20070507
	InitControlProperties(hObject, handles);
	%Matlab -v6 compatible, create some frames instead of panels
	InitFrames(hObject,handles);
		
    [pathstr, name, ext, versn] = fileparts(mfilename('fullpath'));	
	%the {hdr/img} directories to be processed , count of volumns(i.e. time series' point number) corresponding to the dir		
    handles.Cfg.DataDirs ={}; %{[pathstr '\SampleData'], 10} ;	
    handles.Cfg.MaskFile = 'Default';                 %the  user defined mask file    	
	handles.Cfg.OutputDir =pwd;			    % pwd is the default dir for functional connectivity map result
	handles.Cfg.WantFisherZMap ='Yes';		%Calcute the mean functional connectivity map default
	handles.Cfg.ROIList ='';				% ROI Definition file, a common mask, 20070830
	
	%Covariables definition
	handles.Covariables.ort_file ='';
	handles.Covariables.polort =1;
	
	handles.Filter.BandLow  =0.01;			%Config about Band pass filter, dawnsong 20070429
	handles.Filter.BandHigh =0.08;
	handles.Filter.UseFilter   	='No';
	handles.Filter.Retrend		='Yes';		% by default, always re-trend after linear filtering after removing linear trend	20070614, bug fixes
	handles.Filter.SamplePeriod=2;			%by default, set TR=2s
	handles.Detrend.BeforeFilter ='No';% ZangYF, 20070530 decide
	handles.Detrend.AfterFilter  ='No';% ZangYF, 20070530 decide
		
	handles.Log.SelfPath =pathstr;			% 20070507, dawnsong, just for writing log to file for further investigation
	handles.Log.Filename =GetLogFilename('','');
	%Performance record, use elapsed time to describe it, 20070507
	handles.Performance =0;
	
    guidata(hObject, handles);
    UpdateDisplay(handles);
	movegui(handles.figFCMain, 'center');
	set(handles.figFCMain,'Name','Functional Connectivity');
	
    % Choose default command line output for fc_gui
    handles.output = hObject;	    
    guidata(hObject, handles);% Update handles structure

	% UIWAIT makes fc_gui wait for user response (see UIRESUME)
	% uiwait(handles.figFCMain);

% --- Outputs from this function are returned to the command line.
function varargout = fc_gui_OutputFcn(hObject, eventdata, handles) 
	% Get default command line output from handles structure
	varargout{1} = handles.output;




function edtDataDirectory_Callback(hObject, eventdata, handles)
	theDir =get(hObject, 'String');    
	SetDataDir(hObject, theDir,handles);

function edtDataDirectory_CreateFcn(hObject, eventdata, handles)
	if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
	    set(hObject,'BackgroundColor','white');
	end


function btnSelectDataDir_Callback(hObject, eventdata, handles)
	if size(handles.Cfg.DataDirs, 1)>0
		theDir =handles.Cfg.DataDirs{1,1};
	else
		theDir =pwd;
	end
    theDir =uigetdir(theDir, 'Please select the data directory to compute functional connectivity map: ');
	if ischar(theDir),
		SetDataDir(hObject, theDir,handles);	
	end

function RecursiveAddDataDir(hObject, eventdata, handles)
	if prod(size(handles.Cfg.DataDirs))>0 && size(handles.Cfg.DataDirs, 1)>0,
		theDir =handles.Cfg.DataDirs{1,1};
	else
		theDir =pwd;
	end
	theDir =uigetdir(theDir, 'Please select the parent data directory of many sub-folders containing EPI data to compute functional connectivity map: ');
	if ischar(theDir),
		%Make the warning dlg off! 20071201
		setappdata(0, 'FC_DoingRecursiveDir', 1);
		theOldColor =get(handles.listDataDirs, 'BackgroundColor');
		set(handles.listDataDirs, 'BackgroundColor', [ 0.7373    0.9804    0.4784]);
		try
			rest_RecursiveDir(theDir, 'fc_gui(''SetDataDir'',gcbo, ''%s'', guidata(gcbo) )');
		catch
			rest_misc( 'DisplayLastException');
		end	
		set(handles.listDataDirs, 'BackgroundColor', theOldColor);
		rmappdata(0, 'FC_DoingRecursiveDir');
	end	
	
function SetDataDir(hObject, ADir,handles)	
	if ~ischar(ADir), return; end	
	theOldWarnings =warning('off', 'all');
    % if (~isequal(ADir , 0)) &&( (size(handles.Cfg.DataDirs, 1)==0)||(0==seqmatch({ADir} ,handles.Cfg.DataDirs( : , 1) ) ) )
	if rest_misc('GetMatlabVersion')>=7.3,
		ADir =strtrim(ADir);
	end	
	if (~isequal(ADir , 0)) &&( (size(handles.Cfg.DataDirs, 1)==0)||(0==length(strmatch(ADir,handles.Cfg.DataDirs( : , 1),'exact' ) ) ))
        handles.Cfg.DataDirs =[ {ADir , 0}; handles.Cfg.DataDirs];%update the dir    
		theVolumnCount =CheckDataDir(handles.Cfg.DataDirs{1,1} );	
		if (theVolumnCount<=0),
			if isappdata(0, 'FC_DoingRecursiveDir') && getappdata(0, 'FC_DoingRecursiveDir'), 
			else
				fprintf('There is no data or non-data files in this directory:\n%s\nPlease re-select\n\n', ADir);
				errordlg( sprintf('There is no data or non-data files in this directory:\n\n%s\n\nPlease re-select', handles.Cfg.DataDirs{1,1} )); 
			end
			handles.Cfg.DataDirs(1,:)=[];
			if size(handles.Cfg.DataDirs, 1)==0
				handles.Cfg.DataDirs=[];
			end	%handles.Cfg.DataDirs = handles.Cfg.DataDirs( 2:end, :);%update the dir        
		else
			handles.Cfg.DataDirs{1,2} =theVolumnCount;
		end	
	
        guidata(hObject, handles);
        UpdateDisplay(handles);
    end
	warning(theOldWarnings);
	
%% Update All the uiControls' display on the GUI
function UpdateDisplay(handles)
	if size(handles.Cfg.DataDirs,1)>0	
		theOldIndex =get(handles.listDataDirs, 'Value');
		%set(handles.listDataDirs, 'String',  handles.Cfg.DataDirs(: ,1) , 'Value', 1);	
		set(handles.listDataDirs, 'String',  GetInputDirDisplayList(handles) , 'Value', 1);
		theCount =size(handles.Cfg.DataDirs,1);
		if (theOldIndex>0) && (theOldIndex<= theCount)
			set(handles.listDataDirs, 'Value', theOldIndex);
		end
		set(handles.edtDataDirectory,'String', handles.Cfg.DataDirs{1,1});
		theResultFilename=get(handles.edtPrefix, 'String');
		theResultFilename=[theResultFilename '_' GetDirName(handles.Cfg.DataDirs{1,1})];
		set(handles.txtResultFilename, 'String', [theResultFilename  '.{hdr/img}']);
	else
		set(handles.listDataDirs, 'String', '' , 'Value', 0);
		set(handles.txtResultFilename, 'String', 'Result: Prefix_DirectoryName.{hdr/img}');
	end
	% set(handles.pnlParametersInput,'Title', ...			%show the first dir's Volumn count in the panel's title	
		 % ['Input Parameters (Volumn count= '...
		  % num2str( cell2mat(handles.Cfg.DataDirs(1,2)) )...
		  % ' in 'handles.Cfg.DataDirs(1,1) ' )']);
	set(handles.edtOutputDir ,'String', handles.Cfg.OutputDir);	
    if isequal(handles.Cfg.MaskFile, '')
        set(handles.edtMaskfile, 'String', 'Don''t use any Mask');
    else
        set(handles.edtMaskfile, 'String', handles.Cfg.MaskFile);    
    end
	
	%Set detrend dawnsong 20070820
	if strcmpi(handles.Detrend.BeforeFilter, 'Yes')
		%Update filter and detrend button's state according to Option: detrend/Filter 20070820
		set(handles.btnDetrend, 'Enable', 'on');
	else
		%Update filter and detrend button's state according to Option: detrend/Filter 20070820
		set(handles.btnDetrend, 'Enable', 'off');
	end
	%Set filter, dawnsong 20070430
	if strcmpi(handles.Filter.UseFilter, 'Yes')
		set(handles.ckboxFilter, 'Value', 1);		
		set(handles.ckboxRetrend, 'Enable', 'on');		
		set(handles.edtBandLow, 'Enable', 'on', 'String', num2str(handles.Filter.BandLow));
		set(handles.edtBandHigh, 'Enable', 'on', 'String', num2str(handles.Filter.BandHigh));
		set(handles.edtSamplePeriod, 'Enable', 'on', 'String', num2str(handles.Filter.SamplePeriod));
		%Update filter and detrend button's state according to Option: detrend/Filter 20070820
		set(handles.btnBandPass, 'Enable', 'on');	
	else
		set(handles.ckboxFilter, 'Value', 0);		
		set(handles.ckboxRetrend,'Enable', 'off');
		set(handles.edtBandLow, 'Enable', 'off', 'String', num2str(handles.Filter.BandLow));
		set(handles.edtBandHigh, 'Enable', 'off', 'String', num2str(handles.Filter.BandHigh));
		set(handles.edtSamplePeriod, 'Enable', 'off', 'String', num2str(handles.Filter.SamplePeriod));
		%Update filter and detrend button's state according to Option: detrend/Filter 20070820
		set(handles.btnBandPass, 'Enable', 'off');
	end
	
	%Set mean calculation, dawnsong 20070504	
	set(handles.ckboxFisherZ, 'Value', strcmpi(handles.Cfg.WantFisherZMap, 'Yes'));		
	
	% Set detrend option
	set(handles.ckboxRemoveTrendBefore, 'Value', strcmpi(handles.Detrend.BeforeFilter, 'Yes'));
	set(handles.ckboxRemoveTrendAfter, 'Value', strcmpi(handles.Detrend.AfterFilter, 'Yes'));	
		
	%Indicate which ROI type user has selected
	if isempty(handles.Cfg.ROIList) || prod(size(handles.Cfg.ROIList)) ==0,
		%User has not selected any ROI
		set(handles.btnROIVoxelWise, 'ForegroundColor', 'red', 'FontWeight', 'normal');
		set(handles.btnROIRegionWise, 'ForegroundColor', 'red', 'FontWeight', 'normal');		
	else
		% [pathstr, name, ext, versn] = fileparts(handles.Cfg.ROIFile);
		% if strcmpi(ext, 'rest_roi'),		
		if  ~iscell(handles.Cfg.ROIList) || 0 ...			
			% ( size(handles.Cfg.ROIList,1)==1 && ~isspace(handles.Cfg.ROIList) ),
			%Single Region for Voxel Wise type ROI			
			set(handles.btnROIVoxelWise, 'ForegroundColor', 'red', 'FontWeight', 'bold');
			set(handles.btnROIRegionWise, 'ForegroundColor', 'red', 'FontWeight', 'normal');		
			
		elseif size(handles.Cfg.ROIList,1)>=1,			
			%Region Wise type ROI series
			set(handles.btnROIVoxelWise, 'ForegroundColor', 'red', 'FontWeight', 'normal');
			set(handles.btnROIRegionWise, 'ForegroundColor', 'red', 'FontWeight', 'bold');		
		end
	end
	
	%Set covariables's definition
	set(handles.edtCovariableFile, 'String', handles.Covariables.ort_file);
	
	
%% check the Data dir to make sure that there are only {hdr,img}
function Result=GetInputDirDisplayList(handles)
	Result ={};
	for x=size(handles.Cfg.DataDirs, 1):-1:1
		Result =[{sprintf('%d# %s',handles.Cfg.DataDirs{x, 2},handles.Cfg.DataDirs{x, 1})} ;Result];
	end

% in this dir
function [nVolumn]=CheckDataDir(ADataDir)
    theFilenames = dir(ADataDir);
	theHdrFiles=dir(fullfile(ADataDir,'*.hdr'));
	theImgFiles=dir(fullfile(ADataDir,'*.img'));
	% if (length(theFilenames)-length(theHdrFiles)-length(theImgFiles))>2
		% nVolumn =-1;
		% errordlg(sprintf(['There should not be any file other than *.{hdr,img} .' ...
					% 'Please re-examin the DataDir\n\n%s '] ...
					% , ADataDir)); 
		% return;
	% end
	if ~length(theHdrFiles)==length(theImgFiles)
		nVolumn =-1;
		fprintf('%s, *.{hdr,img} should be pairwise. Please re-examin them.\n', ADataDir);
		errordlg('*.{hdr,img} should be pairwise. Please re-examin them.'); 
		return;
	end		
    count = 3; nVolumn = 0;		
	for count = 3:size(struct2cell(theFilenames),2)				
		if	(length(theFilenames(count).name)>4) && ...
			strcmpi(theFilenames(count).name(end-3:end) , '.hdr') 
			if strcmpi(theFilenames(count).name(1:end-4) ...                %hdr
					        , theFilenames(count+1).name(1:end-4) )     %img
				nVolumn = nVolumn + 1;  
			else
				%error('*.{hdr,img} should be pairwise. Please re-examin them.'); 
				nVolumn =-1;
				fprintf('%s, *.{hdr,img} should be pairwise. Please re-examin them.\n', ADataDir);	
				errordlg('*.{hdr,img} should be pairwise. Please re-examin them.'); 
				break;
			end
		end			
	end
 	

	


function edtMaskfile_Callback(hObject, eventdata, handles)
	theMaskfile =get(hObject, 'String');
	if rest_misc('GetMatlabVersion')>=7.3,
		theMaskfile =strtrim(theMaskfile);
	end	
	if exist(theMaskfile, 'file')
		handles.Cfg.MaskFile =theMaskfile;
		guidata(hObject, handles);
	else
		errordlg(sprintf('The mask file "%s" does not exist!\n Please re-check it.', theMaskfile));
	end

function edtMaskfile_CreateFcn(hObject, eventdata, handles)
	if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
	    set(hObject,'BackgroundColor','white');
	end


function btnSelectMask_Callback(hObject, eventdata, handles)
	[filename, pathname] = uigetfile({'*.img;*.mat', 'All Mask files (*.img; *.mat)'; ...
												'*.mat','MAT masks (*.mat)'; ...
												'*.img', 'ANALYZE or NIFTI masks(*.img)'}, ...
												'Pick a user''s  mask');
    if ~(filename==0)
        handles.Cfg.MaskFile =[pathname filename];
        guidata(hObject,handles);
    elseif ~( exist(handles.Cfg.MaskFile, 'file')==2)
        set(handles.rbtnDefaultMask, 'Value',[1]);        
        set(handles.rbtnUserMask, 'Value',[0]); 
		set(handles.edtMaskfile, 'Enable','off');
		set(handles.btnSelectMask, 'Enable','off');			
		handles.Cfg.MaskFile ='Default';
		guidata(hObject, handles);        
    end    
    UpdateDisplay(handles);


	
	

function rbtnDefaultMask_Callback(hObject, eventdata, handles)
	set(handles.edtMaskfile, 'Enable','off', 'String','Use Default Mask');
	set(handles.btnSelectMask, 'Enable','off');	
	drawnow;
    handles.Cfg.MaskFile ='Default';
	guidata(hObject, handles);
    set(handles.rbtnDefaultMask,'Value',1);
	set(handles.rbtnNullMask,'Value',0);
	set(handles.rbtnUserMask,'Value',0);

function rbtnUserMask_Callback(hObject, eventdata, handles)
	set(handles.edtMaskfile,'Enable','on', 'String',handles.Cfg.MaskFile);
	set(handles.btnSelectMask, 'Enable','on');
	set(handles.rbtnDefaultMask,'Value',0);
	set(handles.rbtnNullMask,'Value',0);
	set(handles.rbtnUserMask,'Value',1);
    drawnow;
	
function rbtnNullMask_Callback(hObject, eventdata, handles)
	set(handles.edtMaskfile, 'Enable','off', 'String','Don''t use any Mask');
	set(handles.btnSelectMask, 'Enable','off');
	drawnow;
	handles.Cfg.MaskFile ='';
	guidata(hObject, handles);
    set(handles.rbtnDefaultMask,'Value',0);
	set(handles.rbtnNullMask,'Value',1);
	set(handles.rbtnUserMask,'Value',0);



	

function listDataDirs_Callback(hObject, eventdata, handles)
	theIndex =get(hObject, 'Value');
	if isempty(theIndex) || theIndex<1,
        msgbox(sprintf('Nothing added.\n\nYou must add some diretories containing only paired {hdr/img} files first'), ...
					'REST' ,'help');
		return;
    end	
	
	if strcmp(get(handles.figFCMain, 'SelectionType'), 'open') %when double click 
	    msgbox(sprintf('%s \t\nhas\t %d\t volumes\n\nTotal: %d Data Directories' , ... 
					handles.Cfg.DataDirs{theIndex, 1} , ...
	                handles.Cfg.DataDirs{theIndex, 2} , ...
					size(handles.Cfg.DataDirs,1)), ...
					'Volume count in selected dir' ,'help');
	end

function listDataDirs_KeyPressFcn(hObject, eventdata, handles)
	%Delete the selected item when 'Del' is pressed
    key =get(handles.figFCMain, 'currentkey');
    if seqmatch({key},{'delete', 'backspace'})
        DeleteSelectedDataDir(hObject, eventdata,handles);
    end   
	
function DeleteSelectedDataDir(hObject, eventdata, handles)	
	theIndex =get(handles.listDataDirs, 'Value');
	if prod(size(handles.Cfg.DataDirs))==0 ...
		|| size(handles.Cfg.DataDirs, 1)==0 ...
		|| theIndex>size(handles.Cfg.DataDirs, 1),
		return;
	end
	theDir     =handles.Cfg.DataDirs{theIndex, 1};
	theVolumnCount=handles.Cfg.DataDirs{theIndex, 2};
	tmpMsg=sprintf('Delete\n\n "%s" \nVolumn Count :%d ?', theDir, theVolumnCount);
	if strcmp(questdlg(tmpMsg, 'Delete confirmation'), 'Yes')
		if theIndex>1,
			set(handles.listDataDirs, 'Value', theIndex-1);
		end
		handles.Cfg.DataDirs(theIndex, :)=[];
		if size(handles.Cfg.DataDirs, 1)==0
			handles.Cfg.DataDirs={};
		end	
		guidata(hObject, handles);
		UpdateDisplay(handles);
	end
	
function ClearDataDirectories(hObject, eventdata, handles)	
	if prod(size(handles.Cfg.DataDirs))==0 ...
		|| size(handles.Cfg.DataDirs, 1)==0,		
		return;
	end
	tmpMsg=sprintf('Attention!\n\n\nDelete all data directories?');
	if strcmpi(questdlg(tmpMsg, 'Clear confirmation'), 'Yes'),		
		handles.Cfg.DataDirs(:)=[];
		if prod(size(handles.Cfg.DataDirs))==0,
			handles.Cfg.DataDirs={};
		end	
		guidata(hObject, handles);
		UpdateDisplay(handles);
	end	
	
	
function listDataDirs_CreateFcn(hObject, eventdata, handles)
	if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
	    set(hObject,'BackgroundColor','white');
	end

	
function edtPrefix_Callback(hObject, eventdata, handles)
%nothing need to do, because I get the prefix when I need. Look at line 229 "thePrefix =get(handles.edtPrefix, 'String');"

function edtPrefix_CreateFcn(hObject, eventdata, handles)
	if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
	    set(hObject,'BackgroundColor','white');
	end


	
	
function edtOutputDir_Callback(hObject, eventdata, handles)
	theDir =get(hObject, 'String');	
	SetOutputDir(hObject,handles, theDir);

function edtOutputDir_CreateFcn(hObject, eventdata, handles)
	if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
	    set(hObject,'BackgroundColor','white');
	end


function btnSelectOutputDir_Callback(hObject, eventdata, handles)
	theDir =handles.Cfg.OutputDir;
	theDir =uigetdir(theDir, 'Please select the data directory to compute functional connectivity map: ');
	if ~isequal(theDir, 0)
		SetOutputDir(hObject,handles, theDir);	
	end	
	
function SetOutputDir(hObject, handles, ADir)
	if 7==exist(ADir,'dir')
		handles.Cfg.OutputDir =ADir;
		guidata(hObject, handles);
	    UpdateDisplay(handles);
	end

function Result=GetDirName(ADir)
	if isempty(ADir), Result=ADir; return; end
	theDir =ADir;
	if strcmp(theDir(end),filesep)==1
		theDir=theDir(1:end-1);
	end	
	[tmp,Result]=fileparts(theDir);

	
function ckboxFilter_Callback(hObject, eventdata, handles)
	if get(hObject,'Value')
		handles.Filter.UseFilter ='Yes';
	else	
		handles.Filter.UseFilter ='No';
	end	
	guidata(hObject, handles);
	UpdateDisplay(handles);

function edtBandLow_Callback(hObject, eventdata, handles)
	handles.Filter.BandLow =str2double(get(hObject,'String'));
	guidata(hObject, handles);

function edtBandLow_CreateFcn(hObject, eventdata, handles)
	if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
	    set(hObject,'BackgroundColor','white');
	end


function edtBandHigh_Callback(hObject, eventdata, handles)
	handles.Filter.BandHigh =str2double(get(hObject,'String'));
	guidata(hObject, handles);

function edtBandHigh_CreateFcn(hObject, eventdata, handles)
	if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
	    set(hObject,'BackgroundColor','white');
	end



function ckboxRetrend_Callback(hObject, eventdata, handles)
	if get(hObject,'Value')
		handles.Filter.Retrend ='Yes';
	else	
		handles.Filter.Retrend ='No';
	end	
	guidata(hObject, handles);
	UpdateDisplay(handles);

function edtSamplePeriod_Callback(hObject, eventdata, handles)
	handles.Filter.SamplePeriod =str2double(get(hObject,'String'));
	guidata(hObject, handles);

function edtSamplePeriod_CreateFcn(hObject, eventdata, handles)
	if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
	    set(hObject,'BackgroundColor','white');
	end

	
function ckboxFisherZ_Callback(hObject, eventdata, handles)
	if get(hObject,'Value')
		handles.Cfg.WantFisherZMap ='Yes';
	else	
		handles.Cfg.WantFisherZMap ='No';
	end
	guidata(hObject, handles);
	UpdateDisplay(handles);
	
function btnFisherZ_Callback(hObject, eventdata, handles)
	theOldColor=get(hObject,'BackgroundColor');		
	set(hObject,'Enable','off', 'BackgroundColor', 'red');
	drawnow;
	try
		[filename, pathname] = uigetfile({'*.img', 'functional connectivity files (*.img)'}, ...
													'Pick one functional connectivity map');
	    if (filename~=0)% not canceled
			if strcmpi(filename(end-3:end), '.img')%revise filename to remove extension		
				filename = filename(1:end-4);
			end
			if ~strcmpi(pathname(end), filesep)%revise filename to remove extension		
				pathname = [pathname filesep];
			end
			theOrigFCMap =[pathname filename];
			theFisherZMap =[pathname 'z' filename];
			theMaskFile =handles.Cfg.MaskFile;
			rest_Corr2FisherZ(theOrigFCMap, theFisherZMap, theMaskFile);
			
			msgbox(sprintf('functional connectivity brain "%s.{hdr/img}" \nhas been transformed to Fisher Z-score map in the specified mask.\t\n\nSave to "%s.{hdr/img}"\n' , ... 
					theOrigFCMap, theFisherZMap), ...				
					'Fisher Z-score transformation within mask successfully' ,'help');
	    end    
	catch
		rest_misc( 'DisplayLastException');
	end
	set(hObject,'Enable','on', 'BackgroundColor', theOldColor);
	drawnow;
	
function btnBandPass_Callback(hObject, eventdata, handles)
	theOldColor=get(hObject,'BackgroundColor');		
	set(hObject,'Enable','off', 'BackgroundColor', 'red');
	drawnow;
	try
	    %Band pass filter
		if strcmpi(handles.Filter.UseFilter, 'Yes')
			BandPass(hObject, handles);
			msgbox('Ideal Band Pass filter Over.',...
					'Filter successfully' ,'help');
		else
			errordlg(sprintf('You didn''t select option "Band Pass". \n\nPlease slect first.'));
		end
		UpdateDisplay(handles);	
	catch
		rest_misc( 'DisplayLastException');
	end
	rest_waitbar;
	set(hObject,'Enable','on', 'BackgroundColor', theOldColor);
	drawnow;

function InitFrames(hObject,handles)
	offsetY =83+50; %dawnsong, 20070504, add for the divide by the mask mean, the Y of Edit "OutPut Diectory"
	%dawnsong, 20070905, add Covariable for functional connectivities
	
	% for Matlab 6.5 compatible, draw a panel
	uicontrol(handles.figFCMain, 'Style','Frame','Position',[2 offsetY+92 433 1]);%bottom
	uicontrol(handles.figFCMain, 'Style','Frame','Position',[2 offsetY+136 433 1]);%Covariables horz line
	%uicontrol(handles.figFCMain, 'Style','Frame','Position',[90 offsetY+202 343 1]);%Mask Bottom line
	uicontrol(handles.figFCMain, 'Style','Frame','Position',[2 offsetY+227 433 1]);%Middle, mask top line
	uicontrol(handles.figFCMain, 'Style','Frame','Position',[90 offsetY+137 1 90]);%Middle, mask left line	
	uicontrol(handles.figFCMain, 'Style','Frame','Position',[2 offsetY+92 1 290]);	%Input left line
	uicontrol(handles.figFCMain, 'Style','Frame','Position',[435 offsetY+92 1 290]);%Input right line	
	uicontrol(handles.figFCMain, 'Style','Frame','Position',[2 offsetY+382 433 1]);	%Input top line
	uicontrol(handles.figFCMain,'Style','Text','Position',[142 offsetY+378 180 14],...
		'String','Input Parameters');
	uicontrol(handles.figFCMain,'Style','Text','Position',[208 offsetY+222 40 14],...
		'String','Mask');		
	uicontrol(handles.figFCMain,'Style','Text','Position',[20 offsetY+222 50 14],...
		'String','Set ROI', 'FontWeight', 'normal','FontSize', 10,'ForegroundColor', 'red');			
	
			
	uicontrol(handles.figFCMain, 'Style','Frame','Position',[2 offsetY+393 433 1]);	
	uicontrol(handles.figFCMain, 'Style','Frame','Position',[435 offsetY+393 1 50]);	
	uicontrol(handles.figFCMain, 'Style','Frame','Position',[2 offsetY+393 1 50]);	
	uicontrol(handles.figFCMain, 'Style','Frame','Position',[2 offsetY+443 433 1]);	
	uicontrol(handles.figFCMain,'Style','Text','Position',[142 offsetY+438 180 14],...
		'String','Option: Ideal Band Pass Filter');
	
	uicontrol(handles.figFCMain, 'Style','Frame','Position',[2 offsetY+458 433 1]);	
	uicontrol(handles.figFCMain, 'Style','Frame','Position',[435 offsetY+458 1 50]);	
	uicontrol(handles.figFCMain, 'Style','Frame','Position',[2 offsetY+458 1 50]);	
	uicontrol(handles.figFCMain, 'Style','Frame','Position',[2 offsetY+508 433 1]);	
	uicontrol(handles.figFCMain,'Style','Text','Position',[142 offsetY+498 180 14],...
		'String','Option: Remove Linear Trend');
	
	%I insert the area for covariables between Input and Output areas.
	offsetY = offsetY -50;
	uicontrol(handles.figFCMain, 'Style','Frame','Position',[2 offsetY+94 433 1]);	
	uicontrol(handles.figFCMain, 'Style','Frame','Position',[2 offsetY-8 433 1]);	
	uicontrol(handles.figFCMain, 'Style','Frame','Position',[2 offsetY-8 1 102]);	
	uicontrol(handles.figFCMain, 'Style','Frame','Position',[435 offsetY-8 1 102]);	
	uicontrol(handles.figFCMain,'Style','Text','Position',[142 offsetY+88 180 14],...
		'String','Output Parameters');
	
	%20070506, Add manual operation button groups like SPM
	uicontrol(handles.figFCMain, 'Style','Frame','Position',[2 offsetY-25 433 1]);	
	uicontrol(handles.figFCMain,'Style','Text','Position',[152 offsetY-30 140 14],...
		'String','Manual Operations');
	

function InitControlProperties(hObject, handles)
	%for Linux compatible 20070507 dawnsong
	% --- FIGURE -------------------------------------
	set(handles.figFCMain,...
		'Units', 'pixels', ...
		'Position', [20 5 440 645], ...
		'Name', 'fc_gui', ...
		'MenuBar', 'none', ...
		'NumberTitle', 'off', ...
		'Color', get(0,'DefaultUicontrolBackgroundColor'));

	% --- STATIC TEXTS -------------------------------------
	set(handles.txtLogo,	...		
		'Style', 'text', ...
		'Units', 'pixels', ...
		'Position', [16 186 260 30], ...
		'FontSize', 16, ...
		'FontWeight', 'bold', ...
		'String', 'Functional Connectivity');
	set(handles.txtLongName,	...		
		'Style', 'text', ...
		'Units', 'pixels', ...
		'Position', [10 400 65 30], ...
		'FontSize', 10, ... 
		'FontWeight', 'bold', ...				
		'Enable', 'on', ...
		'Visible', 'off', ...
		'String', sprintf('ROI Definition'));
		
	set(handles.txtOutputDir,	...		
		'Style', 'text', ...
		'Units', 'pixels', ...
		'Position', [8 109 80 21], ...
		'String', 'Directory:');

	set(handles.txtInputDir,	...		
		'Style', 'text', ...
		'Units', 'pixels', ...
		'Position', [7 370 80 21], ...
		'String', 'Data Directory:');

	set(handles.txtPrefix,	...		
		'Style', 'text', ...
		'Units', 'pixels', ...
		'Position', [9 140 80 21], ...
		'String', 'Prefix:');

	set(handles.txtResultFilename,	...		
		'Style', 'text', ...
		'Units', 'pixels', ...
		'Position', [227 148 200 16], ...
		'HorizontalAlignment','left'         , ...
		'String', 'Result: Prefix_DirectoryName.{hdr/img}');

	set(handles.txtBandSep,	...		
		'Style', 'text', ...
		'Units', 'pixels', ...
		'Position', [146 516 25 51], ...
		'FontSize', 28, ...
		'String', '~');

	set(handles.txtTR,	...		
		'Style', 'text', ...
		'Units', 'pixels', ...
		'Position', [230 530 40 16], ...
		'String', 'TR: (s)');
		
	% --- PUSHBUTTONS -------------------------------------
	set(handles.btnSelectOutputDir,	...		
		'Style', 'pushbutton', ...
		'Units', 'pixels', ...
		'Position', [396 107 30 25], ...
		'FontSize', 18, ...
		'String', '...');

	set(handles.btnSelectDataDir,	...		
		'Style', 'pushbutton', ...
		'Units', 'pixels', ...
		'Position', [396 372 30 25], ...
		'FontSize', 18, ...
		'String', '...', ...
		'CData', zeros(1,0));

	set(handles.btnSelectMask,	...		
		'Style', 'pushbutton', ...
		'Units', 'pixels', ...
		'Position', [396 275 30 25], ...
		'FontSize', 18, ...
		'String', '...', ...
		'Enable', 'off', ...
		'CData', zeros(1,0));

	set(handles.btnComputeFC,	...		
		'Style', 'pushbutton', ...
		'Units', 'pixels', ...
		'Position', [320 186 107 33], ...
		'FontSize', 12, ...
		'FontWeight', 'bold', ...
		'String', 'Do all');

		
	set(handles.btnDetrend , ...
		'Style', 'pushbutton', ...
		'Units', 'pixels', ...
		'Position', [337 593 90 25], ...
		'FontSize', 10, ...
		'String', 'Detrend');
	set(handles.btnBandPass , ...
		'Style', 'pushbutton', ...
		'Units', 'pixels', ...
		'Position', [337 530 90 25], ...
		'FontSize', 10, ...
		'String', 'Filter');
	
		
	set(handles.btnROIVoxelWise , ...
		'Style', 'pushbutton', ...
		'Units', 'pixels', ...
		'Position', [5 315 85 25], ...%'FontSize', 10, ...		
		'ForegroundColor', 'red', ...	
		'TooltipString', 'Functional Connectivity with whole brain', ...
		'String', 'Voxel wise');
	set(handles.btnROIRegionWise , ...
		'Style', 'pushbutton', ...
		'Units', 'pixels', ...
		'Position', [5 275 85 25], ... 		%'FontSize', 18, ... 
		'ForegroundColor', 'red', ...				
		'TooltipString', 'Functional Connectivity between defined regions', ...
		'String', 'ROI wise');	
		
	set(handles.btnCovariable,	...		%'Style', 'pushbutton', ...		
		'Style', 'text', ...	%20071103
		'Units', 'pixels', ...
		'Position', [5 234 85 25], ...
		'FontSize', 10, ...  %'FontWeight', 'bold', ...		
		'ForegroundColor', 'blue', ...
		'Visible', 'on', ...
		'String', 'Covariables:');
		
	set(handles.btnSelectCovariableFile , ...
		'Style', 'pushbutton', ...
		'Units', 'pixels', ...
		'Position', [396 234 30 25], ...
		'FontSize', 18, ...
		'ForegroundColor', 'blue', ...
		'String', '...');	
		
		
	set(handles.btnHelp,	...
		'Style', 'pushbutton', ...
		'Units', 'pixels', ...
		'Position', [10 10 90 33], ...
		'FontSize', 10, ...
		'String', 'Help');	
	set(handles.btnFisherZ,	...
		'Style', 'pushbutton', ...
		'Units', 'pixels', ...
		'Position', [110 10 90 33], ...
		'FontSize', 10, ...
		'String', 'Fisher Z');
	set(handles.btnSliceViewer,	...
		'Style', 'pushbutton', ...
		'Units', 'pixels', ...
		'Position', [210 10 90 33], ...
		'FontSize', 10, ...
		'String', 'Slice Viewer');	
	set(handles.btnWaveGraph,	...
		'Style', 'pushbutton', ...
		'Units', 'pixels', ...
		'Position', [314 10 110 33], ...
		'FontSize', 10, ...
		'String', 'Power Spectrum');
		
		
	% --- RADIO BUTTONS -------------------------------------
	set(handles.rbtnDefaultMask,	...		
		'Style', 'radiobutton', ...
		'Units', 'pixels', ...
		'Position', [110 335 158 16], ...
		'String', 'Default mask');

	set(handles.rbtnUserMask,	...		
		'Style', 'radiobutton', ...
		'Units', 'pixels', ...
		'Position', [110 305 148 16], ...
		'String', 'User-defined mask');

	set(handles.rbtnNullMask,	...		
		'Style', 'radiobutton', ...
		'Units', 'pixels', ...
		'Position', [277 335 82 16], ...
		'String', 'No mask');

	% --- CHECKBOXES -------------------------------------
	set(handles.ckboxFilter,	...		
		'Style', 'checkbox', ...
		'Units', 'pixels', ...
		'Position', [14 530 80 22], ...
		'String', 'Band (Hz)');

	set(handles.ckboxFisherZ,	...		
		'Style', 'checkbox', ...
		'Units', 'pixels', ...
		'Position', [12 82 430 19], ...
		'String', 'Fisher Z-score transformation within the mask (zPrefix_DirectoryName.{hdr/img})');

	set(handles.ckboxRetrend,	...		
		'Style', 'checkbox', ...
		'Units', 'pixels', ...
		'Position', [366 530 60 22], ...
		'Enable', 'Off', ...
		'String', 'Retrend');

	set(handles.ckboxRemoveTrendBefore, ...
		'Style', 'checkbox', ...
		'Units', 'pixels', ...
		'Position', [13 595 160 21],...
		'String', 'detrend');
	set(handles.ckboxRemoveTrendAfter, ...
		'Style', 'checkbox', ...
		'Units', 'pixels', ...
		'Position', [171 595 140 21],...
		'Visible', 'off', ...
		'String', 'detrend AFTER Filter');	
		
	% --- EDIT TEXTS -------------------------------------
	set(handles.edtOutputDir,	...		
		'Style', 'edit', ...
		'Units', 'pixels', ...
		'Position', [94 109 300 23], ...
		'BackgroundColor', [1 1 1], ...
		'String', 'Edit Text');

	set(handles.edtDataDirectory,	...		
		'Style', 'edit', ...
		'Units', 'pixels', ...
		'Position', [94 373 300 22], ...
		'BackgroundColor', [1 1 1], ...
		'String', '');

	set(handles.edtMaskfile,	...		
		'Style', 'edit', ...
		'Units', 'pixels', ...
		'Position', [94 275 300 23], ...
		'BackgroundColor', [1 1 1], ...
		'String', 'Default', ...
		'Enable', 'off');

	set(handles.edtPrefix,	...		
		'Style', 'edit', ...
		'Units', 'pixels', ...
		'Position', [94 142 115 22], ...
		'BackgroundColor', [1 1 1], ...
		'String', 'FCMap');

	set(handles.edtBandLow,	...		
		'Style', 'edit', ...
		'Units', 'pixels', ...
		'Position', [94 531 50 22], ...
		'BackgroundColor', [1 1 1], ...
		'String', '0.01', ...
		'Enable', 'off');

	set(handles.edtBandHigh,	...		
		'Style', 'edit', ...
		'Units', 'pixels', ...
		'Position', [171 531 50 22], ...
		'BackgroundColor', [1 1 1], ...
		'String', '0.08', ...
		'Enable', 'off');

	set(handles.edtSamplePeriod,	...		
		'Style', 'edit', ...
		'Units', 'pixels', ...
		'Position', [276 531 50 22], ...
		'BackgroundColor', [1 1 1], ...
		'String', '2', ...
		'Enable', 'off');

	
	set(handles.edtCovariableFile,	...		
		'Style', 'edit', ...
		'Units', 'pixels', ...
		'Position', [94 235 300 23], ...
		'BackgroundColor', [1 1 1], ...
		'String', '', ...
		'ForegroundColor', 'blue', ...
		'Enable', 'on');
		
	% --- LISTBOXES -------------------------------------
	set(handles.listDataDirs,	...		
		'Style', 'listbox', ...
		'Units', 'pixels', ...
		'Position', [14 400 413 108], ...
		'BackgroundColor', [1 1 1], ...
		'String', '');

	%20071103, Add context menu to Input Data Directories to add��delete��export��import����
	handles.hContextMenu =uicontextmenu;
	set(handles.listDataDirs, 'UIContextMenu', handles.hContextMenu);	
	uimenu(handles.hContextMenu, 'Label', 'Add a directory', 'Callback', get(handles.btnSelectDataDir, 'Callback'));	
	uimenu(handles.hContextMenu, 'Label', 'Remove selected directory', 'Callback', 'fc_gui(''DeleteSelectedDataDir'',gcbo,[], guidata(gcbo))');
	uimenu(handles.hContextMenu, 'Label', 'Add recursively all sub-folders of a directory', 'Callback', 'fc_gui(''RecursiveAddDataDir'',gcbo,[], guidata(gcbo))');
	uimenu(handles.hContextMenu, 'Label', '=============================');	
	uimenu(handles.hContextMenu, 'Label', 'Remove all data directories', 'Callback', 'fc_gui(''ClearDataDirectories'',gcbo,[], guidata(gcbo))');
	
	
	% Save handles structure	
	guidata(hObject,handles);

%% Log options to a log file for further investigation, 20070507 before Computing
function Log2File(handles)
	constLineSep= '-------------------------------------------------------------------------------';
	[theVer, theRelease] =rest_misc( 'GetRestVersion');
	theMsgVersion = sprintf('REST Version:%s, Release %s\r\n%s\r\n', theVer, theRelease, constLineSep);	
	theMsgHead = sprintf('Functional Connectivity computation log %s\r\n%s\r\n', rest_misc( 'GetDateTimeStr'), constLineSep);
	theMsg =sprintf('%s\r\n%s\r\n\r\n%s', theMsgVersion, theMsgHead, constLineSep);
	theMsg =sprintf('%s\r\nRemove Linear Trend options:\r\n%s\r\n\r\n%s',theMsg,...
					LogRemoveLinearTrend(handles), constLineSep);
	theMsg =sprintf('%s\r\nIdeal Band Pass filter options:\r\n%s\r\n\r\n%s',theMsg,...
					LogBandPassFilter(handles), constLineSep);
	theMsg =sprintf('%s\r\nFunctional Connectivity input parameters:\r\n%s\r\n\r\n%s', theMsg, ...
					LogInputParameters(handles), constLineSep);
	theMsg =sprintf('%s\r\nFunctional Connectivity output parameters:\r\n%s\r\n\r\n%s', theMsg, ...
					LogOutputParameters(handles), constLineSep);
	
	fid = fopen(handles.Log.Filename,'w');
	if fid~=-1
		fprintf(fid,'%s',theMsg);
		fclose(fid);
	else
		errordlg(sprintf('Error to open log file:\n\n%s', handles.Log.Filename));
	end
	
%Log the total elapsed time by once "Do all"
function LogPerformance(handles)	
	theMsg =sprintf('\r\n\r\nTotal elapsed time for Functional Connectivity Computing: %g  seconds\r\n',handles.Performance);
	fid = fopen(handles.Log.Filename,'r+');
	fseek(fid, 0, 'eof');
	if fid~=-1
		fprintf(fid,'%s',theMsg);
		fclose(fid);
	else
		errordlg(sprintf('Error to open log file:\n\n%s', handles.Log.Filename));
	end
	
	
function ResultLogString=LogRemoveLinearTrend(handles)
	ResultLogString ='';
	ResultLogString =sprintf('%s\tremove linear trend BEFORE filter: %s\r\n',ResultLogString, handles.Detrend.BeforeFilter);
	%ResultLogString =sprintf('%s\tremove linear trend AFTER filter: %s\r\n',ResultLogString, handles.Detrend.AfterFilter);
	
function ResultLogString=LogBandPassFilter(handles)
	ResultLogString ='';
	ResultLogString =sprintf('%s\tUse Filter: %s\r\n',ResultLogString, handles.Filter.UseFilter);
	ResultLogString =sprintf('%s\tBand Low: %g\r\n', ResultLogString, handles.Filter.BandLow);
	ResultLogString =sprintf('%s\tBand High: %g\r\n',ResultLogString, handles.Filter.BandHigh);
	ResultLogString =sprintf('%s\tSample Period(i.e. TR): %g\r\n',ResultLogString, handles.Filter.SamplePeriod);
	
function ResultLogString=LogInputParameters(handles)
	ResultLogString ='';
	constLineSep= '-------------------------------------------------------------------------------';
	theDataDirString= '';
	theDataDirCells =get(handles.listDataDirs, 'string');
	for x=1:length(theDataDirCells)
		theDataDirString =sprintf('%s\r\n\t%s', theDataDirString, theDataDirCells{x});
	end
	theDirType ='';
	if strcmpi(handles.Detrend.BeforeFilter, 'Yes')
		theDirType =sprintf(' %s after Detrend processing', theDirType);
	end
	if strcmpi(handles.Detrend.BeforeFilter, 'Yes') && ...
		strcmpi(handles.Filter.UseFilter, 'Yes'),
		theDirType =sprintf(' %s and ', theDirType);
	end
	if strcmpi(handles.Filter.UseFilter, 'Yes')
		theDirType =sprintf(' %s after Filter processing', theDirType);
	end
	ResultLogString =sprintf('%s\tInput Data Directories( %s): \r\n\t%s%s\r\n\t%s\r\n',ResultLogString,...
							theDirType, ...
							constLineSep, ...
							theDataDirString, ...
							constLineSep);
	ResultLogString =sprintf('%s\tMask file: %s\r\n', ResultLogString, handles.Cfg.MaskFile);	
		
	%Functional Connectivity
	ResultLogString =sprintf('%s\n\n\tFunctional Connectivity Parameters\r\n', ResultLogString);	
	%ROI Definition log
	if iscell(handles.Cfg.ROIList),
		for x=1:size(handles.Cfg.ROIList, 1),
			ResultLogString =sprintf('%s\tROI Definition: \n\t\t%s\r\n', ResultLogString, handles.Cfg.ROIList{x});	
		end
	else
		ResultLogString =sprintf('%s\tROI Definition: \n\t\t%s\r\n', ResultLogString, handles.Cfg.ROIList);	
	end
	%Covariable log
	ResultLogString =sprintf('%s\tCovariables Definition File: \n\t\t%s\r\n', ResultLogString, handles.Covariables.ort_file);	
	ResultLogString =sprintf('%s\tCovariables Polort (Polynomial Orthogonal Degree): \n\t\t%d\r\n', ResultLogString, handles.Covariables.polort);	
		
function ResultLogString=LogOutputParameters(handles)
	ResultLogString ='';
	ResultLogString =sprintf('%s\tPrefix to the Data directories: %s\r\n',ResultLogString, get(handles.edtPrefix, 'String'));
	ResultLogString =sprintf('%s\tOutput Data Directories: %s\r\n',ResultLogString, handles.Cfg.OutputDir);
	ResultLogString =sprintf('%s\tWant Fisher Z-score map transformation: %s \r\n',ResultLogString, handles.Cfg.WantFisherZMap);
	

%compose the log filename	
function ResultLogFileName=GetLogFilename(ALogDirectory, APrefix)
	if isempty(ALogDirectory)
		[pathstr, name, ext, versn] = fileparts(mfilename('fullpath'));	
		ALogDirectory =pathstr;
	end
	if ~strcmp(ALogDirectory(end), filesep)
		ALogDirectory =[ALogDirectory filesep];
	end
	ResultLogFileName=sprintf('%s%s_%s.log', ...
		ALogDirectory, ...
		APrefix, ...
		rest_misc( 'GetDateTimeStr'));
		

function btnSliceViewer_Callback(hObject, eventdata, handles)
	%Display a brain image like MRIcro
	theOldColor=get(hObject,'BackgroundColor');		
	set(hObject,'Enable','off', 'BackgroundColor', 'red');
	drawnow;
	try
		rest_sliceviewer;
		% [filename, pathname] = uigetfile({'*.img', 'ANALYZE or NIFTI files (*.img)'}, ...
														% 'Pick one brain map');
		% if any(filename~=0) && ischar(filename) && length(filename)>4 ,	% not canceled and legal			
			% if ~strcmpi(pathname(end), filesep)%revise pathname to remove extension		
				% pathname = [pathname filesep];
			% end
			% theBrainMap =[pathname filename];
			% rest_sliceviewer('ShowImage', theBrainMap);
		% end
	catch
		rest_misc( 'DisplayLastException');
	end	
	set(hObject,'Enable','on', 'BackgroundColor', theOldColor);
	drawnow;



function btnWaveGraph_Callback(hObject, eventdata, handles)
	%Display a brain image like MRIcro, and show specific voxel's time course and its freq domain's fluctuation
	theOldColor=get(hObject,'BackgroundColor');		
	set(hObject,'Enable','off', 'BackgroundColor', 'red');
	drawnow;
	try
		[filename, pathname] = uigetfile({'*.img', 'ANALYZE or NIFTI files (*.img)'}, ...
														'Pick one functional EPI brain map in the dataset''s directory');
		if any(filename~=0) && ischar(filename),	% not canceled and legal			
			if ~strcmpi(pathname(end), filesep)%revise pathname to remove extension		
				pathname = [pathname filesep];
			end
			theBrainMap 	=[pathname filename];			
			theViewer =rest_sliceviewer('ShowImage', theBrainMap);
			
			%Set the Functional Connectivity figure to show corresponding voxel's time-course and its freq amplitude
			theDataSetDir 	=pathname;
			theVoxelPosition=rest_sliceviewer('GetPosition', theViewer);
			theSamplePeriod =handles.Filter.SamplePeriod;
			theBandRange	=[handles.Filter.BandLow, handles.Filter.BandHigh];						
			rest_powerspectrum('ShowFluctuation', theDataSetDir, theVoxelPosition, ...
							theSamplePeriod, theBandRange);
							
			%Update the Callback
			theCallback 	='';
			cmdDataSetDir	=sprintf('theDataSetDir= ''%s'';', theDataSetDir);
			cmdBrainMap 	=sprintf('theVoxelPosition=rest_sliceviewer(''GetPosition'', %g);', theViewer);
			cmdSamplePeriod =sprintf('theSamplePeriod= %g;', theSamplePeriod);
			cmdBandRange	=sprintf('theBandRange= [%g, %g];', theBandRange(1), theBandRange(2));
			cmdUpdateWaveGraph	='rest_powerspectrum(''ShowFluctuation'', theDataSetDir, theVoxelPosition, theSamplePeriod, theBandRange);';
			theCallback	=sprintf('%s\n%s\n%s\n%s\n%s\n',cmdDataSetDir, ...
								cmdBrainMap, cmdSamplePeriod, cmdBandRange, ...
								cmdUpdateWaveGraph);
			cmdClearVar ='clear theDataSetDir theVoxelPosition theSamplePeriod theBandRange;';
			rest_sliceviewer('UpdateCallback', theViewer, [theCallback cmdClearVar], 'ALFF Analysis');
			
			% Update some Message
			theMsg =sprintf('TR( s): %g\nBand( Hz): %g~%g', ...
							theSamplePeriod, theBandRange(1), theBandRange(2) );
			rest_sliceviewer('SetMessage', theViewer, theMsg);
		end
	catch
		rest_misc( 'DisplayLastException');
	end	
	set(hObject,'Enable','on', 'BackgroundColor', theOldColor);
	drawnow;
	rest_waitbar;


function ckboxRemoveTrendBefore_Callback(hObject, eventdata, handles)
	if get(hObject,'Value')
		handles.Detrend.BeforeFilter ='Yes';
	else	
		handles.Detrend.BeforeFilter ='No';
	end	
	guidata(hObject, handles);
	UpdateDisplay(handles);

function ckboxRemoveTrendAfter_Callback(hObject, eventdata, handles)
	if get(hObject,'Value')
		handles.Detrend.AfterFilter ='Yes';
	else	
		handles.Detrend.AfterFilter ='No';
	end	
	guidata(hObject, handles);
	UpdateDisplay(handles);

function btnDetrend_Callback(hObject, eventdata, handles)
	try
		Detrend(hObject,handles);
		msgbox('Remove the Linear Trend Over.',...
				'Detrend successfully' ,'help');
	catch
		rest_misc( 'DisplayLastException');
	end
	rest_waitbar;

function Detrend(hObject,handles)
	for x=1:size(handles.Cfg.DataDirs, 1)	
		%Update display
		set(handles.listDataDirs, 'Value', x);
		drawnow;
		if size(handles.Cfg.DataDirs, 1)>1,
			rest_waitbar((x-1)/size(handles.Cfg.DataDirs, 1)+0.01, ...
					handles.Cfg.DataDirs{x, 1}, ...
					'Removing the Linear Trend','Parent');
		end		
		rest_detrend(handles.Cfg.DataDirs{x, 1}, '_detrend');
		
		%Revise the data directories
		handles.Cfg.DataDirs{x, 1}=[handles.Cfg.DataDirs{x, 1} , '_detrend'];
		guidata(hObject, handles);	% Save Dir names
	end	
	UpdateDisplay(handles);
	
	
function BandPass(hObject, handles)
	for x=1:size(handles.Cfg.DataDirs, 1)	
		%Update display
		set(handles.listDataDirs, 'Value', x);
		drawnow;
		if size(handles.Cfg.DataDirs, 1)>1,
			rest_waitbar((x-1)/size(handles.Cfg.DataDirs, 1)+0.01, ...
					handles.Cfg.DataDirs{x, 1}, ...
					'Band Pass filter','Parent');
		end
				
		rest_bandpass(handles.Cfg.DataDirs{x, 1}, ...
					  handles.Filter.SamplePeriod, ...								  
					  handles.Filter.BandHigh, ...
					  handles.Filter.BandLow, ...
					  handles.Filter.Retrend, ...
					  handles.Cfg.MaskFile);
		%build the postfix for filtering
		thePostfix ='_filtered';					
		%Revise the data directories
		handles.Cfg.DataDirs{x, 1}=[handles.Cfg.DataDirs{x, 1} , thePostfix];
		guidata(hObject, handles);	% Save Dir names
	end
	UpdateDisplay(handles);

function btnHelp_Callback(hObject, eventdata, handles)
	web('http://resting-fmri.sourceforge.net');
	%web (sprintf('%s/man/English/ALFF/index.html', rest_misc( 'WhereIsREST')), '-helpbrowser');
	









function btnROIVoxelWise_Callback(hObject, eventdata, handles)
	%msgbox( sprintf('There is two way to define a ROI:\n\n1. Define a ball with its central coordinate and radius. Such as defining a ROI ball which centered at (-2,-36,37) and had a radius 10, you could enter "(-2,-36,37), radius=10".\n\n2. Any other ROI that''s not a ball. This kind of ROI could be defined by MRIcro or other softwares and must be a ANALYZE or NIFTI hdr/img file. Then select this file as ROI definition like selecting a mask.'), ...
	%		'ROI Definition method' ,'help');
	try
		if ~iscell(handles.Cfg.ROIList),
			handles.Cfg.ROIList =rest_SetROI('Init', handles.Cfg.ROIList);		
		else
			if prod(size(handles.Cfg.ROIList)),
				handles.Cfg.ROIList =rest_SetROI('Init', handles.Cfg.ROIList{1});
			else
				handles.Cfg.ROIList =rest_SetROI('Init');
			end
		end
	catch
		rest_SetROI('Delete');
	end
	guidata(hObject, handles);
	UpdateDisplay(handles);
	

function btnROIRegionWise_Callback(hObject, eventdata, handles)
	if ~iscell(handles.Cfg.ROIList), handles.Cfg.ROIList={handles.Cfg.ROIList}; end
	handles.Cfg.ROIList=rest_ROIList_gui(handles.Cfg.ROIList);	 
	% if prod(size(handles.Cfg.ROIList)) && size(handles.Cfg.ROIList, 1)==1,
		% handles.Cfg.ROIList =handles.Cfg.ROIList{1};
	% end
	guidata(hObject, handles);
	UpdateDisplay(handles);


function btnComputeFC_Callback(hObject, eventdata, handles)
	if (size(handles.Cfg.DataDirs, 1)==0) %check legal parameter set first
		errordlg('No Data found! Please re-config'); 
		return;
	end
	if size(handles.Cfg.ROIList, 1) ==0,
		errordlg('No ROI Defined! Please define ROI first'); 
		return;
	end
	%Remove the blank ROI definition at the end before judging
	if iscell(handles.Cfg.ROIList) && all(isspace(handles.Cfg.ROIList{1})),
		handles.Cfg.ROIList(1)=[];
	end
	if iscell(handles.Cfg.ROIList) && size(handles.Cfg.ROIList,1)<2 ,
		errordlg('Only one ROI Defined for ROI-wise functional connectivity! Please define ROI first'); 
		return;
	end
	
    if (exist('fc.m','file')==2)
		%write log 20070830
		handles.Log.Filename =GetLogFilename(handles.Cfg.OutputDir, get(handles.edtPrefix, 'String'));
		Log2File(handles);
		handles.Performance =cputime; %Write down the Start time , 20070903
		%start computation
		theOldDir =pwd;
		theOldColor=get(hObject,'BackgroundColor');		
		set(hObject,'Enable','off', 'BackgroundColor', 'red');
		drawnow;
		try
			%%Remove the linear trend first, and create a new directory, then do filtering
			if strcmpi(handles.Filter.UseFilter, 'Yes') && strcmpi(handles.Detrend.BeforeFilter, 'Yes'),
				Detrend(hObject, handles);
				%20070614, Bug fix, Update the data structure manually
				handles =guidata(hObject);	% I have to read it again, because I changed it for further processing		
			end	
			
			%%Filter all the data and create a new directory, then compute the Functional Connectivity value, dawnsong 20070429
			%Band pass filter
			if strcmpi(handles.Filter.UseFilter, 'Yes')
				BandPass(hObject, handles);	
				%20070614, Bug fix, Update the data structure manually
				handles =guidata(hObject);	% I have to read it again, because I changed it	for further processing			
			end	
			
			%%Remove the linear trend after filtering, and create a new directory, then do ReHo
			if strcmpi(handles.Filter.UseFilter, 'Yes') && strcmpi(handles.Detrend.AfterFilter, 'Yes'),
				Detrend(hObject, handles);
				%20070614, Bug fix, Update the data structure manually
				handles =guidata(hObject);	% I have to read it again, because I changed it for further processing		
			end
			
			%compute the Functional Connectivity brain
			for x=1:size(handles.Cfg.DataDirs, 1)	
				%Update display
				set(handles.listDataDirs, 'Value', x);
				drawnow;
				if size(handles.Cfg.DataDirs, 1)>1, 
					rest_waitbar((x-1)/size(handles.Cfg.DataDirs, 1)+0.01, ...
								handles.Cfg.DataDirs{x, 1}, ...
								'Functional connectivity Computing','Parent');
				end				
				fprintf('\nFunctional connectivity :"%s"\n', handles.Cfg.DataDirs{x, 1});				
				
				theOutputDir=get(handles.edtOutputDir, 'String');
				thePrefix =get(handles.edtPrefix, 'String');
				theDstFile=fullfile(theOutputDir,[thePrefix '_' ...
											GetDirName(handles.Cfg.DataDirs{x, 1}) ] );
                                        
				Subject_Covariables = handles.Covariables; % Revised by YAN Chao-Gan 080804, in order to process multiple subjects with different covaribles in batch mode.
                if ~isempty(handles.Covariables.ort_file)  % Revised by YAN Chao-Gan 080903, in order to fix the bug that with no Covariables
                    CovariablesList=textread(handles.Covariables.ort_file,'%s')
                    if strcmp(CovariablesList{1},'Covariables_List:')
                        Subject_Covariables.ort_file=CovariablesList{x+1};
                    end
                end
                
                Subject_ROIList = handles.Cfg.ROIList; % Added by YAN Chao-Gan 091104, in order to process multiple subjects with different seed time courses in batch mode.
                if ~iscell(handles.Cfg.ROIList)  %Revised by YAN Chao-Gan 100130, fixed the bug in ROI-wise functional connectivity calculation. %if 2==exist(handles.Cfg.ROIList) 
                    [pathstr, name, ext, versn] = fileparts(handles.Cfg.ROIList) 
                    if strcmpi(ext,'.txt')
                        SeedTimeCourseList=textread(handles.Cfg.ROIList,'%s')
                        if strcmp(SeedTimeCourseList{1},'Seed_Time_Course_List:')
                            Subject_ROIList=SeedTimeCourseList{x+1};
                        end
                    end
                end
                
		        ResultMaps =fc( handles.Cfg.DataDirs{x, 1}, ...
								handles.Cfg.MaskFile, ...
								Subject_ROIList, ...            %Revised by YAN Chao-Gan 091104         %handles.Cfg.ROIList
								theDstFile, ...
								Subject_Covariables);			% Revised by YAN Chao-Gan 080804		% handles.Covariables);		
				
				%20070504, divide Functional Connectivity brain by the mean within the mask
				if strcmpi(handles.Cfg.WantFisherZMap, 'Yes')
					if ndims(ResultMaps)>2 && size(ResultMaps, 1)>1 ,
						%There are many correlation maps
						for y=1:size(ResultMaps, 1),
							theOrigFCMap =ResultMaps{y, 1};
							[pathstr, name, ext, versn] = fileparts(theOrigFCMap);
							theFisherZMap =[pathstr, filesep, 'z', name, ext, versn];
							theMaskFile =handles.Cfg.MaskFile;
							rest_Corr2FisherZ(theOrigFCMap, theFisherZMap, theMaskFile);
						end
					elseif size(ResultMaps, 1)==1,
						%There is only one correlation map
						theOrigFCMap =theDstFile;
						[pathstr, name, ext, versn] = fileparts(theOrigFCMap);
						theFisherZMap =[pathstr, filesep, 'z', name, ext, versn];
						theMaskFile =handles.Cfg.MaskFile;
						rest_Corr2FisherZ(theOrigFCMap, theFisherZMap, theMaskFile);
					elseif ndims(ResultMaps)==2,
						%Time series correlation matrix
						theOrigFCMap =theDstFile;
						[pathstr, name, ext, versn] = fileparts(theOrigFCMap);
						theFisherZMap =[pathstr, filesep, 'z', name, ext, versn];
						ResultMaps =0.5 * log((1 +ResultMaps)./(1- ResultMaps));
						save([theFisherZMap, '.txt'], 'ResultMaps', '-ASCII', '-DOUBLE','-TABS')
					end
				end
			end		
			handles.Performance =cputime -handles.Performance; %Write down the End time , 20070903
			LogPerformance(handles);		
		catch	
			rest_misc( 'DisplayLastException');			
			errordlg(sprintf('Exception occured: \n\n%s' , lasterr)); 
		end		
		cd(theOldDir);
		set(hObject,'Enable','on', 'BackgroundColor', theOldColor);
		drawnow;
		rest_waitbar;
    else
        errordlg('No fc.m ! Please re-install'); 
    end






	
function edtCovariableFile_Callback(hObject, eventdata, handles)
	handles.Covariables.ort_file =get(hObject, 'String');
	guidata(hObject,handles); 

function edtCovariableFile_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function btnSelectCovariableFile_Callback(hObject, eventdata, handles)
	[filename, pathname] = uigetfile({'*.txt; *.1D', 'Covariables'' time course file (*.txt; *.1D)'; ...
												'*.txt','text file (*.txt)'; ...
												'*.1D', 'AFNI 1D file(*.1D)'}, ...
												'Pick Covariables'' time course file');
    if ~(filename==0),
        handles.Covariables.ort_file =[pathname filename];
        guidata(hObject,handles);    
    end    
    UpdateDisplay(handles);

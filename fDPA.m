function varargout = fDPA(varargin)

%fMRI Data Processing Assistant. Original GUI by YAN Chao-Gan. Modified by Eerik Puska at Aalto
%University.

%-----------------------------------------------------------
%	Copyright(c) 2009~2013
%	State Key Laboratory of Cognitive Neuroscience and Learning, Beijing Normal University
%	Written by YAN Chao-Gan
%	http://www.restfmri.net
% $mail     =ycg.yan@gmail.com
%-----------------------------------------------------------
% 	Mail to original Author:  <a href="ycg.yan@gmail.com">YAN Chao-Gan</a>

% Modified by YAN Chao-Gan 090712, added the function of mReHo - 1, mALFF - 1, mfALFF -1.
% Modified by YAN Chao-Gan 090901, added the function of smReHo, remove variable first time points.
% Modified by YAN Chao-Gan 090909, fixed the bug of setting user's defined mask.
% Modified by YAN Chao-Gan 091111. 1. Use different Affine Regularisation in Segmentation: East Asian brains (eastern) or European brains (mni). 2. Added a checkbox for removing first time points. 3.Added popup menu to delete selected subject by right click. 4. Close wait bar when program finished.
% Modified by YAN Chao-Gan 091127. Add Utilities: Change the Prefix of Images.
% Modified by YAN Chao-Gan 091215. Also can regress out other covariates.
% Modified by YAN Chao-Gan, 100201. Save the configuration parameters automatically.
% Modified by YAN Chao-Gan, 100510. Added a right-click menu to delete all the participants.
% Modified by YAN Chao-Gan, 101025. Fixed the bug of 'copying co*'.
% Modified by YAN Chao-Gan, 110505. Fixed an error in the future MATLAB version in "[pathstr, name, ext, versn] = fileparts...".
% Modified by Eerik Puska & Yevhen Hlushchuk (Aalto University), 05-07/2011. Added functionalities for cleaning up data based on ECG and respiration data (Drifter), removing volumes in case of artifacts (ArtRepair), moving origo in pictures in order to make segmentation work better, and made the slice timing correction optional. Also modified some UI texts and layoutm, changed the name to more general "fMRI Data Processing Assistant (fDPA)".
% Modified by Janne Kauttonen 10/2013-02/2014. Lots of modifications and adds.

[ProgramPath, notneeded1, notneeded2] = fileparts(which('fDPA.m'));
addpath(ProgramPath);

warning('on','all');

global fsl_root_command;

fsl_root_command = 'fsl5.0-';
%setenv('LD_LIBRARY_PATH',''); %

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',  mfilename, ...
    'gui_Singleton',  gui_Singleton, ...
    'gui_OpeningFcn', @fDPA_OpeningFcn, ...
    'gui_OutputFcn',  @fDPA_OutputFcn, ...
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


% --- Executes just before fDPA is made visible.
function fDPA_OpeningFcn(hObject, eventdata, handles, varargin)
if ispc
    UserName =getenv('USERNAME');
else
    UserName =getenv('USER');
end
Datetime=fix(clock);
fprintf('-----------------------------------------------------------\n');
fprintf('Welcome: %s, %.4d-%.2d-%.2d %.2d:%.2d \n', UserName,Datetime(1),Datetime(2),Datetime(3),Datetime(4),Datetime(5));
fprintf('-----------------------------------------------------------\n');
fprintf('NeuroCine Data Processing Assistant ("fDPA")\n');
fprintf('Yevhen Hlushchuk and Eerik Puska 2011-2013\n');
fprintf('Janne Kauttonen 2014-2015\n');
fprintf('(Based on Data Processing Assistant for Resting-State fMRI (DPARSF) by YAN Chao-Gan\nat State Key Laboratory of Cognitive Neuroscience and Learning, Beijing Normal University, China)\n');
fprintf('-----------------------------------------------------------\n');
fprintf('Message from original author:\n');
fprintf('Data Processing Assistant for Resting-State fMRI (DPARSF).\n');
fprintf('Copyright(c) 2009~2013\nState Key Laboratory of Cognitive Neuroscience and Learning, Beijing Normal University, China\nMail to Author:  <a href="ycg.yan@gmail.com">YAN Chao-Gan</a>\nhttp://www.restfmri.net\n');
fprintf('Citing Information:\nIf you think DPARSF is useful for your work, citing it in your paper would be greatly appreciated.\nSomething like "... preprocessing were carried out using Statistical Parametric Mapping (SPM8, http://www.fil.ion.ucl.ac.uk/spm) and Data Processing Assistant for Resting-State fMRI (DPARSF) V2.0 Basic Edition (Yan and Zang, 2010) ..." in your method session would be fine. If FC, ReHo, ALFF or fALFF is computed, please also cite Resting-State fMRI Data Analysis Toolkit (REST, by Song et al., http://www.restfmri.net).\nReference: Yan C and Zang Y (2010) DPARSF: a MATLAB toolbox for "pipeline" data analysis of resting-state fMRI. Front. Syst. Neurosci. 4:13. doi:10.3389/fnsys.2010.00013\n');
fprintf('-----------------------------------------------------------\n');

handles.hContextMenu =uicontextmenu;
set(handles.listSubjectID, 'UIContextMenu', handles.hContextMenu);	%Added by YAN Chao-Gan 091110. Added popup menu to delete selected subject by right click.
uimenu(handles.hContextMenu, 'Label', 'Remove the selected participant', 'Callback', 'fDPA(''DeleteSelectedSubjectID'',gcbo,[], guidata(gcbo))');
uimenu(handles.hContextMenu, 'Label', 'Remove all the participants', 'Callback', 'fDPA(''DeleteAllSubjects'',gcbo,[], guidata(gcbo))');

handles.Cfg.hasFunData = 0;
handles.Cfg.WorkingDir = pwd;
handles.Cfg.DataProcessDir =[];
handles.Cfg.SubjectID={};
handles.Cfg.TimePoints=0;
handles.Cfg.TR=0;
handles.Cfg.IsNeedConvertFunDCM2IMG=1;
handles.Cfg.IsRemoveFirstTimePoints=0;
handles.Cfg.RemoveFirstTimePoints=0;
handles.Cfg.IsSliceTiming=0;
handles.Cfg.SliceTiming.SliceNumber=26;
handles.Cfg.SliceTiming.IsAutoSliceNumber=true;
handles.Cfg.SliceTiming.TA=handles.Cfg.TR-(handles.Cfg.TR/handles.Cfg.SliceTiming.SliceNumber);
handles.Cfg.SliceTiming.SliceOrder=[1:2:26,2:2:26];
handles.Cfg.SliceTiming.IsInterleaved=true;
handles.Cfg.SliceTiming.ReferenceSlice=2;
handles.Cfg.SliceTiming.IsMiddleReference=true;
handles.Cfg.IsRealign=1;
handles.Cfg.IsNormalize=2;
handles.Cfg.IsNeedConvertT1DCM2IMG=1;
handles.Cfg.Normalize.BoundingBox=[-90 -126 -72;90 90 108];
handles.Cfg.Normalize.VoxSize=[2,2,2];
handles.Cfg.Normalize.AffineRegularisationInSegmentation='mni';

handles.Cfg.GotParams=1; %New 09/11 /EP

handles.Cfg.IsDelFilesBeforeNormalize=0;
handles.Cfg.IsSmooth=0;
handles.Cfg.Smooth.FWHM=[7 7 7];
handles.Cfg.IsDetrend=1;
handles.Cfg.DetrendPolyOrder=1;
handles.Cfg.IsFilter=0;
handles.Cfg.Filter.ASamplePeriod=2;
handles.Cfg.Filter.AHighPass_LowCutoff=0.008;
handles.Cfg.Filter.ALowPass_HighCutoff=999.0;
handles.Cfg.Filter.AMaskFilename='';
handles.Cfg.Filter.AAddMeanBack='Yes';  %YAN Chao-Gan, 100420. %handles.Cfg.Filter.ARetrend='Yes';
handles.Cfg.IsDelDetrendedFiles=0;

handles.Cfg.StartingDirName = [];

handles.Cfg.IsMultisession=0;

handles.Cfg.IsExtractRESTdefinedROITC=0;
handles.Cfg.IsCalFC=0;
handles.Cfg.CalFC.ROIDef=[];
handles.Cfg.CalFC.AMaskFilename='Default';

handles.Cfg.IsResliceT1To1x1x1=0;
handles.Cfg.IsT1Segment=0;
handles.Cfg.IsWrapAALToNative=0;
handles.Cfg.IsExtractAALGMVolume=0;

handles.Cfg.VolumeArtifactRemoval=0; %New 05/11 /EP
handles.Cfg.PercentThresh=1.5; %New 05/11 /EP
handles.Cfg.ZThresh=3.0; %New 05/11 /EP
handles.Cfg.MvmtThresh=0.5; %New 05/11 /EP

handles.Cfg.CalculateContrasts=0; %New 06/11 /EP
handles.Cfg.ContrastsJobFile={}; %New 06/11 /EP
handles.Cfg.BiasCorrectmeanEPI = 1; % Added YH 2012/09/17

handles.Cfg.Drifter=0; %New 09/11 /EP
handles.Cfg.isNormalizeMNI152=1;

handles.Cfg.SourceDir=[]; %New 09/11 /EP
handles.Cfg.NiiConversion=1; %New 09/11 /EP

handles.Cfg.IsAFNI=0;   % NEW 9/13  JanneK
handles.Cfg.IsManualSkullstrip=0; % NEW 9/13 JanneK
handles.Cfg.IsManualAlignment=0;  % NEW 1/14  JanneK
handles.Cfg.CreateGroupMask=1; % NEW 1/14  JanneK

handles.Cfg.doAggressive=0; % NEW 1/14  JanneK

handles.Cfg.requested_nworker = 1; % number of parallel processes to use

handles.Cfg.FinalizeEPIs=0;

handles = checkSPMversion(handles);

guidata(hObject, handles);
UpdateDisplay(handles);
movegui(handles.figfDPAMain, 'center');
set(handles.figfDPAMain,'Name','fDPA');



% Make Display correct in linux
if ~ispc
    ZoomFactor=0.85;
    ObjectNames = fieldnames(handles);
    for i=1:length(ObjectNames);
        eval(['IsFontSizeProp=isprop(handles.',ObjectNames{i},',''FontSize'');']);
        if IsFontSizeProp
            eval(['PCFontSize=get(handles.',ObjectNames{i},',''FontSize'');']);
            FontSize=PCFontSize*ZoomFactor;
            eval(['set(handles.',ObjectNames{i},',''FontSize'',',num2str(FontSize),');']);
        end
    end
end


% Choose default command line output for fDPA
handles.output = hObject;
guidata(hObject, handles);% Update handles structure

% UIWAIT makes fDPA wait for user response (see UIRESUME)
% uiwait(handles.figDPARSFMain);

% --- Outputs from this function are returned to the command line.
function varargout = fDPA_OutputFcn(hObject, eventdata, handles)
% Get default command line output from handles structure
varargout{1} = handles.output;


function edtWorkingDir_Callback(hObject, eventdata, handles)
theDir =get(hObject, 'String');
uiwait(msgbox({'Standard processing steps:';...
    '1. Convert DICOM files to NIFTI images. 2. Remove First Time Points. 3. Slice Timing. 4. Realign. 5. Normalize. 6. ECG/Respiration compensation (Drifter). 7. Volume artifact removal (ArtRepair) 8. Smooth. 9. Detrend. 10. Filter. (11. Calculate ReHo, ALFF, fALFF. 12. Regress out the Covariables. 13. Calculate Functional Connectivity. 14. Extract AAL or ROI time courses for further analysis.)';...
    '';...
    'All the input image files should be arranged in the working directory, and fDPA will put all the output results in the working directory.';...
    '';...
    'For example, if you start with raw DICOM images, you need to arrange each subject''s fMRI DICOM images in one directory, and then put them in "FunRaw" directory under the working directory. i.e.:';...
    '{Working Directory}\FunRaw\Subject001\xxxxx001.dcm';...
    '{Working Directory}\FunRaw\Subject001\xxxxx002.dcm';...
    '...';...
    '{Working Directory}\FunRaw\Subject002\xxxxx001.dcm';...
    '{Working Directory}\FunRaw\Subject002\xxxxx002.dcm';...
    '...';...
    '...';...
    'Please do not name your subjects initiated with letter "a", fDPA will face difficulties to distinguish the images before and after slice timing if the subjects'' name has an "a" initial.';...
    '';...
    'If you start with NIFTI images (.hdr/.img pairs) before slice timing, you need to arrange each subject''s fMRI NIFTI images in one directory, and then put them in "FunImg" directory under the working directory. i.e.:';...
    '{Working Directory}\FunImg\Subject001\xxxxx001.img';...
    '{Working Directory}\FunImg\Subject001\xxxxx002.img';...
    '...';...
    '{Working Directory}\FunImg\Subject002\xxxxx001.img';...
    '{Working Directory}\FunImg\Subject002\xxxxx002.img';...
    '...';...
    '...';...
    '';...
    'If you start with NIFTI images after normalization, you need to arrange each subject''s NIFTI images in one directory, and then put them in "FunImgNormalized" directory under the working directory.';...
    },'Please select the Working directory'));
SetWorkingDir(hObject,handles, theDir);

function btnSelectWorkingDir_Callback(hObject, eventdata, handles)
uiwait(msgbox({'Standard processing steps:';...
    '1. Convert DICOM files to NIFTI images. 2. Remove First Time Points. 3. Slice Timing. 4. Realign. 5. Normalize. 6. ECG/Respiration compensation (Drifter). 7. Volume artifact removal (ArtRepair) 8. Smooth. 9. Detrend. 10. Filter. (11. Calculate ReHo, ALFF, fALFF. 12. Regress out the Covariables. 13. Calculate Functional Connectivity. 14. Extract AAL or ROI time courses for further analysis.)';...
    '';...
    'All the input image files should be arranged in the working directory, and fDPA will put all the output results in the working directory.';...
    '';...
    'For example, if you start with raw DICOM images, you need to arrange each subject''s fMRI DICOM images in one directory, and then put them in "FunRaw" directory under the working directory. i.e.:';...
    '{Working Directory}\FunRaw\Subject001\xxxxx001.dcm';...
    '{Working Directory}\FunRaw\Subject001\xxxxx002.dcm';...
    '...';...
    '{Working Directory}\FunRaw\Subject002\xxxxx001.dcm';...
    '{Working Directory}\FunRaw\Subject002\xxxxx002.dcm';...
    '...';...
    '...';...
    'Please do not name your subjects initiated with letter "a", fDPA will face difficulties to distinguish the images before and after slice timing if the subjects'' name has an "a" initial.';...
    '';...
    'If you start with NIFTI images (.hdr/.img pairs) before slice timing, you need to arrange each subject''s fMRI NIFTI images in one directory, and then put them in "FunImg" directory under the working directory. i.e.:';...
    '{Working Directory}\FunImg\Subject001\xxxxx001.img';...
    '{Working Directory}\FunImg\Subject001\xxxxx002.img';...
    '...';...
    '{Working Directory}\FunImg\Subject002\xxxxx001.img';...
    '{Working Directory}\FunImg\Subject002\xxxxx002.img';...
    '...';...
    '...';...
    '';...
    'If you start with NIFTI images after normalization, you need to arrange each subject''s NIFTI images in one directory, and then put them in "FunImgNormalized" directory under the working directory.';...
    },'Please select the Working directory'));
theDir =handles.Cfg.WorkingDir;
theDir =uigetdir(theDir, 'Please select the Working directory: ');
if ~isequal(theDir, 0)
    SetWorkingDir(hObject,handles, theDir);
end

function SetWorkingDir(hObject, handles, ADir)
if 7==exist(ADir,'dir')
    handles.Cfg.WorkingDir =ADir;
    %%handles.Cfg.DataProcessDir =handles.Cfg.WorkingDir;
    handles.Cfg.SubjectID = {};
    guidata(hObject, handles);
    UpdateDisplay(handles);
end
handles=CheckCfgParameters(handles);
guidata(hObject, handles);
UpdateDisplay(handles);

function listSubjectID_Callback(hObject, eventdata, handles)
theIndex =get(hObject, 'Value');

function listSubjectID_KeyPressFcn(hObject, eventdata, handles)
%Delete the selected item when 'Del' is pressed
key =get(handles.figfDPAMain, 'currentkey');
if seqmatch({key},{'delete'})
    DeleteSelectedSubjectID(hObject, eventdata,handles);
end

function DeleteSelectedSubjectID(hObject, eventdata, handles)
theIndex =get(handles.listSubjectID, 'Value');
if size(handles.Cfg.SubjectID, 1)==0 || max(theIndex)>size(handles.Cfg.SubjectID, 1),
    return;
end

theSubject=handles.Cfg.SubjectID(theIndex, 1);
tmpMsg=sprintf('Delete the Participant(s): "%s" ?',cell2str(theSubject));
if strcmp(questdlg(tmpMsg, 'Delete confirmation'), 'Yes')
    %ind=find(theIndex>1);
    %set(handles.listSubjectID, 'Value', theIndex(ind)-1);
    handles.Cfg.SubjectID(theIndex, :)=[];
    if size(handles.Cfg.SubjectID, 1)==0
        handles.Cfg.SubjectID={};
    end
    guidata(hObject, handles);
    set(handles.listSubjectID, 'Value',1);
    UpdateDisplay(handles);
end

function DeleteAllSubjects(hObject, eventdata, handles)
tmpMsg=sprintf('Delete all the participants?');
if strcmp(questdlg(tmpMsg, 'Delete confirmation'), 'Yes')
    handles.Cfg.SubjectID={};
    guidata(hObject, handles);
    UpdateDisplay(handles);
end

function editTimePoints_Callback(hObject, eventdata, handles)
handles.Cfg.TimePoints =str2double(get(hObject,'String'));
guidata(hObject, handles);
UpdateDisplay(handles);

function editTR_Callback(hObject, eventdata, handles)
handles.Cfg.TR =str2double(get(hObject,'String'));
handles.Cfg.SliceTiming.TA=handles.Cfg.TR-(handles.Cfg.TR/handles.Cfg.SliceTiming.SliceNumber);
handles.Cfg.Filter.ASamplePeriod=handles.Cfg.TR;
handles.Cfg.CalALFF.ASamplePeriod=handles.Cfg.TR;
handles.Cfg.CalfALFF.ASamplePeriod=handles.Cfg.TR;
guidata(hObject, handles);
UpdateDisplay(handles);

function ckboxEPIDICOM2NIFTI_Callback(hObject, eventdata, handles)
if get(hObject,'Value')
    handles.Cfg.IsNeedConvertFunDCM2IMG = 1;
    handles.Cfg.SourceDir = 'FunRaw';
else
    handles.Cfg.IsNeedConvertFunDCM2IMG = 0;
    handles.Cfg.SourceDir = 'FunImg';
end
handles=CheckCfgParameters(handles);
guidata(hObject, handles);
UpdateDisplay(handles);

function checkboxRemoveFirstTimePoints_Callback(hObject, eventdata, handles)
if get(hObject,'Value')
    handles.Cfg.IsRemoveFirstTimePoints = 1;
else
    handles.Cfg.IsRemoveFirstTimePoints = 0;
end
%handles.Cfg.RemoveFirstTimePoints=handles.Cfg.RemoveFirstTimePoints*handles.Cfg.IsRemoveFirstTimePoints;
%handles=CheckCfgParameters(handles);
guidata(hObject, handles);
UpdateDisplay(handles);

function checkbox_slicenumber_Callback(hObject, eventdata, handles)
if get(hObject,'Value')
    handles.Cfg.SliceTiming.IsAutoSliceNumber = true;
else
    handles.Cfg.SliceTiming.IsAutoSliceNumber = false;
end

if handles.Cfg.SPMver==8
    handles.Cfg.SliceTiming.IsInterleaved = false;
    warning('Cannot use automatic slicenumber with SPM8!');
end
%handles.Cfg.RemoveFirstTimePoints=handles.Cfg.RemoveFirstTimePoints*handles.Cfg.IsRemoveFirstTimePoints;
%handles=CheckCfgParameters(handles);
guidata(hObject, handles);
UpdateDisplay(handles);

function checkbox_slicereference_Callback(hObject, eventdata, handles)
if get(hObject,'Value')
    handles.Cfg.SliceTiming.IsMiddleReference = true;
else
    handles.Cfg.SliceTiming.IsMiddleReference = false;
end

if handles.Cfg.SPMver==8
    handles.Cfg.SliceTiming.IsInterleaved = false;
    warning('Cannot use automatic reference with SPM8!');
end

%handles.Cfg.RemoveFirstTimePoints=handles.Cfg.RemoveFirstTimePoints*handles.Cfg.IsRemoveFirstTimePoints;
%handles=CheckCfgParameters(handles);
guidata(hObject, handles);
UpdateDisplay(handles);

function checkbox_sliceorder_Callback(hObject, eventdata, handles)
if get(hObject,'Value')
    handles.Cfg.SliceTiming.IsInterleaved = true;
else
    handles.Cfg.SliceTiming.IsInterleaved = false;
end

if handles.Cfg.SPMver==8
    handles.Cfg.SliceTiming.IsInterleaved = false;
    warning('Cannot use automatic sliceorder with SPM8!');
end
%handles.Cfg.RemoveFirstTimePoints=handles.Cfg.RemoveFirstTimePoints*handles.Cfg.IsRemoveFirstTimePoints;
%handles=CheckCfgParameters(handles);
guidata(hObject, handles);
UpdateDisplay(handles);


function editRemoveFirstTimePoints_Callback(hObject, eventdata, handles)
handles.Cfg.RemoveFirstTimePoints =str2double(get(hObject,'String'));
handles.Cfg.RemoveFirstTimePoints=round(max(0,handles.Cfg.RemoveFirstTimePoints*handles.Cfg.IsRemoveFirstTimePoints));
guidata(hObject, handles);
UpdateDisplay(handles);

function checkboxSliceTiming_Callback(hObject, eventdata, handles)
if get(hObject,'Value')
    handles.Cfg.IsSliceTiming = 1;
else
    handles.Cfg.IsSliceTiming = 0;
end
%handles=CheckCfgParameters(handles);
guidata(hObject, handles);
UpdateDisplay(handles);

function editSliceNumber_Callback(hObject, eventdata, handles)
handles.Cfg.SliceTiming.SliceNumber =str2double(get(hObject,'String'));
handles.Cfg.SliceTiming.TA=handles.Cfg.TR-(handles.Cfg.TR/handles.Cfg.SliceTiming.SliceNumber);
guidata(hObject, handles);
UpdateDisplay(handles);

function editSliceOrder_Callback(hObject, eventdata, handles)
SliceOrder=get(hObject,'String');
handles.Cfg.SliceTiming.SliceOrder =eval(['[',SliceOrder,']']);
guidata(hObject, handles);
UpdateDisplay(handles);

function editReferenceSlice_Callback(hObject, eventdata, handles)
handles.Cfg.SliceTiming.ReferenceSlice =str2double(get(hObject,'String'));
guidata(hObject, handles);
UpdateDisplay(handles);

function checkboxRealign_Callback(hObject, eventdata, handles)
if get(hObject,'Value')
    handles.Cfg.IsRealign = 1;
else
    handles.Cfg.IsRealign = 0;
end
%handles=CheckCfgParameters(handles);
guidata(hObject, handles);
UpdateDisplay(handles);

function checkboxEPIMask_Callback(hObject, eventdata, handles)
if get(hObject,'Value')
    handles.Cfg.CreateGroupMask=1;
else
    handles.Cfg.CreateGroupMask=0;
end
%handles=CheckCfgParameters(handles);
guidata(hObject, handles);
UpdateDisplay(handles);

function checkboxAggressive_Callback(hObject, eventdata, handles)
if get(hObject,'Value')
    handles.Cfg.doAggressive=1;
else
    handles.Cfg.doAggressive=0;
end
%handles=CheckCfgParameters(handles);
guidata(hObject, handles);
UpdateDisplay(handles);

function checkbox_multisession_Callback(hObject, eventdata, handles)
if get(hObject,'Value')
    handles.Cfg.IsMultisession=1;
else
    handles.Cfg.IsMultisession=0;
end
handles.Cfg.SubjectID={};
handles=CheckCfgParameters(handles);
guidata(hObject, handles);
UpdateDisplay(handles);

function checkboxNormalize_Callback(hObject, eventdata, handles)
if get(hObject,'Value')
    if handles.Cfg.SPMver==8
        handles.Cfg.IsNormalize=2;
    else
        handles.Cfg.IsNormalize=3;
    end
else
    handles.Cfg.IsNormalize=0;
end
%handles=CheckCfgParameters(handles);
guidata(hObject, handles);
UpdateDisplay(handles);

function editBoundingBox_Callback(hObject, eventdata, handles)
BoundingBox=get(hObject,'String');
handles.Cfg.Normalize.BoundingBox =eval(['[',BoundingBox,']']);
guidata(hObject, handles);
UpdateDisplay(handles);

function editVoxSize_Callback(hObject, eventdata, handles)
VoxSize=get(hObject,'String');
handles.Cfg.Normalize.VoxSize =eval(['[',VoxSize,']']);
guidata(hObject, handles);
UpdateDisplay(handles);

function radiobuttonNormalize_EPI_Callback(hObject, eventdata, handles)
handles.Cfg.IsNormalize=1;
drawnow;
guidata(hObject, handles);
UpdateDisplay(handles);


function radiobuttonNormalizeMNI152_Callback(hObject, eventdata, handles)
handles.Cfg.isNormalizeMNI152=1;
set(handles.radiobuttonNormalizeCustom,'Value',0);
drawnow;
guidata(hObject, handles);
UpdateDisplay(handles);

function radiobuttonNormalizeCustom_Callback(hObject, eventdata, handles)
handles.Cfg.isNormalizeMNI152=0;
set(handles.radiobuttonNormalizeMNI152,'Value',0);
drawnow;
guidata(hObject, handles);
UpdateDisplay(handles);

function radiobuttonPolyOrd1_Callback(hObject, eventdata, handles)
handles.Cfg.DetrendPolyOrder=1;
set(handles.radiobuttonPolyOrd1,'Value',1);
set(handles.radiobuttonPolyOrd2,'Value',0);
set(handles.radiobuttonPolyOrd3,'Value',0);
drawnow;
guidata(hObject, handles);
UpdateDisplay(handles);

function radiobuttonPolyOrd2_Callback(hObject, eventdata, handles)
handles.Cfg.DetrendPolyOrder=2;
set(handles.radiobuttonPolyOrd1,'Value',0);
set(handles.radiobuttonPolyOrd2,'Value',1);
set(handles.radiobuttonPolyOrd3,'Value',0);
drawnow;
guidata(hObject, handles);
UpdateDisplay(handles);

function radiobuttonPolyOrd3_Callback(hObject, eventdata, handles)
handles.Cfg.DetrendPolyOrder=3;
set(handles.radiobuttonPolyOrd1,'Value',0);
set(handles.radiobuttonPolyOrd2,'Value',0);
set(handles.radiobuttonPolyOrd3,'Value',1);
drawnow;
guidata(hObject, handles);
UpdateDisplay(handles);

function radiobuttonNormalize_T1_Callback(hObject, eventdata, handles)
uiwait(msgbox({'Normalization by using the T1 image unified segmentation will include the following steps: 1. Individual structural image would be coregistered to the mean functional image after the motion correction. 2. The transformed structural images would be then segmented into gray matter, white matter, cerebrospinal fluid by using a unified segmentation algorithm. 3. The motion corrected functional volumes would be spatially normalized to the Montreal Neurological Institute (MNI) space and re-sampled using the normalization parameters estimated during unified segmentation';...
    '';...
    'Please arrange your structural images if you want to use normalization by using the T1 image unified segmentation:';...
    'For example, if you want fDPA convert the T1 DICOM images into NIFTI images first, you need to arrange each subject''s T1 DICOM images in one directory, and then put them in "T1Raw" directory under the working directory. i.e.:';...
    '{Working Directory}\T1Raw\Subject001\xxxxx001.dcm';...
    '{Working Directory}\T1Raw\Subject001\xxxxx002.dcm';...
    '...';...
    '{Working Directory}\T1Raw\Subject002\xxxxx001.dcm';...
    '{Working Directory}\T1Raw\Subject002\xxxxx002.dcm';...
    '...';...
    '...';...
    'If you start with T1 NIFTI images (.hdr/.img pairs) need not fDPA convert the DICOM images, you need to arrange each subject''s T1 NIFTI images in one directory under the working directory and specify the directory in the UI. You need to ensure the file name of T1 NIFTI image of each subject initiated with "co"! i.e.:';...
    '{Working Directory}\T1Img\Subject001\coxxxxx.img';...
    '...';...
    '{Working Directory}\T1Img\Subject002\coxxxxx.img';...
    '...';...
    '...';...
    '';...
    'Note: Some subjects may be segmented and normalized incorrectly by using the T1 image unified segmentation. Checking the results of normalization and segmentation is suggested. Moving the origo of the pictures close to the AC point helps.';...
    },'Normalize by using T1 image unified segmentation'));
handles.Cfg.IsNormalize=2;
set(handles.radiobuttonNormalize_EPI,'Value',0);
set(handles.radiobuttonNormalize_T1,'Value',1);
set(handles.radiobuttonNormalize_newT1,'Value',0);
set(handles.radiobuttonFSL,'Value',0);
set(handles.checkboxT1DICOM2NIFTI, 'Visible', 'on');
set(handles.textAffineRegularisation, 'Visible', 'on');
set(handles.radiobuttonEastAsian, 'Visible', 'on');
set(handles.radiobuttonEuropean, 'Visible', 'on');
drawnow;
guidata(hObject, handles);
UpdateDisplay(handles);

function radiobuttonNormalize_newT1_Callback(hObject, eventdata, handles)
uiwait(msgbox({'Normalization by using the T1 image new segmentation will include the following steps: 1. Individual structural image would be coregistered to the mean functional image after the motion correction. 2. The transformed structural images would be then segmented into gray matter, white matter, cerebrospinal fluid by using a unified segmentation algorithm. 3. The motion corrected functional volumes would be spatially normalized to the Montreal Neurological Institute (MNI) space and re-sampled using the normalization parameters estimated during unified segmentation';...
    '';...
    'Please arrange your structural images if you want to use normalization by using the T1 image unified segmentation:';...
    'For example, if you want fDPA convert the T1 DICOM images into NIFTI images first, you need to arrange each subject''s T1 DICOM images in one directory, and then put them in "T1Raw" directory under the working directory. i.e.:';...
    '{Working Directory}\T1Raw\Subject001\xxxxx001.dcm';...
    '{Working Directory}\T1Raw\Subject001\xxxxx002.dcm';...
    '...';...
    '{Working Directory}\T1Raw\Subject002\xxxxx001.dcm';...
    '{Working Directory}\T1Raw\Subject002\xxxxx002.dcm';...
    '...';...
    '...';...
    'If you start with T1 NIFTI images (.hdr/.img pairs) need not fDPA convert the DICOM images, you need to arrange each subject''s T1 NIFTI images in one directory under the working directory and specify the directory in the UI. You need to ensure the file name of T1 NIFTI image of each subject initiated with "co"! i.e.:';...
    '{Working Directory}\T1Img\Subject001\coxxxxx.img';...
    '...';...
    '{Working Directory}\T1Img\Subject002\coxxxxx.img';...
    '...';...
    '...';...
    '';...
    'Note: Some subjects may be segmented and normalized incorrectly. Checking the results of normalization and segmentation is suggested. Moving the origo of the pictures close to the AC point helps.';...
    },'Normalize by using T1 image unified segmentation'));
handles.Cfg.IsNormalize=3;
set(handles.radiobuttonNormalize_EPI,'Value',0);
set(handles.radiobuttonNormalize_T1,'Value',0);
set(handles.radiobuttonNormalize_newT1,'Value',1);
set(handles.radiobuttonFSL,'Value',0);
set(handles.checkboxT1DICOM2NIFTI, 'Visible', 'on');
set(handles.textAffineRegularisation, 'Visible', 'on');
set(handles.radiobuttonEastAsian, 'Visible', 'on');
set(handles.radiobuttonEuropean, 'Visible', 'on');
drawnow;
guidata(hObject, handles);
UpdateDisplay(handles);

function radiobuttonFSL_Callback(hObject, eventdata, handles)

if ~isunix()
    uiwait(msgbox({'FSL tools are available only in Linux/Unix environment :('},'FSL tools'));
else
    uiwait(msgbox({'Normalization by using the T1 image and FSL functions'; ...
	'Procedure is as follows:';...
	'1. Bias-field corrected T1 (FAST)';...
	'2. Skullstripped T1 (BET2)';...
	'3. Linear (affine) transformation T1->MNI152 (FLIRT)';...
	'4. Non-linear transformation T1->MNI152 (FNIRT)';...
	'5. Apply normalization (warping) for functional volumes (APPLYWARP)';...
    '!!NOTE!! You must manually set ''fsl_root_command'' in the beginning of fDPA.m';...
    'Example: your unix command for BET is ''fsl5.0-bet'', so you set ''fsl_root_command = ''fsl5.0-''';...
    'To speed up FSL computations, you should set FSL environmental parameter FSLOUTPUTTYPE into NIFTI_PAIR,';...
    'otherwise FSL image conversion tool is applied (slow for large EPI sets)';...
    },'Normalize with FSL'));
    if is_fsl()==1
        handles.Cfg.IsNormalize=4;
        handles.Cfg.isNormalizeMNI152=1;
        set(handles.radiobuttonNormalize_EPI,'Value',0);
        set(handles.radiobuttonNormalize_T1,'Value',0);
        set(handles.radiobuttonNormalize_newT1,'Value',0);
        set(handles.radiobuttonFSL,'Value',1);
        set(handles.checkboxT1DICOM2NIFTI, 'Visible', 'on');
        set(handles.textAffineRegularisation, 'Visible', 'on');
        set(handles.radiobuttonEastAsian, 'Visible', 'off');
        set(handles.radiobuttonEuropean, 'Visible', 'on');
    else
        warning('!!! FSL functions cannot be executed, check your FSL root command !!!');
    end
end
drawnow;
guidata(hObject, handles);
UpdateDisplay(handles);

function checkboxT1DICOM2NIFTI_Callback(hObject, eventdata, handles)
if get(hObject,'Value')
    handles.Cfg.IsNeedConvertT1DCM2IMG=1;
else
    handles.Cfg.IsNeedConvertT1DCM2IMG=0;
end
handles=CheckCfgParameters(handles);
guidata(hObject, handles);
UpdateDisplay(handles);

function radiobuttonEastAsian_Callback(hObject, eventdata, handles)  %Added by YAN Chao-Gan 091110. Use different Affine Regularisation in Segmentation: East Asian brains (eastern) or European brains (mni).
handles.Cfg.Normalize.AffineRegularisationInSegmentation='eastern';
set(handles.radiobuttonEastAsian,'Value',1);
set(handles.radiobuttonEuropean,'Value',0);
drawnow;
guidata(hObject, handles);
UpdateDisplay(handles);

function radiobuttonEuropean_Callback(hObject, eventdata, handles)  %Added by YAN Chao-Gan 091110. Use different Affine Regularisation in Segmentation: East Asian brains (eastern) or European brains (mni).
handles.Cfg.Normalize.AffineRegularisationInSegmentation='mni';
set(handles.radiobuttonEastAsian,'Value',0);
set(handles.radiobuttonEuropean,'Value',1);
drawnow;
guidata(hObject, handles);
UpdateDisplay(handles);

% New 09/11 /EP
function checkboxGotParams_Callback(hObject, eventdata, handles)
if get(hObject,'Value')
    handles.Cfg.GotParams=1;
    handles.Cfg.MoveOrigo = 0;
    %         set(handles.checkboxMoveOrigo, 'Value', 0);
    %         set(handles.checkboxMoveOrigo, 'Enable', 'off');
    %         set(handles.textMoveBack, 'Enable', 'off');
    %         set(handles.textMoveDown, 'Enable', 'off');
else
    handles.Cfg.GotParams=0;
end
%handles=CheckCfgParameters(handles);
guidata(hObject, handles);
UpdateDisplay(handles);

function checkbox_finalize_EPIs_Callback(hObject, eventdata, handles)
if get(hObject,'Value')
    handles.Cfg.FinalizeEPIs=1;
else
    handles.Cfg.FinalizeEPIs=0;
end
%handles=CheckCfgParameters(handles);
guidata(hObject, handles);
UpdateDisplay(handles);

% New 09/11 /EP
function checkboxDrifter_Callback(hObject, eventdata, handles)
if get(hObject,'Value')
    handles.Cfg.Drifter=1;
    uiwait(msgbox('Note: Requires at least 8 GB of memory'));
else
    handles.Cfg.Drifter=0;
end
%handles=CheckCfgParameters(handles);
guidata(hObject, handles);
UpdateDisplay(handles);

% New 05/11 /EP
function checkboxVolume_Callback(hObject, eventdata, handles)
if get(hObject,'Value')
    handles.Cfg.VolumeArtifactRemoval = 1;
    handles.Cfg.IsDetrend=1;
    %uiwait(msgbox('Please define the thresholds for removing volume artifacts. The function will use a movement threshold and a standard deviation threshold for deciding which volumes to remove. An std threshold of minimum between [Z-threshold] and [%-threshold*mean(data)/std(data)] will be selected.'));
else
    handles.Cfg.VolumeArtifactRemoval = 0;
end
guidata(hObject, handles);
UpdateDisplay(handles);

% New 05/11 /EP
function editPercentThresh_Callback(hObject, eventdata, handles)
handles.Cfg.PercentThresh =str2double(get(hObject,'String'));
handles.Cfg.PercentThresh=handles.Cfg.VolumeArtifactRemoval*handles.Cfg.PercentThresh;
guidata(hObject, handles);
UpdateDisplay(handles);

% New 05/11 /EP
function editZThresh_Callback(hObject, eventdata, handles)
handles.Cfg.ZThresh =str2double(get(hObject,'String'));
handles.Cfg.ZThresh=handles.Cfg.VolumeArtifactRemoval*handles.Cfg.ZThresh;
guidata(hObject, handles);
UpdateDisplay(handles);

% New 05/11 /EP
function editMvmtThresh_Callback(hObject, eventdata, handles)
handles.Cfg.MvmtThresh =str2double(get(hObject,'String'));
handles.Cfg.MvmtThresh=handles.Cfg.VolumeArtifactRemoval*handles.Cfg.MvmtThresh;
guidata(hObject, handles);
UpdateDisplay(handles);

function checkboxSmooth_Callback(hObject, eventdata, handles)
if get(hObject,'Value')
    handles.Cfg.IsSmooth = 1;
else
    handles.Cfg.IsSmooth = 0;
end
%handles=CheckCfgParameters(handles);
guidata(hObject, handles);
UpdateDisplay(handles);

function editFWHM_Callback(hObject, eventdata, handles)
FWHM=get(hObject,'String');
handles.Cfg.Smooth.FWHM =eval(['[',FWHM,']']);
guidata(hObject, handles);
UpdateDisplay(handles);


function editParallel_Callback(hObject, eventdata, handles)
val=get(hObject,'String');
handles.Cfg.requested_nworker =eval(['[',val,']']);
guidata(hObject, handles);
UpdateDisplay(handles);

%New 06/11 /EP
function setJobFile(hObject, handles, JFile)
if 2==exist(JFile,'file')
    handles.Cfg.ContrastsJobFile = JFile;
    guidata(hObject, handles);
    UpdateDisplay(handles);
end
handles=CheckCfgParameters(handles);
guidata(hObject, handles);
UpdateDisplay(handles);

% NEW 09/2012 YH --- Executes on button press in BiasCorrectmeanEPI.
function BiasCorrectmeanEPI_Callback(hObject, eventdata, handles)
if get(hObject,'Value')
    handles.Cfg.BiasCorrectmeanEPI = 1;
else
    handles.Cfg.BiasCorrectmeanEPI = 0;
end
%handles=CheckCfgParameters(handles);
guidata(hObject, handles);
UpdateDisplay(handles);


function checkboxDetrend_Callback(hObject, eventdata, handles)
if get(hObject,'Value')
    handles.Cfg.IsDetrend = 1;
else
    handles.Cfg.IsDetrend = 0;
end
%handles=CheckCfgParameters(handles);
guidata(hObject, handles);
UpdateDisplay(handles);

function ckboxFilter_Callback(hObject, eventdata, handles)
if get(hObject,'Value')
    handles.Cfg.IsFilter = 1;
else
    handles.Cfg.IsFilter = 0;
    handles.Cfg.IsDelDetrendedFiles = 0;
end
handles.Cfg.Filter.ASamplePeriod=handles.Cfg.TR;
handles.Cfg.Filter.AMaskFilename='';
handles.Cfg.Filter.AAddMeanBack='Yes'; %YAN Chao-Gan, 100420. %handles.Cfg.Filter.ARetrend='Yes';
%handles=CheckCfgParameters(handles);
guidata(hObject, handles);
UpdateDisplay(handles);

function edtBandLow_Callback(hObject, eventdata, handles)
handles.Cfg.Filter.AHighPass_LowCutoff =str2double(get(hObject,'String'));
guidata(hObject, handles);
UpdateDisplay(handles);

function edtBandHigh_Callback(hObject, eventdata, handles)
handles.Cfg.Filter.ALowPass_HighCutoff =str2double(get(hObject,'String'));
guidata(hObject, handles);
UpdateDisplay(handles);

function checkboxAFNI_Callback(hObject, eventdata, handles)

if isunix()
    handles.Cfg.IsAFNI = get(hObject,'Value');
else
    uiwait(msgbox({'AFNI tools are available only in Linux/Unix environment :('},'AFNI skullstrip'));
    handles.Cfg.IsAFNI = 0;
end
handles=CheckCfgParameters(handles);
guidata(hObject, handles);
UpdateDisplay(handles);

function checkboxDoManualAlignment_Callback(hObject, eventdata, handles)
handles.Cfg.IsManualAlignment = get(hObject,'Value');
%handles=CheckCfgParameters(handles);
guidata(hObject, handles);
UpdateDisplay(handles);

function checkboxManualSkullstrip_Callback(hObject, eventdata, handles)
handles.Cfg.IsManualSkullstrip = get(hObject,'Value');
%    handles=CheckCfgParameters(handles);
guidata(hObject, handles);
UpdateDisplay(handles);

function edtfAlffBandLow_Callback(hObject, eventdata, handles)
handles.Cfg.CalALFF.AHighPass_LowCutoff =str2double(get(hObject,'String'));
handles.Cfg.CalfALFF.AHighPass_LowCutoff=handles.Cfg.CalALFF.AHighPass_LowCutoff;
guidata(hObject, handles);

function edtfAlffBandHigh_Callback(hObject, eventdata, handles)
handles.Cfg.CalALFF.ALowPass_HighCutoff =str2double(get(hObject,'String'));
handles.Cfg.CalfALFF.ALowPass_HighCutoff=handles.Cfg.CalALFF.ALowPass_HighCutoff;
guidata(hObject, handles);

function editSourceDir_Callback(hObject, eventdata, handles)
handles.Cfg.SourceDir=get(hObject,'String');
handles=CheckCfgParameters(handles);
guidata(hObject, handles);
UpdateDisplay(handles);

% New 09/11 /EP
function checkboxNiiConversion_Callback(hObject, eventdata, handles)
if get(hObject,'Value')
    handles.Cfg.NiiConversion=1;
else
    handles.Cfg.NiiConversion=0;
end
%handles=CheckCfgParameters(handles);
guidata(hObject, handles);
UpdateDisplay(handles);

function pushbuttonHelp_Callback(hObject, eventdata, handles)
web('http://www.restfmri.net');

function pushbuttonSave_Callback(hObject, eventdata, handles)
[filename, pathname] = uiputfile({'*.mat'}, 'Save Parameters As');
Cfg=handles.Cfg;
save(['',pathname,filename,''], 'Cfg');

function handles=pushbuttonLoad_Callback(hObject, eventdata, handles)
[filename, pathname] = uigetfile({'*.mat'}, 'Load Parameters From');
if ischar(filename)
    load([pathname,filename]);
    SetLoadedData(hObject,handles,Cfg);
end

function SetLoadedData(hObject,handles, Cfg);
handles.Cfg=Cfg;
handles = checkSPMversion(handles);
guidata(hObject, handles);
UpdateDisplay(handles);

function pushbuttonQuit_Callback(hObject, eventdata, handles)
close(handles.figfDPAMain);

function pushbuttonRun_Callback(hObject, eventdata, handles)
[handles, CheckingPass]=CheckCfgParameters(handles);

if CheckingPass==0
    warning('No valid T1 data!')
    return
end

if handles.Cfg.hasFunData==0
    options.Interpreter = 'tex';
    % Include the desired Default answer
    options.Default = 'No';
    button = questdlg('Working EPI directory not set, proceed with T1?','Configuration parameters checking','Yes','No',options);
    if strcmp(button,'No')
        return;
    end   
end

StepConsecutiveChecking=[handles.Cfg.IsNeedConvertFunDCM2IMG,...
    handles.Cfg.IsNeedConvertFunDCM2IMG,...   %handles.Cfg.IsRemoveFirst10TimePoints %YAN Chao-Gan 090831: IsRemoveFirst10TimePoints has been changed to RemoveFirstTimePoints, this step is no longer necessary, thus replaced it with handles.Cfg.IsNeedConvertFunDCM2IMG to no longer interfere the checking.
    handles.Cfg.IsRealign,...
    handles.Cfg.IsNormalize,...
    handles.Cfg.IsDetrend,...
    handles.Cfg.IsFilter];
StepConsecutiveCheckingName={'EPI DICOM to NIFTI',...
    'Remove First Time Points',...  %YAN Chao-Gan 090831: This will no longer happen, since IsRemoveFirst10TimePoints has been changed to RemoveFirstTimePoints.
    'Realign',...
    'Normalize',...
    'Detrend',...
    'Filter'};
StepIndex=find(StepConsecutiveChecking);
if length(StepIndex)>=2
    StepMask=[zeros(1,StepIndex(1)-1),ones(1,StepIndex(end)-StepIndex(1)+1),zeros(1,length(StepConsecutiveChecking)-StepIndex(end))];
    StepDisConsecutive=(~StepConsecutiveChecking).*StepMask;
    if any(StepDisConsecutive)
        StepDisConsecutiveIndex=find(StepDisConsecutive);
        theMsg=[];
        for i=1:length(StepDisConsecutiveIndex)
            theMsg=[theMsg, ' "',StepConsecutiveCheckingName{StepDisConsecutiveIndex(i)},'" ']
        end
        theMsg =['The steps from "',StepConsecutiveCheckingName{StepIndex(1)},'" to "',StepConsecutiveCheckingName{StepIndex(end)},'" should be consecutive, you need to choose the following steps to ensure the continuity: ',theMsg,'.'];
        uiwait(msgbox(theMsg,'Configuration parameters checking','warn'));
        return
    end
end

RawBackgroundColor=get(handles.pushbuttonRun ,'BackgroundColor');
RawForegroundColor=get(handles.pushbuttonRun ,'ForegroundColor');
set(handles.pushbuttonRun ,'Enable', 'off','BackgroundColor', 'red','ForegroundColor','green');
Cfg=handles.Cfg; %Added by YAN Chao-Gan, 100130. Save the configuration parameters automatically.
Datetime=fix(clock); %Added by YAN Chao-Gan, 100130.
save([handles.Cfg.DataProcessDir,filesep,'fDPA_AutoSave_',num2str(Datetime(1)),'_',num2str(Datetime(2)),'_',num2str(Datetime(3)),'_',num2str(Datetime(4)),'_',num2str(Datetime(5)),'.mat'], 'Cfg'); %Added by YAN Chao-Gan, 100130.

[Error]=fDPA_run(handles.Cfg);

if ~isempty(Error)
    uiwait(msgbox(Error,'Errors were encountered while processing','error'));
end
set(handles.pushbuttonRun ,'Enable', 'on','BackgroundColor', RawBackgroundColor,'ForegroundColor',RawForegroundColor);
UpdateDisplay(handles);



%% Check if the configuration parameters is correct
function [handles, CheckingPass]=CheckCfgParameters(handles)
CheckingPass=0;

% if (handles.Cfg.IsNeedConvertFunDCM2IMG==1)
%     if 7==exist([handles.Cfg.WorkingDir,filesep,'FunRaw'],'dir')
%         handles.Cfg.StartingDirName='FunRaw';
%         if isempty (handles.Cfg.SubjectID)
%             Dir=dir([handles.Cfg.WorkingDir,filesep,'FunRaw']);
%             for i=3:length(Dir)
%                 handles.Cfg.SubjectID=[handles.Cfg.SubjectID;{Dir(i).name}];
%             end
%         end
%     else
%         warning('Please arrange each subject''s DICOM images in one directory, and then put them in "FunRaw" directory under the working directory!');
%         %uiwait(msgbox('Please arrange each subject''s DICOM images in one directory, and then put them in "FunRaw" directory under the working directory!','Configuration parameters checking','warn'));
%         %return
%     end
% else    
%     if 7==exist([handles.Cfg.WorkingDir,filesep,handles.Cfg.SourceDir],'dir')
%         handles.Cfg.StartingDirName='FunImg';
%         if isempty (handles.Cfg.SubjectID)
%             Dir=dir([handles.Cfg.WorkingDir,filesep,handles.Cfg.SourceDir]);
%             for i=3:length(Dir)
%                 handles.Cfg.SubjectID=[handles.Cfg.SubjectID;{Dir(i).name}];
%             end
%         end
%         
%         if ~(strcmpi(handles.Cfg.SourceDir,'T1Raw') || strcmpi(handles.Cfg.SourceDir,'T1Img')) %If not just use for VBM, check if the time points right.
%             DirImg=dir([handles.Cfg.WorkingDir,filesep,handles.Cfg.SourceDir,filesep,handles.Cfg.SubjectID{1},filesep,'*.img']);
%             if length(DirImg)~=(handles.Cfg.TimePoints) %YAN Chao-Gan 090922, %if length(DirImg)~=(handles.Cfg.TimePoints-handles.Cfg.RemoveFirstTimePoints)
%                 uiwait(msgbox(['The detected number of time points for subject "',handles.Cfg.SubjectID{1},'" is: ',num2str(length(DirImg)),'. This is different from the predefined number of time points: ',num2str(handles.Cfg.TimePoints),'. Please check your data!'],'Configuration parameters checking','warn'));
%                 return
%             end
%         end
%     else
%         warning('Please arrange each subject''s DICOM images in one directory, and then put them in "FunRaw" directory under the working directory!');
% %        uiwait(msgbox(['Please arrange each subject''s NIFTI images in one directory, and then put them in your defined source directory under the working directory!'],'Configuration parameters checking','warn'));
% %        return
%     end
% end %handles.Cfg.IsNeedConvertT1DCM2IMG


if handles.Cfg.IsMultisession==1
    k = 1;
    while true    
        if 7==exist([handles.Cfg.WorkingDir,filesep,'Session',num2str(k)],'dir')            
            fprintf('Found session %i!\n',k);
            k=k+1;
        else
            break;
        end            
    end
    handles.Cfg.Sessions = k-1;
    if k==0
        warning('Could not find any sessions! They should in folders ''Session1'', ''Session2'',...,''SessionN''');
        return;
    end
    MULTISESSION_PATH = [filesep,'Session1'];
else
    MULTISESSION_PATH = '';
end

if handles.Cfg.IsNormalize>1
    if (handles.Cfg.IsNeedConvertT1DCM2IMG==1)
        if 7==exist([handles.Cfg.WorkingDir,MULTISESSION_PATH,filesep,'T1Raw'],'dir')
            handles.Cfg.DataProcessDir = handles.Cfg.WorkingDir;
            if isempty(handles.Cfg.SubjectID)
                Dir=dir([handles.Cfg.WorkingDir,MULTISESSION_PATH,filesep,'T1Raw']);
                for i=3:length(Dir)
                    handles.Cfg.SubjectID=[handles.Cfg.SubjectID;{Dir(i).name}];
                end
            end
        else
            warning('Please arrange each subject''s T1 DICOM images in "T1Raw" directory under the working directory!');
            return
        end
    else
        if 7==exist([handles.Cfg.WorkingDir,MULTISESSION_PATH,filesep,'T1Img'],'dir')
            handles.Cfg.DataProcessDir = handles.Cfg.WorkingDir;
            if isempty(handles.Cfg.SubjectID)
                Dir=dir([handles.Cfg.WorkingDir,MULTISESSION_PATH,filesep,'T1Img']);
                for i=3:length(Dir)
                    handles.Cfg.SubjectID=[handles.Cfg.SubjectID;{Dir(i).name}];
                end
            end
        else
            warning('Please arrange each subject''s T1 images in "T1Img" directory under the working directory!');
            return
        end
    end
end

if (handles.Cfg.IsNeedConvertFunDCM2IMG==1)
    if 7==exist([handles.Cfg.DataProcessDir,MULTISESSION_PATH,filesep,'FunRaw'],'dir')
        handles.Cfg.StartingDirName='FunRaw';
        Dir=dir([handles.Cfg.DataProcessDir,MULTISESSION_PATH,filesep,'FunRaw']);
        a={};
        for i=3:length(Dir)
            a=[a;{Dir(i).name}];
        end
        if nnz(~ismember(handles.Cfg.SubjectID,a))>0
            warning('Functional data does not match T1 data!')
            handles.Cfg.hasFunData = 0;
        else
            if handles.Cfg.IsNormalize==1
                handles.Cfg.SubjectID = a;
            end
            handles.Cfg.hasFunData = 1;
        end
    else
        handles.Cfg.hasFunData=0;
    end
else
    if 7==exist([handles.Cfg.DataProcessDir,MULTISESSION_PATH,filesep,handles.Cfg.SourceDir],'dir')
        handles.Cfg.StartingDirName=handles.Cfg.SourceDir;
        Dir=dir([handles.Cfg.DataProcessDir,MULTISESSION_PATH,filesep,handles.Cfg.SourceDir]);
        a={};
        for i=3:length(Dir)
            a=[a;{Dir(i).name}];
        end
        if nnz(~ismember(handles.Cfg.SubjectID,a))>0
            warning('Functional data does not mach T1 data!')
            handles.Cfg.hasFunData = 0;
        else
            if handles.Cfg.IsNormalize==1
                handles.Cfg.SubjectID = a;
            end
            handles.Cfg.hasFunData = 1;
        end
    else
       handles.Cfg.hasFunData=0; 
    end
end

if handles.Cfg.TimePoints<0
    uiwait(msgbox('Please set the number of time points of your functional MRI data!','Configuration parameters checking','warn'));
    return
end

CheckingPass=1;
UpdateDisplay(handles);



%% Update All the uiControls' display on the GUI
function UpdateDisplay(handles)
set(handles.edtWorkingDir ,'String', handles.Cfg.WorkingDir);

if handles.Cfg.IsMultisession==1
    set(handles.checkbox_multisession,'Value', 1);
else
    set(handles.checkbox_multisession,'Value', 0);
end

if size(handles.Cfg.SubjectID,1)>0
    theOldIndex =get(handles.listSubjectID, 'Value');
    set(handles.listSubjectID, 'String',  handles.Cfg.SubjectID , 'Value', 1);
    theCount =size(handles.Cfg.SubjectID,1);
    if (theOldIndex>0) && (theOldIndex<= theCount)
        set(handles.listSubjectID, 'Value', theOldIndex);
    end
else
    set(handles.listSubjectID, 'String', '' , 'Value', 0);
end

if handles.Cfg.IsRemoveFirstTimePoints == 0
    handles.Cfg.RemoveFirstTimePoints = 0;
end

set(handles.checkboxAggressive, 'Value', handles.Cfg.doAggressive);
set(handles.checkboxEPIMask, 'Value', handles.Cfg.CreateGroupMask);
set(handles.checkboxDoManualAlignment, 'Value', handles.Cfg.IsManualAlignment);
set(handles.checkboxAFNI, 'Value', handles.Cfg.IsAFNI);
set(handles.checkboxManualSkullstrip, 'Value',  handles.Cfg.IsManualSkullstrip);

set(handles.editTimePoints ,'String', num2str(handles.Cfg.TimePoints));
set(handles.editTR ,'String', num2str(handles.Cfg.TR));
set(handles.ckboxEPIDICOM2NIFTI, 'Value', handles.Cfg.IsNeedConvertFunDCM2IMG);
% set(handles.editRemoveFirstTimePoints ,'String', num2str(handles.Cfg.RemoveFirstTimePoints));
% Revised by YAN Chao-Gan 091110. Add a checkbox to avoid forgeting to check this parameter.

if handles.Cfg.IsNeedConvertFunDCM2IMG==1
    set(handles.editSourceDir, 'Enable', 'off', 'String', handles.Cfg.SourceDir);
    set(handles.textSourceDir, 'Enable', 'off');
else
    set(handles.editSourceDir, 'Enable', 'on', 'String', handles.Cfg.SourceDir);
    set(handles.textSourceDir, 'Enable', 'on');
end

if handles.Cfg.IsRemoveFirstTimePoints==1
    set(handles.checkboxRemoveFirstTimePoints, 'Value', 1);
    set(handles.editRemoveFirstTimePoints, 'Enable', 'on', 'String', num2str(handles.Cfg.RemoveFirstTimePoints));
else
    set(handles.checkboxRemoveFirstTimePoints, 'Value', 0);
    set(handles.editRemoveFirstTimePoints, 'Enable', 'off', 'String', num2str(handles.Cfg.RemoveFirstTimePoints));
end

% New 05/11 /EP
if handles.Cfg.VolumeArtifactRemoval==1
    set(handles.checkboxVolume, 'Value', 1);
    set(handles.editPercentThresh, 'Enable', 'on', 'String', num2str(handles.Cfg.PercentThresh));
    set(handles.editZThresh, 'Enable', 'on', 'String', num2str(handles.Cfg.ZThresh));
    set(handles.editMvmtThresh, 'Enable', 'on', 'String', num2str(handles.Cfg.MvmtThresh));
else
    set(handles.checkboxVolume, 'Value', 0);
    set(handles.editPercentThresh, 'Enable', 'off', 'String', num2str(handles.Cfg.PercentThresh));
    set(handles.editZThresh, 'Enable', 'off', 'String', num2str(handles.Cfg.ZThresh));
    set(handles.editMvmtThresh, 'Enable', 'off', 'String', num2str(handles.Cfg.MvmtThresh));
end

if handles.Cfg.IsSliceTiming==1
    set(handles.checkboxSliceTiming, 'Value', 1);
    if ~handles.Cfg.SliceTiming.IsAutoSliceNumber
        set(handles.editSliceNumber, 'Enable', 'on', 'String', num2str(handles.Cfg.SliceTiming.SliceNumber));
    else
        set(handles.editSliceNumber, 'Enable', 'off', 'String', num2str(handles.Cfg.SliceTiming.SliceNumber));
    end
    if ~handles.Cfg.SliceTiming.IsInterleaved 
        set(handles.editSliceOrder, 'Enable', 'on', 'String', mat2str(handles.Cfg.SliceTiming.SliceOrder));
    else
        set(handles.editSliceOrder, 'Enable', 'off', 'String', mat2str(handles.Cfg.SliceTiming.SliceOrder));
    end
    if ~handles.Cfg.SliceTiming.IsMiddleReference
        set(handles.editReferenceSlice, 'Enable', 'on', 'String', num2str(handles.Cfg.SliceTiming.ReferenceSlice));
    else
        set(handles.editReferenceSlice, 'Enable', 'off', 'String', num2str(handles.Cfg.SliceTiming.ReferenceSlice));
    end
    set(handles.checkbox_slicenumber, 'Enable', 'on');
    set(handles.checkbox_sliceorder, 'Enable', 'on');
    set(handles.checkbox_slicereference, 'Enable','on');            
    
else
    set(handles.checkboxSliceTiming, 'Value', 0);
    set(handles.editSliceNumber, 'Enable', 'off', 'String', num2str(handles.Cfg.SliceTiming.SliceNumber));
    set(handles.editSliceOrder, 'Enable', 'off', 'String', mat2str(handles.Cfg.SliceTiming.SliceOrder));
    set(handles.editReferenceSlice, 'Enable', 'off', 'String', num2str(handles.Cfg.SliceTiming.ReferenceSlice));
    set(handles.checkbox_slicenumber, 'Enable', 'off');
    set(handles.checkbox_sliceorder, 'Enable', 'off');
    set(handles.checkbox_slicereference, 'Enable','off');
        
end

set(handles.checkbox_slicenumber,'Value',handles.Cfg.SliceTiming.IsAutoSliceNumber);
set(handles.checkbox_sliceorder,'Value',handles.Cfg.SliceTiming.IsInterleaved );
set(handles.checkbox_slicereference,'Value',handles.Cfg.SliceTiming.IsMiddleReference);

set(handles.editParallel,'String', num2str(handles.Cfg.requested_nworker));
set(handles.checkboxRealign, 'Value', handles.Cfg.IsRealign);
set(handles.BiasCorrectmeanEPI, 'Value', handles.Cfg.BiasCorrectmeanEPI);%YH 09/2012 trying to make sure the BIAS button remains on.

if handles.Cfg.IsDetrend==1
    set(handles.radiobuttonPolyOrd1,'Enable','on');
    set(handles.radiobuttonPolyOrd2,'Enable','on');
    set(handles.radiobuttonPolyOrd3,'Enable','on');
else
    set(handles.radiobuttonPolyOrd1,'Enable','off');
    set(handles.radiobuttonPolyOrd2,'Enable','off');
    set(handles.radiobuttonPolyOrd3,'Enable','off');
end

if handles.Cfg.DetrendPolyOrder==1
    set(handles.radiobuttonPolyOrd1,'Value',1);
    set(handles.radiobuttonPolyOrd2,'Value',0);
    set(handles.radiobuttonPolyOrd3,'Value',0);
elseif handles.Cfg.DetrendPolyOrder==2
    set(handles.radiobuttonPolyOrd1,'Value',0);
    set(handles.radiobuttonPolyOrd2,'Value',1);
    set(handles.radiobuttonPolyOrd3,'Value',0);
elseif handles.Cfg.DetrendPolyOrder==3
    set(handles.radiobuttonPolyOrd1,'Value',0);
    set(handles.radiobuttonPolyOrd2,'Value',0);
    set(handles.radiobuttonPolyOrd3,'Value',1);
else
    error('Polyorder has a wrong number')
end

if handles.Cfg.IsNormalize>0
    
    if handles.Cfg.IsNormalize==3
        handles.Cfg.isNormalizeMNI152=1;
    end    
    
    set(handles.checkbox_finalize_EPIs, 'Enable','on'); 
    if handles.Cfg.FinalizeEPIs==1
       set(handles.checkbox_finalize_EPIs, 'Value', 1); 
    else
       set(handles.checkbox_finalize_EPIs, 'Value', 0); 
    end
    
    set(handles.radiobuttonNormalizeMNI152, 'Enable', 'on');
    set(handles.radiobuttonNormalizeCustom, 'Enable', 'on');
    set(handles.checkboxNormalize, 'Value', 1);
    set(handles.editBoundingBox, 'Enable', 'on', 'String', mat2str(handles.Cfg.Normalize.BoundingBox));
    set(handles.editVoxSize, 'Enable', 'on', 'String', mat2str(handles.Cfg.Normalize.VoxSize));
    set(handles.radiobuttonNormalize_EPI,'Enable', 'on', 'Value',1==handles.Cfg.IsNormalize);
    set(handles.radiobuttonNormalize_T1,'Enable', 'on', 'Value',2==handles.Cfg.IsNormalize);
    set(handles.radiobuttonNormalize_newT1,'Enable', 'on', 'Value',3==handles.Cfg.IsNormalize);
    set(handles.radiobuttonFSL,'Enable', 'on', 'Value',4==handles.Cfg.IsNormalize);
    set(handles.BiasCorrectmeanEPI, 'Visible', 'on');
    
    if handles.Cfg.isNormalizeMNI152==1
        handles.Cfg.Normalize.BoundingBox=[-90 -126 -72;90 90 108];
        handles.Cfg.Normalize.VoxSize=[2,2,2];
        set(handles.editBoundingBox, 'Enable', 'on', 'String', mat2str(handles.Cfg.Normalize.BoundingBox));
        set(handles.editVoxSize, 'Enable', 'on', 'String', mat2str(handles.Cfg.Normalize.VoxSize));
        set(handles.radiobuttonNormalizeMNI152, 'Value', 1);
        set(handles.radiobuttonNormalizeCustom, 'Value', 0);
        set(handles.editBoundingBox, 'Enable', 'off');
        set(handles.editVoxSize, 'Enable', 'off');
    else
        set(handles.radiobuttonNormalizeCustom, 'Value', 1);
        set(handles.radiobuttonNormalizeMNI152, 'Value', 0);
        set(handles.editBoundingBox, 'Enable', 'on');
        set(handles.editVoxSize, 'Enable', 'on');
    end
    
    if handles.Cfg.IsNormalize>1
        
        set(handles.checkboxT1DICOM2NIFTI, 'Visible', 'on', 'Value', handles.Cfg.IsNeedConvertT1DCM2IMG);
        set(handles.textAffineRegularisation, 'Visible', 'on');
        set(handles.radiobuttonEastAsian,'Visible', 'on','Value',strcmpi(handles.Cfg.Normalize.AffineRegularisationInSegmentation,'eastern'));
        set(handles.radiobuttonEuropean,'Visible', 'on','Value',strcmpi(handles.Cfg.Normalize.AffineRegularisationInSegmentation,'mni'));
        
        %New 05/11 /EP
%         set(handles.editMoveBack, 'Visible', 'on', 'String', num2str(handles.Cfg.MoveBack));
%         set(handles.editMoveDown, 'Visible', 'on', 'String', num2str(handles.Cfg.MoveDown));
%         set(handles.editMoveBack, 'Enable', 'off', 'String', num2str(handles.Cfg.MoveBack));
%         set(handles.editMoveDown, 'Enable', 'off', 'String', num2str(handles.Cfg.MoveDown));
%         set(handles.checkboxGotParams, 'Visible', 'on');
%         set(handles.checkboxMoveOrigo, 'Visible', 'on');
%         set(handles.textMoveBack, 'Visible', 'on');
%         set(handles.textMoveDown, 'Visible', 'on');
        

        
    else
        %set(handles.checkboxT1DICOM2NIFTI, 'Visible', 'off', 'Value', handles.Cfg.IsNeedConvertT1DCM2IMG);
        set(handles.textAffineRegularisation, 'Visible', 'off');
        set(handles.radiobuttonEastAsian,'Visible', 'off','Value',strcmpi(handles.Cfg.Normalize.AffineRegularisationInSegmentation,'eastern'));
        set(handles.radiobuttonEuropean,'Visible', 'off','Value',strcmpi(handles.Cfg.Normalize.AffineRegularisationInSegmentation,'mni'));
        
        %New 05/11 /EP
        set(handles.editMoveBack, 'Visible', 'off', 'String', num2str(handles.Cfg.MoveBack));
        set(handles.editMoveDown, 'Visible', 'off', 'String', num2str(handles.Cfg.MoveDown));
        set(handles.checkboxGotParams, 'Visible', 'off');
        set(handles.checkboxMoveOrigo, 'Visible', 'off');
        set(handles.textMoveBack, 'Visible', 'off');
        set(handles.textMoveDown, 'Visible', 'off');
        
        handles.Cfg.IsNeedConvertT1DCM2IMG=0;
        set(handles.radiobuttonNormalize_EPI,'Value',1);
        set(handles.radiobuttonNormalize_T1,'Value',0);
        set(handles.radiobuttonNormalize_newT1,'Value',0);
        set(handles.radiobuttonFSL,'Value',0);
        set(handles.checkboxT1DICOM2NIFTI, 'Visible', 'off');
        set(handles.textAffineRegularisation, 'Visible', 'off');
        set(handles.radiobuttonEastAsian, 'Visible', 'off');
        set(handles.radiobuttonEuropean, 'Visible', 'off');
        
    end
else
    set(handles.checkbox_finalize_EPIs, 'Enable','off');    
    set(handles.checkboxNormalize, 'Value', 0);
    set(handles.editBoundingBox, 'Enable', 'off', 'String', mat2str(handles.Cfg.Normalize.BoundingBox));
    set(handles.editVoxSize, 'Enable', 'off', 'String', mat2str(handles.Cfg.Normalize.VoxSize));
    set(handles.radiobuttonNormalize_EPI,'Enable', 'off','Value',1==handles.Cfg.IsNormalize);
    set(handles.radiobuttonNormalize_T1,'Enable', 'off','Value',2==handles.Cfg.IsNormalize);
    set(handles.radiobuttonNormalize_newT1,'Enable', 'off','Value',3==handles.Cfg.IsNormalize);
    set(handles.radiobuttonFSL,'Enable', 'off','Value',4==handles.Cfg.IsNormalize);
    set(handles.checkboxT1DICOM2NIFTI, 'Visible', 'off', 'Value', handles.Cfg.IsNeedConvertT1DCM2IMG);
    set(handles.textAffineRegularisation, 'Visible', 'off');
    set(handles.radiobuttonEastAsian,'Visible', 'off','Value',strcmpi(handles.Cfg.Normalize.AffineRegularisationInSegmentation,'eastern'));
    set(handles.radiobuttonEuropean,'Visible', 'off','Value',strcmpi(handles.Cfg.Normalize.AffineRegularisationInSegmentation,'mni'));
    
    %New 05/11 /EP
    set(handles.editMoveBack, 'Visible', 'off', 'String', num2str(handles.Cfg.MoveBack));
    set(handles.editMoveDown, 'Visible', 'off', 'String', num2str(handles.Cfg.MoveDown));
    set(handles.checkboxGotParams, 'Visible', 'off');
    set(handles.checkboxMoveOrigo, 'Visible', 'off');
    set(handles.textMoveBack, 'Visible', 'off');
    set(handles.textMoveDown, 'Visible', 'off');
    set(handles.BiasCorrectmeanEPI, 'Visible', 'off');
    
    set(handles.radiobuttonNormalizeMNI152, 'Enable', 'off');
    set(handles.radiobuttonNormalizeCustom, 'Enable', 'off');
end

if handles.Cfg.SPMver==12
    set(handles.radiobuttonNormalize_T1, 'Enable', 'off');
    if handles.Cfg.IsNormalize==3
        set(handles.checkboxAggressive, 'Enable', 'on');
    else
        set(handles.checkboxAggressive, 'Enable', 'off');
    end
else
    set(handles.checkboxAggressive, 'Enable', 'off'); 
end

if handles.Cfg.IsSmooth==1
    set(handles.checkboxSmooth, 'Value', 1);
    set(handles.editFWHM, 'Enable', 'on', 'String', mat2str(handles.Cfg.Smooth.FWHM));
else
    set(handles.checkboxSmooth, 'Value', 0);
    set(handles.editFWHM, 'Enable', 'off', 'String', mat2str(handles.Cfg.Smooth.FWHM));
end

%     %New 06/11 /EP
%     if handles.Cfg.CalculateContrasts==1
% 		set(handles.checkboxCalculateContrasts, 'Value', 1);
%         set(handles.textJobFile, 'Visible', 'on');
%         set(handles.editContrastsJob, 'Visible', 'on');
%         set(handles.editContrastsJob, 'String', handles.Cfg.ContrastsJobFile);
%         set(handles.pushbuttonSelectContrastsJob, 'Visible', 'on');
%     else
% 		set(handles.checkboxCalculateContrasts, 'Value', 0);
%         set(handles.textJobFile, 'Visible', 'off');
%         set(handles.editContrastsJob, 'Visible', 'off');
%         set(handles.pushbuttonSelectContrastsJob, 'Visible', 'off');
%     end

set(handles.checkboxDetrend, 'Value', handles.Cfg.IsDetrend);

if handles.Cfg.IsFilter==1
    set(handles.ckboxFilter, 'Value', 1);
    set(handles.edtBandLow, 'Enable', 'on', 'String', num2str(handles.Cfg.Filter.AHighPass_LowCutoff));
    set(handles.edtBandHigh, 'Enable', 'on', 'String', num2str(handles.Cfg.Filter.ALowPass_HighCutoff));
else
    set(handles.ckboxFilter, 'Value', 0);
    set(handles.edtBandLow, 'Enable', 'off', 'String', num2str(handles.Cfg.Filter.AHighPass_LowCutoff));
    set(handles.edtBandHigh, 'Enable', 'off', 'String', num2str(handles.Cfg.Filter.ALowPass_HighCutoff));
end

%
%     if handles.Cfg.IsCovremove==1
%         set(handles.checkboxCovremove, 'Value', 1);
%         set(handles.checkboxCovremoveHeadMotion, 'Enable', 'on', 'Value', handles.Cfg.Covremove.HeadMotion);
%         set(handles.checkboxCovremoveWholeBrain, 'Enable', 'on', 'Value', handles.Cfg.Covremove.WholeBrain);
%         set(handles.checkboxCovremoveWhiteMatter, 'Enable', 'on', 'Value', handles.Cfg.Covremove.WhiteMatter);
%         set(handles.checkboxCovremoveCSF, 'Enable', 'on', 'Value', handles.Cfg.Covremove.CSF);
%         set(handles.checkboxOtherCovariates, 'Enable', 'on', 'Value', ~isempty(handles.Cfg.Covremove.OtherCovariatesROI));
%     else
%         set(handles.checkboxCovremove, 'Value', 0);
%         set(handles.checkboxCovremoveHeadMotion, 'Enable', 'off', 'Value', handles.Cfg.Covremove.HeadMotion);
%         set(handles.checkboxCovremoveWholeBrain, 'Enable', 'off', 'Value', handles.Cfg.Covremove.WholeBrain);
%         set(handles.checkboxCovremoveWhiteMatter, 'Enable', 'off', 'Value', handles.Cfg.Covremove.WhiteMatter);
%         set(handles.checkboxCovremoveCSF, 'Enable', 'off', 'Value', handles.Cfg.Covremove.CSF);
%         set(handles.checkboxOtherCovariates, 'Enable', 'off', 'Value', ~isempty(handles.Cfg.Covremove.OtherCovariatesROI));
%     end
%
%     if (handles.Cfg.IsExtractRESTdefinedROITC==1) || (handles.Cfg.IsCalFC==1)
%         set(handles.checkboxExtractRESTdefinedROITC, 'Value', handles.Cfg.IsExtractRESTdefinedROITC);
%         set(handles.checkboxCalFC, 'Value', handles.Cfg.IsCalFC);
%         set(handles.pushbuttonDefineROI, 'Enable', 'on');
%     else
%         set(handles.checkboxExtractRESTdefinedROITC, 'Value', handles.Cfg.IsExtractRESTdefinedROITC);
%         set(handles.checkboxCalFC, 'Value', handles.Cfg.IsCalFC);
%         set(handles.pushbuttonDefineROI, 'Enable', 'off');
%     end

%    set(handles.checkboxExtractAALTC, 'Value', handles.Cfg.IsExtractAALTC);
set(handles.editSourceDir ,'String', handles.Cfg.SourceDir);
set(handles.checkboxDrifter, 'Value', handles.Cfg.Drifter);
set(handles.checkboxNiiConversion, 'Value', handles.Cfg.NiiConversion);

drawnow;





function res = is_fsl()
%IS_FSL Summary of this function goes here
%   Detailed explanation goes here

global fsl_root_command;

res = 1;

str = [fsl_root_command,'bet'];
[status,message]=unix(str);
if status>126
    disp(message);
    warning('command ''%s'' cannot be executed\n',str)
    res=0;
end

str = [fsl_root_command,'fast'];
[status,message]=unix(str);
if status>126
    disp(message);
    warning('command ''%s'' cannot be executed\n',str)
    res=0;
end

str = [fsl_root_command,'flirt'];
[status,message]=unix(str);
if status>126
    disp(message);
    warning('command ''%s'' cannot be executed\n',str)
    res=0;
end

str = [fsl_root_command,'fnirt'];
[status,message]=unix(str);
if status>126
    disp(message);
    warning('command ''%s'' cannot be executed\n',str)
    res=0;
end

str = [fsl_root_command,'fslchfiletype'];
[status,message]=unix(str);
if status>126
    disp(message);
    warning('command ''%s'' cannot be executed\n',str)
    res=0;
end

str = [fsl_root_command,'applywarp'];
[status,message]=unix(str);
if status>126
    disp(message);
    warning('command ''%s'' cannot be executed\n',str)
    res=0;
end


function res = cell2str(celldata)

N=length(celldata);
res = '';
for i=1:N
    if ischar(celldata{i})
        if i==1
            res=celldata{i};
        else
            res=[res,',',celldata{i}];
        end
    else
        warning('Celldata contains other than strings!')
        res=-1;
        return;
    end
    if i>50
        res=[res,'.....'];
        return;
    end
end

function handles = checkSPMversion(handles)

if ~(exist('spm.m'))
    uiwait(msgbox('fDPA is based on SPM8 or SPM12, please install either one','fDPA'));
    handles.Cfg.SPMver = -1;
else
    SPMversion=spm('Ver');
    if strcmp('SPM8',SPMversion)
        fprintf('\n\nDetected SPM version is 8\n\n');
        handles.Cfg.SPMver = 8;
    elseif strcmp('SPM12',SPMversion)
        fprintf('\n\nDetected SPM version is 12\n\n');
        handles.Cfg.SPMver = 12;
        handles.Cfg.IsNormalize=3;
    else
        fprintf('\n\nDetected SPM version must be 8 or 12\n\n');
        error('fDPA is based on SPM8 or SPM12, please install either one');
    end
end


function create_EPI_preview(ID,EPI_path)

clear global

global DPARSF_rest_sliceviewer_Cfg;

% Create EPI preview figures separately
[ProgramPath, fileN, extn] = fileparts(which('fDPA_run.m'));
if isempty(ProgramPath)
    uiwait(msgbox('fDPA program path not found! It should be loaded.','program path setup'));
    return
end
addpath([ProgramPath,filesep,'Subfunctions']);
addpath([ProgramPath,filesep,'Subfunctions',filesep,'ArtRepair']);
addpath([ProgramPath,filesep,'Subfunctions',filesep,'NIFTI_20121012']);
addpath([ProgramPath,filesep,'Subfunctions',filesep,'REST_V1.4_100426']);
addpath([ProgramPath,filesep,'Subfunctions',filesep,'export_fig_tool']);

[a, fileN, extn] = fileparts(which('rest_misc.m'));
if isempty(a)
    uiwait(msgbox('REST not found! It should be loaded.','program path setup'));
    return
end
[a, fileN, extn] = fileparts(which('rest_detrend.m'));
if isempty(a)
    uiwait(msgbox('REST not found! It should be loaded.','program path setup'));
    return
end
[a, fileN, extn] = fileparts(which('art_global_ep.m'));
if isempty(a)
    uiwait(msgbox('ARTREPAIR not found! It should be loaded.','program path setup'));
    return
end
[a, fileN, extn] = fileparts(which('export_fig.m'));
if isempty(a)
    uiwait(msgbox('Export figure (export_fig) toolbox not found! It should be loaded.','program path setup'));
    return
end

if nargin<2
    EPI_path=pwd;
end

if ~exist(EPI_path,'dir')
    error('Path does not exist!')
end

home = pwd;
close all force;

if license('test','image_toolbox') % Added by YAN Chao-Gan, 100420.        
    
    try
        
        h=DPARSF_rest_sliceviewer;
        [RESTPath, fileN, extn] = fileparts(which('rest.m'));
        Ch2Filename=[RESTPath,filesep,'Template',filesep,'ch2.nii'];
        set(DPARSF_rest_sliceviewer_Cfg.Config(1).hOverlayFile, 'String', Ch2Filename);
        DPARSF_rest_sliceviewer_Cfg.Config(1).Overlay.Opacity=0.2;
        DPARSF_rest_sliceviewer('ChangeOverlay', h);

        cd(EPI_path);
        Dir=dir('*.img');        
        Filename=[pwd,filesep,Dir(1).name];
        cd(home);
        
        fDPA_Normalized_TempImage =fullfile(tempdir,['DPARSF_Normalized_TempImage','_',rest_misc('GetCurrentUser'),'.img']);
        y_Reslice(Filename,fDPA_Normalized_TempImage,[1 1 1],0)
        set(DPARSF_rest_sliceviewer_Cfg.Config(1).hUnderlayFile, 'String', fDPA_Normalized_TempImage);
        set(DPARSF_rest_sliceviewer_Cfg.Config(1).hMagnify ,'Value',2);
        DPARSF_rest_sliceviewer('ChangeUnderlay', h);
        eval(['print(''-dtiff'',''-r300'',''',ID,'.tif'',h);']);
        fprintf(['Generating the pictures for checking normalization (EPI): ',ID,' OK\n']);
        
        close(h);
        fprintf('\n');
    catch err
        warning('Failed to create DPARSF EPI check: %s',err.message);
    end
    
    try
        [RESTPath, fileN, extn] = fileparts(which('rest.m'));
        Ch2Filename=[RESTPath,filesep,'Template',filesep,'ch2.nii'];
        nii=load_nii(Ch2Filename);
        mat_base=nii.img;
        
        cd(EPI_path);
        Dir=dir('*.img');        
        Filename=[pwd,filesep,Dir(1).name];
        cd(home);
        
        fDPA_Normalized_TempImage =fullfile(tempdir,['DPARSF_Normalized_TempImage','_',rest_misc('GetCurrentUser'),'.img']);
        y_Reslice(Filename,fDPA_Normalized_TempImage,[1 1 1],0);
        nii=load_nii(fDPA_Normalized_TempImage);
        mat=nii.img;
        tit=['Subject ',ID,' first EPI volume'];
        save_EPI_preview(mat_base,mat,...
            tit,...
            [ID,'_EPI_vol1.tiff']);
        fprintf(['Generating the pictures for checking normalization (EPI): ',ID,' OK\n']);
        
        clear mat_base mat
        
    catch err
        warning('Failed to create multislice EPI check: %s',err.message);
    end
    
end

cd(home)

end

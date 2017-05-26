function create_EPI_T1_preview(ID,EPI_file,T1_file,outpath)

clear global

if nargin<4
    outpath=[];
end

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

home = pwd;
close all force;

if license('test','image_toolbox') % Added by YAN Chao-Gan, 100420.        
    
%     try
%         
%         h=DPARSF_rest_sliceviewer;
% 
%         fDPA_Normalized_TempImage1 =fullfile(tempdir,['DPARSF_Normalized_TempImage1','_',rest_misc('GetCurrentUser'),'.img']);
%         y_Reslice(T1_file,fDPA_Normalized_TempImage1,[1 1 1],0);        
%         
%         set(DPARSF_rest_sliceviewer_Cfg.Config(1).hOverlayFile, 'String', fDPA_Normalized_TempImage1);
%         DPARSF_rest_sliceviewer_Cfg.Config(1).Overlay.Opacity=0.2;
%         DPARSF_rest_sliceviewer('ChangeOverlay', h);
%        
%         fDPA_Normalized_TempImage2 =fullfile(tempdir,['DPARSF_Normalized_TempImage2','_',rest_misc('GetCurrentUser'),'.img']);
%         y_Reslice(EPI_file,fDPA_Normalized_TempImage2,[1 1 1],0)
%         set(DPARSF_rest_sliceviewer_Cfg.Config(1).hUnderlayFile, 'String', fDPA_Normalized_TempImage2);
%         
%         set(DPARSF_rest_sliceviewer_Cfg.Config(1).hMagnify ,'Value',2);
%         DPARSF_rest_sliceviewer('ChangeUnderlay', h);
%         eval(['print(''-dtiff'',''-r300'',''',[outpath,filesep,ID],'.tif'',h);']);
%         fprintf(['Generating the pictures for checking normalization (EPI): ',ID,' OK\n']);
%         
%         close(h);
%         fprintf('\n');
%     catch err
%         warning('Failed to create DPARSF EPI check: %s',err.message);
%     end
%     
    try

        fDPA_Normalized_TempImage2 =fullfile(tempdir,['tempfile1','_',rest_misc('GetCurrentUser'),'.img']);
        reslice_nii(EPI_file, fDPA_Normalized_TempImage2,[1,1,1],0,[],1,1,[]);
        nii=load_nii(fDPA_Normalized_TempImage2);
        mat_EPI=nii.img;               
        
        fDPA_Normalized_TempImage1 =fullfile(tempdir,['tempImage2','_',rest_misc('GetCurrentUser'),'.img']);
        reslice_nii(T1_file, fDPA_Normalized_TempImage2,[1,1,1],0,[],1,1,[]);
        nii=load_nii(fDPA_Normalized_TempImage1);
        mat_base=nii.img;                  
               
        tit=['Subject ',ID,' first EPI volume'];
        save_EPI_preview_unnormalized(mat_base,mat_EPI,...
            tit,...
            [outpath,filesep,ID,'_EPI_T1_vol1.tiff']);
        fprintf(['Generating the pictures for checking EPI-T1 registration: ',ID,' OK\n']);
        
        clear mat_base mat
        
    catch err
        warning('Failed to create multislice EPI check: %s',err.message);
    end
    
end

cd(home)

end

function [Error]=fDPA_run(AutoDataProcessParameter)

% Original version written by YAN Chao-Gan 090306.
% State Key Laboratory of Cognitive Neuroscience and Learning, Beijing Normal University, China, 100875
% ycg.yan@gmail.com
% Modified by YAN Chao-Gan 090712, added the function of mReHo - 1, mALFF - 1, mfALFF -1.
% Modified by YAN Chao-Gan 090901, added the function of smReHo, remove variable first time points.
% Modified by YAN Chao-Gan, 090925, SPM8 compatible.
% Modified by YAN Chao-Gan 091001, Generate the pictures for checking normalization.
% Modified by YAN Chao-Gan 091111. 1. Use different Affine Regularisation in Segmentation: East Asian brains (eastern) or European brains (mni). 2. Added a checkbox for removing first time points. 3.Added popup menu to delete selected subject by right click. 4. Close wait bar when program finished.
% Modified by YAN Chao-Gan 091212. Also can regress out other covariates.
% Modified by YAN Chao-Gan 100201. Fixed the bug in converting DICOM files to NIfTI files when DPARSF stored under C:\Program Files\Matlab\Toolbox.
% Modified by YAN Chao-Gan, 100420. Release the memory occupied by "hdr" after converting one participant's Functional DICOM files to NIFTI images in linux. Make compatible with missing parameters. Fixed a bug in generating the pictures for checking normalizationdisplaying when overlay with different bounding box from those of underlay in according to rest_sliceviewer.m.
% Modified by YAN Chao-Gan, 100510. Fixed a bug in converting DICOM files to NIfTI in Windows 7, thanks to Prof. Chris Rorden's new dcm2nii. Now will detect if co* T1 image is exist before normalization by using T1 image unified segmentation.
% Modified by YAN Chao-Gan, 101025. Fixed a bug in copying *.ps files.
% Modified by Eerik Puska & Yevhen Hlushchuk (Aalto University),
% 05-09/2011. Added functionalities for removing volumes in case of
% artifacts, moving origo in pictures in order to make segmentation work
% better, compensation for heartbeat and respiration,
% and calculating contrasts. Made handling directory structures
% more flexible. Made realign use "only mean image" setting. Now also
% normalizes T1 images. Also some various other fixes.

[ProgramPath, fileN, extn] = fileparts(which('fDPA_run.m'));
if isempty(ProgramPath)
    uiwait(msgbox('fDPA program path not found! It should be loaded.','program path setup'));
    return
end
AutoDataProcessParameter.SubjectNum=length(AutoDataProcessParameter.SubjectID);
Error=[];
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
[a, fileN, extn] = fileparts(which('art_global.m'));
if isempty(a)
    uiwait(msgbox('ARTREPAIR not found! It should be loaded.','program path setup'));
    return
end
[a, fileN, extn] = fileparts(which('export_fig.m'));
if isempty(a)
    uiwait(msgbox('Export figure (export_fig) toolbox not found! It should be loaded.','program path setup'));
    return
end

SPMversion=AutoDataProcessParameter.SPMver;
[SPMPath, ~, ~] = fileparts(which('spm.m'));

set(0,'units','pixels');
SPM_screensize = spm('WinSize','0',1);

warning('off','MATLAB:RandStream:ActivatingLegacyGenerators');
warning('off','MATLAB:hg:WillBeRemovedReplaceWith');

AllTargetDirs={};

%Make compatible with missing parameters. YAN Chao-Gan, 100420.

if ~isfield(AutoDataProcessParameter,'IsMultisession')
    AutoDataProcessParameter.IsMultisession=0;
    AutoDataProcessParameter.Sessions = 1;
end
% if ~isfield(AutoDataProcessParameter,'ComputeDVARS')
%     AutoDataProcessParameter.ComputeDVARS=0;
% end
if ~isfield(AutoDataProcessParameter,'IsSmooth')
    AutoDataProcessParameter.IsSmooth=0;
end
if ~isfield(AutoDataProcessParameter,'IsDetrend')
    AutoDataProcessParameter.IsDetrend=0;
end
if ~isfield(AutoDataProcessParameter,'IsFilter')
    AutoDataProcessParameter.IsFilter=0;
end
if ~isfield(AutoDataProcessParameter,'FinalizeEPIs')
     AutoDataProcessParameter.FinalizeEPIs=0;
end
if ~isfield(AutoDataProcessParameter,'IsT1Segment')
    AutoDataProcessParameter.IsT1Segment=0;
end
if ~isfield(AutoDataProcessParameter,'Drifter')
    AutoDataProcessParameter.Drifter=0;
end
if ~isfield(AutoDataProcessParameter,'BiasCorrectmeanEPI')
    AutoDataProcessParameter.BiasCorrectmeanEPI=1; % using Bias correction of EPI by default...YH 2012/09/18
end
if strcmpi(AutoDataProcessParameter.Normalize.AffineRegularisationInSegmentation,'mni')
    regtype='mni';
else
    regtype='eastern';
end

% create local cluster
if AutoDataProcessParameter.requested_nworker>1
    fprintf('Creating a worker pool...\n')
    AutoDataProcessParameter.available_nworker = open_pool(AutoDataProcessParameter.requested_nworker);
    fprintf('\nPool has %i workers\n',AutoDataProcessParameter.available_nworker);
    use_parallel = 1;
else
    AutoDataProcessParameter.available_nworker = 1;
    use_parallel = 0;
end

if AutoDataProcessParameter.IsMultisession==1
    MULTISESSION_PREFIX = [filesep,'Session1'];
    for i=1:AutoDataProcessParameter.Sessions
        SESSION_PREFIX{i}=[filesep,'Session',num2str(i)];
    end
else
    AutoDataProcessParameter.Sessions=1;
    MULTISESSION_PREFIX = '';
    SESSION_PREFIX{1}='';
end

original_fig_handles = findall(0,'Type','figure');

%Convert T1 DICOM files to NIFTI images
if (AutoDataProcessParameter.IsNeedConvertT1DCM2IMG==1)
    fprintf('------------- DICOM to NIFTI conversion T1 -----------------\n')
    cd([AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1Raw']);
    for i=1:AutoDataProcessParameter.SubjectNum
        OutputDir=[AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1Img',filesep,AutoDataProcessParameter.SubjectID{i}];
        
        if exist(OutputDir,'dir')
            oldFiles=give_filelist([OutputDir,filesep,'*.img']);%dir([OutputDir,filesep,'*.img']);            
            if ~isempty(oldFiles)
                fprintf('Old T1 *.img files found for %s -- deleting them all!\n',AutoDataProcessParameter.SubjectID{i});
                for k=1:length(oldFiles)
                    delete([OutputDir,filesep,oldFiles(k).name]);
                    delete([OutputDir,filesep,oldFiles(k).name(1:(end-3)),'hdr']);
                end
            end
        else
            mkdir(OutputDir);
        end
        DirDCM=dir([AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1Raw',filesep,AutoDataProcessParameter.SubjectID{i},filesep,'*']); %Revised by YAN Chao-Gan 100130. %DirDCM=dir([AutoDataProcessParameter.DataProcessDir,filesep,'T1Raw',filesep,AutoDataProcessParameter.SubjectID{i},filesep,'*.*']);
        InputFilename=[AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1Raw',filesep,AutoDataProcessParameter.SubjectID{i},filesep,DirDCM(3).name];
        OldDirTemp=pwd; %Added by YAN Chao-Gan 100130.
        cd([ProgramPath,filesep,'dcm2nii']); %Revised by YAN Chao-Gan 100510. %cd([ProgramPath,filesep,'MRIcroN']);
        if ispc
            %eval(['!dcm2nii.exe -o ',OutputDir,' ',InputFilename]); %Revised by YAN Chao-Gan 100130. %eval(['!',ProgramPath,filesep,'MRIcroN',filesep,'dcm2nii.exe -o ',OutputDir,' ',InputFilename]);
            %YAN Chao-Gan 100506
            eval(['!dcm2nii.exe -b dcm2nii.ini -o "',OutputDir,'" "',InputFilename,'"']);
        else
            eval(['!chmod +x dcm2nii_linux']); %Revised by YAN Chao-Gan 100130. %eval(['!chmod +x ',ProgramPath,filesep,'MRIcroN',filesep,'dcm2nii_linux']);
            eval(['!./dcm2nii_linux -b ./dcm2nii_linux.ini -o "',OutputDir,'" "',InputFilename,'"']); %Revised by YAN Chao-Gan 100130. %eval(['!',ProgramPath,filesep,'MRIcroN',filesep,'dcm2nii_linux -a N -d Y -e Y -f N -g N -i Y -n N -p Y -s N -v Y -o ',OutputDir,' ',InputFilename]);
            %eval(['!dcm2nii_linux -a N -d Y -e Y -f N -g N -i Y -n N -p Y -s N -v Y -o ',OutputDir,' ',InputFilename]); %Revised by YAN Chao-Gan 100130. %eval(['!',ProgramPath,filesep,'MRIcroN',filesep,'dcm2nii_linux -a N -d Y -e Y -f N -g N -i Y -n N -p Y -s N -v Y -o ',OutputDir,' ',InputFilename]);
        end
        cd(OldDirTemp); %Added by YAN Chao-Gan 100130.
        fprintf(['Converting T1 Images:',AutoDataProcessParameter.SubjectID{i},' OK\n']);
    end
    fprintf('\n');
else
    if (AutoDataProcessParameter.IsNormalize>1)
        fprintf('------------- Orienting and cropping T1 -----------------\n')
        cd([AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1Img']);
        for i=1:AutoDataProcessParameter.SubjectNum
            OutputDir=[AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1Img',filesep,AutoDataProcessParameter.SubjectID{i}];
            
            DirDCM=give_filelist([OutputDir,filesep,'co*.img']);
            if ~isempty(DirDCM)
                fprintf('co*.img already found, skipping\n')
            else
                DirDCM=give_filelist([OutputDir,filesep,'*.img']); %Revised by YAN Chao-Gan 100130. %DirDCM=dir([AutoDataProcessParameter.DataProcessDir,filesep,'T1Raw',filesep,AutoDataProcessParameter.SubjectID{i},filesep,'*.*']);
                InputFilename=[AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1Img',filesep,AutoDataProcessParameter.SubjectID{i},filesep,DirDCM(1).name];
                
                OldDirTemp=pwd; %Added by YAN Chao-Gan 100130.
                cd([ProgramPath,filesep,'dcm2nii']); %Revised by YAN Chao-Gan 100510. %cd([ProgramPath,filesep,'MRIcroN']);
                if ispc
                    %eval(['!dcm2nii.exe -o ',OutputDir,' ',InputFilename]); %Revised by YAN Chao-Gan 100130. %eval(['!',ProgramPath,filesep,'MRIcroN',filesep,'dcm2nii.exe -o ',OutputDir,' ',InputFilename]);
                    %YAN Chao-Gan 100506
                    eval(['!dcm2nii.exe -a N -d Y -e Y -f N -g N -i Y -m N -n N -x Y -p Y -s N -v Y -o ',OutputDir,' ',InputFilename]); %Revised by YAN Chao-Gan 100130. %eval(['!',ProgramPath,filesep,'MRIcroN',filesep,'dcm2nii_linux -a N -d Y -e Y -f N -g N -i Y -n N -p Y -s N -v Y -o ',OutputDir,' ',InputFilename]);
                else
                    eval(['!chmod +x dcm2nii_linux']); %Revised by YAN Chao-Gan 100130. %eval(['!chmod +x ',ProgramPath,filesep,'MRIcroN',filesep,'dcm2nii_linux']);
                    %eval(['!./dcm2nii_linux -n N -x Y -o ',OutputDir,' ',InputFilename]); %Revised by YAN Chao-Gan 100130. %eval(['!',ProgramPath,filesep,'MRIcroN',filesep,'dcm2nii_linux -a N -d Y -e Y -f N -g N -i Y -n N -p Y -s N -v Y -o ',OutputDir,' ',InputFilename]);
                    eval(['!./dcm2nii_linux -a N -d Y -e Y -f N -g N -i Y -m N -n N -x Y -p Y -s N -v Y -o "',OutputDir,'" "',InputFilename,'"']); %Revised by YAN Chao-Gan 100130. %eval(['!',ProgramPath,filesep,'MRIcroN',filesep,'dcm2nii_linux -a N -d Y -e Y -f N -g N -i Y -n N -p Y -s N -v Y -o ',OutputDir,' ',InputFilename]);
                end
                cd(OldDirTemp); %Added by YAN Chao-Gan 100130.
                
                [a,b,c]=fileparts(InputFilename);
                
                cd(AutoDataProcessParameter.SubjectID{i});
                s1 = [a,filesep,'co',b,c];
                if 2~=exist(s1,'file')
                    fprintf('No co*.img found\n');
                    s2 = [a,filesep,'o',b,c];
                    s3 = [a,filesep,'c',b,c];
                    if 2~=exist(s2,'file') && 2~=exist(s3,'file')
                        fprintf('No c*.img OR o*.img found\n');
                        copyfile(InputFilename,s1);
                        copyfile([InputFilename(1:end-4),'.hdr'],[s1(1:end-4),'.hdr']);
                    elseif 2==exist(s2,'file') && 2~=exist(s3,'file')
                        fprintf('o*.img found\n');
                        copyfile(s2,s1);
                        copyfile([s2(1:end-4),'.hdr'],[s1(1:end-4),'.hdr']);
                    elseif 2~=exist(s2,'file') && 2==exist(s3,'file')
                        fprintf('c*.img found\n');
                        copyfile(s3,s1);
                        copyfile([s3(1:end-4),'.hdr'],[s1(1:end-4),'.hdr']);
                    else
                        error('Weird situation with c* and o* files (BOTH EXIST)')
                    end
                end
                cd ..
            end
            
            fprintf(['Converting T1 Images:',AutoDataProcessParameter.SubjectID{i},' OK\n\n']);
        end
        fprintf('\n');
    end
end

spm('defaults','fmri');
spm_jobman('initcfg');
set(0,'units','pixels');

% Janne K. 15.1.2014
%Reorient T1 Image Interactively (OPTIONAL)
if (AutoDataProcessParameter.IsManualAlignment==1 && AutoDataProcessParameter.IsNormalize>1)
    %     cd([AutoDataProcessParameter.DataProcessDir,filesep,'T1Img',filesep,AutoDataProcessParameter.SubjectID{1}]);
    %     DirCo=dir('co*.img');
    %     if isempty(DirCo)
    %         error('co*.img NOT FOUND!');
    %     end
    %     if length(DirCo)>1
    %         warning('Multiple co*.img files found!');
    %     end
    %     UseNoCoT1Image=0;
    %     cd('..');
    
    %     if ~(7==exist([AutoDataProcessParameter.DataProcessDir,filesep,'ReorientMats'],'dir'))
    %         mkdir([AutoDataProcessParameter.DataProcessDir,filesep,'ReorientMats']);
    %     end
    
    
    %Reorient
    for i=1:AutoDataProcessParameter.SubjectNum
        %        if UseNoCoT1Image==0
        if exist([AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1Img',filesep,AutoDataProcessParameter.SubjectID{i},filesep,'ReorientT1ImgMat.mat'],'file')
            fprintf('Reorienting matrix already found for subject %s, skipping\n',AutoDataProcessParameter.SubjectID{i});
        else
            DirT1Img=give_filelist([AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1Img',filesep,AutoDataProcessParameter.SubjectID{i},filesep,'co*.img']);
            if isempty(DirT1Img)
                DirT1Img=dir([AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1Img',filesep,AutoDataProcessParameter.SubjectID{i},filesep,'co*.nii.gz']);% Search .nii.gz and unzip; YAN Chao-Gan, 120806.
                if length(DirT1Img)==1
                    gunzip([AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1Img',filesep,AutoDataProcessParameter.SubjectID{i},filesep,DirT1Img(1).name]);
                    delete([AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1Img',filesep,AutoDataProcessParameter.SubjectID{i},filesep,DirT1Img(1).name]);
                end
                DirT1Img=dir([AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1Img',filesep,AutoDataProcessParameter.SubjectID{i},filesep,'co*.nii']);
            end
            if length(DirT1Img)>1
                warning('Multiple co*.img files found! Using the first one.');
            end
            %         else
            %             DirT1Img=dir([AutoDataProcessParameter.DataProcessDir,filesep,'T1Img',filesep,AutoDataProcessParameter.SubjectID{i},filesep,'*.img']);
            %             if isempty(DirT1Img)
            %                 DirT1Img=dir([AutoDataProcessParameter.DataProcessDir,filesep,'T1Img',filesep,AutoDataProcessParameter.SubjectID{i},filesep,'*.nii.gz']);% Search .nii.gz and unzip; YAN Chao-Gan, 120806.
            %                 if length(DirT1Img)==1
            %                     gunzip([AutoDataProcessParameter.DataProcessDir,filesep,'T1Img',filesep,AutoDataProcessParameter.SubjectID{i},filesep,DirT1Img(1).name]);
            %                     delete([AutoDataProcessParameter.DataProcessDir,filesep,'T1Img',filesep,AutoDataProcessParameter.SubjectID{i},filesep,DirT1Img(1).name]);
            %                 end
            %                 DirT1Img=dir([AutoDataProcessParameter.DataProcessDir,filesep,'T1Img',filesep,AutoDataProcessParameter.SubjectID{i},filesep,'*.nii']);
            %             end
            %         end
            
            fprintf(' Instructions (option 1):\n1. press thin grey button (goes to origo)\n2. modify rotation parameters until good head position is found\n3. move rectile into AC\n4. modify translation parameters according to the numbers (inverse sign!)\n5. hit ''reorient images'' button\n')
            fprintf(' !!!!! Do not press thin grey button second time (after step 1).  If you do, no modifications are made !!!!!\n')
            fprintf(' Instructions (option 2):\n1. press thin grey button (goes to origo)\n2. modify rotation parameters until good head position is found\n3. move rectile into AC\n4. hit ''reorient images'' button\n')
            fprintf(' !!!!! Do not modify translation parameters manually or press button second time. If you do, no modifications are made !!!!!\n')
            
            FileList=[{[AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1Img',filesep,AutoDataProcessParameter.SubjectID{i},filesep,DirT1Img(1).name,',1']}];
            %fprintf('Reorienting T1 Image Interactively for %s: \n',AutoDataProcessParameter.SubjectID{i});
            global DPARSFA_spm_image_Parameters
            DPARSFA_spm_image_Parameters.ReorientFileList=FileList;
            filename = [AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1Img',filesep,AutoDataProcessParameter.SubjectID{i},filesep,DirT1Img(1).name];
            [a,b,e] = fileparts(filename);
            
            % keep the old files
            copyfile([a,filesep,b,'.img'],[a,filesep,b,'_OLD','.img']); % keep the old files
            copyfile([a,filesep,b,'.hdr'],[a,filesep,b,'_OLD','.hdr']);
            
            pass=0;
            while pass==0
                uiwait(DPARSFA_spm_image('init',filename));
                if isfield(DPARSFA_spm_image_Parameters,'ReorientMat')
                    mat=DPARSFA_spm_image_Parameters.ReorientMat;
                    if ~all(mat(1:3,4)==zeros(3,1))
                        pass=1;
                    end
                else
                    warning('!! No any translation was made (AC is likely not PERFECTLY in place). Please repeat and follow instructions !!')
                    
                    % just in case let's copy the original over the new one
                    copyfile([a,filesep,b,'_OLD','.img'],[a,filesep,b,'.img']);
                    copyfile([a,filesep,b,'_OLD','.hdr'],[a,filesep,b,'.hdr']);
                end
            end
            
            save([AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1Img',filesep,AutoDataProcessParameter.SubjectID{i},filesep,'ReorientT1ImgMat.mat'],'mat')
            clear global DPARSFA_spm_image_Parameters
            fprintf('Reorienting T1 Image Interactively for %s: OK\n',AutoDataProcessParameter.SubjectID{i});
        end
    end
    
    fprintf('\n');
end

%segmentation (do this before starting any BOLD data processing since if
%segmentation fails, further processing is pointless)
a = spm('WinSize','0',1);
if ~all(SPM_screensize==a)
    error('SPM screen bug!')
end

if (AutoDataProcessParameter.IsNormalize>1)
    
    %Backup the T1 images to T1ImgSegment
    try cd([AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1Img']);
    catch
        errordlg(['If the above command fails, you might have NOT checked the T1 DICOM to NIFTI checkbox the program expects the data in T1Img already'],'No T1Img directory found');
        return;
    end
    
    % Check in co* image exist. Added by YAN Chao-Gan 100510.
    cd(AutoDataProcessParameter.SubjectID{1});
    DirCo=give_filelist('co*.img');
    if isempty(DirCo)
        DirImg=give_filelist('*.img');
        if length(DirImg)==1
            warning('!!! No co* T1 image (T1 image which is reoriented to the nearest orthogonal direction to ''canonical space'' and removed excess air surrounding the individual as well as parts of the neck below the cerebellum) is found !!!');
            button = 'Yes';
            if strcmpi(button,'Yes')
                UseNoCoT1Image=1;
            else
                return;
            end
        else
            errordlg(['No co* T1 image (T1 image which is reoriented to the nearest orthogonal direction to ''canonical space'' and removed excess air surrounding the individual as well as parts of the neck below the cerebellum) is found. And there are too many T1 images detected in T1Img directory. Please determine which T1 image you want to use in unified segmentation and delete the others from the T1Img directory, then re-run the analysis.'],'No co* T1 image is found');
            return;
        end
    else
        UseNoCoT1Image=0;
    end
    cd('..');
    
    for i=1:AutoDataProcessParameter.SubjectNum
        cd(AutoDataProcessParameter.SubjectID{i});
        mkdir(['..',filesep,'..',filesep,'T1ImgSegment',filesep,AutoDataProcessParameter.SubjectID{i}])
        % Check in co* image exist. Added by YAN Chao-Gan 100510.
        if UseNoCoT1Image==0
            copyfile('co*',['..',filesep,'..',filesep,'T1ImgSegment',filesep,AutoDataProcessParameter.SubjectID{i}])
        else
            DirHdr=dir('*.hdr');
            DirImg=dir('*.img');
            copyfile(DirHdr(1).name,['..',filesep,'..',filesep,'T1ImgSegment',filesep,AutoDataProcessParameter.SubjectID{i},filesep,'co',DirHdr(1).name]);
            copyfile(DirImg(1).name,['..',filesep,'..',filesep,'T1ImgSegment',filesep,AutoDataProcessParameter.SubjectID{i},filesep,'co',DirImg(1).name]);
        end
        cd('..');
        fprintf(['Copying T1 image Files:',AutoDataProcessParameter.SubjectID{i},' OK\n']);
    end
    fprintf('\n');
    
    mkdir([AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'PicturesForChkNormalization']);
    
    if (AutoDataProcessParameter.IsNormalize<4)
        
        all_SourceFile = [];
        
        for i=1:AutoDataProcessParameter.SubjectNum
            CoDir=give_filelist([AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1ImgSegment',filesep,AutoDataProcessParameter.SubjectID{i},filesep,'co*.img']);
            
            if ~isempty(findstr(CoDir(1).name,'_OLD'))
                error('co* T1 image contains identifier "_OLD", this should not happen! Terminating.');
            end
            
            if (AutoDataProcessParameter.IsNormalize==2)
                [~,a,~] = fileparts(CoDir(1).name);
                if exist([AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1ImgSegment',filesep,AutoDataProcessParameter.SubjectID{i},filesep,[a,'_seg_sn.mat']],'file') ...
                        &&  exist([AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1ImgSegment',filesep,AutoDataProcessParameter.SubjectID{i},filesep,'skullstripped.img'],'file') ...
                        && ~isempty(dir([AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1ImgSegment',filesep,AutoDataProcessParameter.SubjectID{i},filesep,'c1co*']))
                    fprintf(['Old normalization files found, skipping computation for subject: ',AutoDataProcessParameter.SubjectID{i},'\n']);
                else
                    SourceFile=[AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1ImgSegment',filesep,AutoDataProcessParameter.SubjectID{i},filesep,...
                        CoDir(1).name,',1'];
                    fprintf(['Segmenting setup for subject: ',AutoDataProcessParameter.SubjectID{i},'\n']);
                    fprintf('...sourcefile: %s\n',SourceFile);
                    %segmentT1Image(SourceFile,regtype);%perform the segmentation if no segmentation data available (at this stage WITHOUT  moving the origo YH 8/11/2012
                    all_SourceFile{i}=SourceFile;
                end
            else
                [~,a,~] = fileparts(CoDir(1).name);
                if exist([AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1ImgSegment',filesep,AutoDataProcessParameter.SubjectID{i},filesep,['y_',a,'.nii']],'file') ...
                        && exist([AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1ImgSegment',filesep,AutoDataProcessParameter.SubjectID{i},filesep,[a,'_seg8.mat']],'file') ...
                        && exist([AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1ImgSegment',filesep,AutoDataProcessParameter.SubjectID{i},filesep,'skullstripped.img'],'file') ...
                        && ~isempty(dir([AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1ImgSegment',filesep,AutoDataProcessParameter.SubjectID{i},filesep,'c1co*']))
                    fprintf(['Old normalization files found, skipping computation for subject: ',AutoDataProcessParameter.SubjectID{i},'\n']);
                else
                    SourceFile=[AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1ImgSegment',filesep,AutoDataProcessParameter.SubjectID{i},filesep,...
                        CoDir(1).name,',1'];
                    fprintf(['Segmenting setup for subject: ',AutoDataProcessParameter.SubjectID{i},'\n']);
                    fprintf('...sourcefile: %s\n',SourceFile);
                    all_SourceFile{i}=SourceFile;
                    %segmentT1Image_NEW(SourceFile,regtype,SPMversion);%perform the segmentation if no segmentation data available (at this stage WITHOUT  moving the origo YH 8/11/2012
                end
            end
        end
        
        if use_parallel
            AutoDataProcessParameter.available_nworker = open_pool(AutoDataProcessParameter.requested_nworker);
            parfor k=1:length(all_SourceFile)
                if (AutoDataProcessParameter.IsNormalize==2)
                    segmentT1Image(all_SourceFile{k},regtype);
                else
                    segmentT1Image_NEW(all_SourceFile{k},AutoDataProcessParameter);
                end
            end
        else
            for k=1:length(all_SourceFile)
                if (AutoDataProcessParameter.IsNormalize==2)
                    segmentT1Image(all_SourceFile{k},regtype);
                else
                    segmentT1Image_NEW(all_SourceFile{k},AutoDataProcessParameter);
                end
            end
        end
        
        % clean up skullstripped image with AFNI, old
        % 'skullstripped.img' is now 'skullstripped_OLD.img'
        
        if AutoDataProcessParameter.IsAFNI==1
            AutoDataProcessParameter.available_nworker = open_pool(AutoDataProcessParameter.requested_nworker);
            for i=1:AutoDataProcessParameter.SubjectNum
                
                disp('Cleaning up skullstripped image');
                my_old_path = pwd;
                inputfile = [AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1ImgSegment',filesep,AutoDataProcessParameter.SubjectID{i},filesep,'skullstripped'];
                cd([ProgramPath,filesep,'AFNI']);
                movefile([inputfile,'.hdr'],'skullstripped.hdr');
                movefile([inputfile,'.img'],'skullstripped.img');
                %new_inputfile = [AutoDataProcessParameter.DataProcessDir,filesep,'T1ImgSegment',filesep,AutoDataProcessParameter.SubjectID{i},filesep,'skullstripped_OLD'];
                temp_opts=[];
                temp_opts.doPostprocessing=1;
                temp_opts.prefix='afni_';
                afni_skullstrip('skullstripped',temp_opts);
                movefile('skullstripped.hdr',[inputfile,'_OLD.hdr']);
                movefile('skullstripped.img',[inputfile,'_OLD.img']);
                %nii=load_nii('afni_skullstripped.nii');
                %save_nii(nii,'afni_skullstripped');
                %delete('afni_skullstripped.nii');
                %delete('afni_skullstripped.mat');
                movefile('afni_skullstripped.nii',[inputfile,'.nii']);
                %movefile('afni_skullstripped.hdr',[inputfile,'.hdr']);
                
                % Seems that AFNI loses the rotation info, so we must copy the old header
                % back to AFNI skullstripped image
                cd([AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1ImgSegment',filesep,AutoDataProcessParameter.SubjectID{i}]);
                nii_new = load_untouch_nii('skullstripped.nii');
                nii_old = load_untouch_nii('skullstripped_OLD');
                nii_new.hdr=nii_old.hdr;
                save_untouch_nii(nii_new,'skullstripped');
                
                cd(my_old_path);
                %clear my_old_path inputfile new_inputfile
            end
        end
        
        for i=1:AutoDataProcessParameter.SubjectNum
            
            cd([AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1ImgSegment',filesep,AutoDataProcessParameter.SubjectID{i}]);
            DirImg=give_filelist('c1co*.img');
            if isempty(DirImg)
                DirImg=dir('c1co*.nii');
            end
            fDPA_Normalized_TempImage =fullfile(tempdir,['DPARSF_Normalized_TempImage','_',rest_misc('GetCurrentUser'),'.img']);
            %y_Reslice(DirImg(1).name,fDPA_Normalized_TempImage,[1 1 1],0)
            reslice_nii(DirImg(1).name,fDPA_Normalized_TempImage,[1,1,1],1,0,2);
            nii=load_nii(fDPA_Normalized_TempImage);
            cd([AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'PicturesForChkNormalization']);
            save_volume_slices(nii.img,...
                [AutoDataProcessParameter.SubjectID{i},'_grey_matter_co1.tiff'],...
                [AutoDataProcessParameter.SubjectID{i},' segmented grey matter (co1*.img)']);
            fprintf(['Generating the pictures for checking segmentation (GM): ',AutoDataProcessParameter.SubjectID{i},' OK\n']);
            
            cd([AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1ImgSegment',filesep,AutoDataProcessParameter.SubjectID{i}]);
            DirImg=give_filelist('skullstripped.img');
            %fDPA_Normalized_TempImage =fullfile(tempdir,['DPARSF_Normalized_TempImage','_',rest_misc('GetCurrentUser'),'.img']);
            %y_Reslice(DirImg(1).name,fDPA_Normalized_TempImage,[1 1 1],0)
            reslice_nii(DirImg(1).name,fDPA_Normalized_TempImage,[1,1,1],1,0,2);
            nii=load_nii(fDPA_Normalized_TempImage);
            cd([AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'PicturesForChkNormalization']);
            save_volume_slices(nii.img,...
                [AutoDataProcessParameter.SubjectID{i},'_skullstripped.tiff'],...
                [AutoDataProcessParameter.SubjectID{i},' skullstripped'])
            fprintf(['Generating the pictures for checking skullstripping : ',AutoDataProcessParameter.SubjectID{i},' OK\n']);
            fprintf('\n');
            
        end
        
        if AutoDataProcessParameter.IsManualSkullstrip==1
            fprintf('\n\n!!!    Stopping execution for manual segmentation/skullstrip check     !!!\n\n')
            %fprintf('A. Check c1co* file: %s\n',[AutoDataProcessParameter.DataProcessDir,filesep,'T1ImgSegment',filesep,AutoDataProcessParameter.SubjectID{i},filesep,'c1*.img']');
            %fprintf('B. Check skullstrip file: %s\n',[AutoDataProcessParameter.DataProcessDir,filesep,'T1ImgSegment',filesep,AutoDataProcessParameter.SubjectID{i},filesep,'skullstripped.img']');
            fprintf('Press any key to continue\n');
            pause
        end
        
    else
        needselection = 0;
        for i=1:AutoDataProcessParameter.SubjectNum
            if isempty(dir([AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1ImgSegment',filesep,AutoDataProcessParameter.SubjectID{i},filesep,'skullstripped.nii'])) ...
                    && isempty(dir([AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1ImgSegment',filesep,AutoDataProcessParameter.SubjectID{i},filesep,'skullstripped.img']))
                
                needselection = 1;
                if isempty(dir([AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1ImgSegment',filesep,AutoDataProcessParameter.SubjectID{i},filesep,'FAST_biascorrected_*.nii']))
                    CoDir=give_filelist([AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1ImgSegment',filesep,AutoDataProcessParameter.SubjectID{i},filesep,'co*.img']);
                    
                    if ~isempty(findstr(CoDir(1).name,'_OLD'))
                        error('co* T1 image contains identifier "_OLD", cannot continue!');
                    end
                    
                    SourceFile=[AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1ImgSegment',filesep,AutoDataProcessParameter.SubjectID{i},filesep,...
                        CoDir(1).name];
                    fprintf(['Computing bias-corrected T1 for subject: ',AutoDataProcessParameter.SubjectID{i},'\n']);
                    fsl_normalization_part1(SourceFile);
                else
                    fprintf(['Bias-corrected T1 already found for subject: ',AutoDataProcessParameter.SubjectID{i},'\n']);
                end
                
                cd([AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1ImgSegment',filesep,AutoDataProcessParameter.SubjectID{i}]);
                SourceFile=dir('FAST_biascorrected_*.nii');
                SourceFile=SourceFile(1).name;
                [a,b,c]=fileparts(SourceFile);
                SourceFile=b;
                
                t1_files{i}=[b,c];
                
                clear opts;
                opts.do_two_stage=0;
                opts.g = -0.1;
                opts.do_two_stage=0;
                
                k=0;
                for f=0.10:0.05:0.40
                    k=k+1;
                    opts.f=f;
                    opts.prefix=sprintf('BET_skullstripped_id%i_f%3.2f_',k,f);
                    bet_files{i,k}=[opts.prefix,SourceFile,c];
                    fprintf(' running BET with f=%f\n',f);
                    fsl_bet_skullstrip(SourceFile,opts);
                end
                
            else
                fprintf(['Skullstripped image already found for subject: ',AutoDataProcessParameter.SubjectID{i},'\n']);
            end
        end
        
        while needselection == 1
            
            fprintf('Pausing computation. Choose best image or create a new one.\n');
            
            pass = 1;
            for i=1:AutoDataProcessParameter.SubjectNum
                cd([AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1ImgSegment',filesep,AutoDataProcessParameter.SubjectID{i}]);
                if exist('skullstripped.img')>0 || exist('skullstripped.nii')>0
                    fprintf(['Skulltripped image found for ',AutoDataProcessParameter.SubjectID{i},'\n']);
                elseif ~isempty(dir('BET_skullstripped*'))
                    
                    nii=load_untouch_nii(t1_files{i});
                    mat_base=nii.img;
                    clear h;
                    for k=1:size(bet_files,2)
                        nii=load_untouch_nii(bet_files{i,k});
                        mat=nii.img;
                        tit=['Subject ',AutoDataProcessParameter.SubjectID{i},', BET file ID=',num2str(k)];
                        h{k} = show_volume_slices(mat_base,mat,tit,k);
                    end
                    
                    choice = 0;
                    while choice==0
                        try
                            choice = input(['Check BET files for subject ',num2str(i),'. Enter the best ID number: ']);
                        catch
                        end
                        if ~(isnumeric(choice) && choice>0 && choice<size(bet_files,2)+1)
                            warning('please enter integer between 1 and %i',size(bet_files,2));
                            choice=0;
                        end
                    end
                    
                    movefile([bet_files{i,choice}],'skullstripped.nii');
                    
                    for k=1:size(bet_files,2)
                        try
                            close(h{k});
                        catch
                        end
                    end
                    
                    clear mat_base mat nii;
                    
                else
                    fprintf(['Skulltripped images NOT found for subject: ',AutoDataProcessParameter.SubjectID{i},'\n']);
                    pass=0;
                end
            end
            
            if pass==1
                break;
            end
            
        end
        
        for i=1:AutoDataProcessParameter.SubjectNum
            
            cd([AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1ImgSegment',filesep,AutoDataProcessParameter.SubjectID{i}]);
            DirImg=dir('skullstripped.nii');
            fDPA_Normalized_TempImage =fullfile(tempdir,['DPARSF_Normalized_TempImage','_',rest_misc('GetCurrentUser'),'.img']);
            %y_Reslice(DirImg(1).name,fDPA_Normalized_TempImage,[1 1 1],0)
            reslice_nii(DirImg(1).name,fDPA_Normalized_TempImage,[1,1,1],1,0,2);
            nii=load_nii(fDPA_Normalized_TempImage);
            cd([AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'PicturesForChkNormalization']);
            save_volume_slices(nii.img,...
                [AutoDataProcessParameter.SubjectID{i},'_skullstripped.tiff'],...
                [AutoDataProcessParameter.SubjectID{i},' skullstripped'])
            fprintf(['Generating the pictures for checking skullstripping : ',AutoDataProcessParameter.SubjectID{i},' OK\n']);
        end
        
        if AutoDataProcessParameter.IsManualSkullstrip==1
            disp('!!!    Stopping execution for manual skullstrip check     !!!')
            fprintf('Check skullstrip.img/nii file for all subjects in %s\n',[AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1ImgSegment',filesep]);
            fprintf('If results are not good, do manual skullstripping with BET or AFNI\n');
            pause
        end
    end
end

close_all_new_images(original_fig_handles);
drawnow;

if AutoDataProcessParameter.hasFunData==0
    warning('No functional data set, terminating execution');
    return
end

%Convert Functional DICOM files to NIFTI images
if (AutoDataProcessParameter.IsNeedConvertFunDCM2IMG==1)
    fprintf('------------- DICOM to NIFTI conversion Fun -----------------\n')
    SourceDir = 'FunRaw';
    TargetDir = 'FunImg';
    
    all_timepoints = zeros(AutoDataProcessParameter.SubjectNum,AutoDataProcessParameter.Sessions);
    
    for SES = 1:AutoDataProcessParameter.Sessions
        
        cd([AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,SourceDir]);
        
        for i=1:AutoDataProcessParameter.SubjectNum
            OutputDir=[AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,TargetDir,filesep,AutoDataProcessParameter.SubjectID{i}];
            mkdir(OutputDir);
            DirDCM=dir([AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,SourceDir,filesep,AutoDataProcessParameter.SubjectID{i},filesep,'*']); %Revised by YAN Chao-Gan 100130. %DirDCM=dir([AutoDataProcessParameter.DataProcessDir,filesep,'FunRaw',filesep,AutoDataProcessParameter.SubjectID{i},filesep,'*.*']);
            InputFilename=[AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,SourceDir,filesep,AutoDataProcessParameter.SubjectID{i},filesep,DirDCM(3).name];% if index exceeds matrix dimensions the folder might be empty or non-existent
            if ispc
                OldDirTemp=pwd; %Added by YAN Chao-Gan 100130.
                cd([ProgramPath,filesep,'dcm2nii']); %Revised by YAN Chao-Gan 100510. %cd([ProgramPath,filesep,'MRIcroN']);
                %eval(['!dcm2nii.exe -o ',OutputDir,' ',InputFilename]); %Revised by YAN Chao-Gan 100130. %eval(['!',ProgramPath,filesep,'MRIcroN',filesep,'dcm2nii.exe -o ',OutputDir,' ',InputFilename]);
                eval(['!dcm2nii.exe -b dcm2nii.ini -o "',OutputDir,'" "',InputFilename,'"']); %Revised by YAN Chao-Gan 100506.
                cd(OldDirTemp); %Added by YAN Chao-Gan 100130.
            else
                %101010 Changed to use MRIcroN's dcm2nii since its linux bug has been fixed.
                OldDirTemp=pwd; %Added by YAN Chao-Gan 100130.
                cd([ProgramPath,filesep,'dcm2nii']); %Revised by YAN Chao-Gan 100510. %cd([ProgramPath,filesep,'MRIcroN']);
                eval(['!chmod +x dcm2nii_linux']); %Revised by YAN Chao-Gan 100130. %eval(['!chmod +x ',ProgramPath,filesep,'MRIcroN',filesep,'dcm2nii_linux']);
                eval(['!./dcm2nii_linux -b ./dcm2nii_linux.ini -o "',OutputDir,'" "',InputFilename,'"']); %Revised by YAN Chao-Gan 100510. %eval(['!',ProgramPath,filesep,'MRIcroN',filesep,'dcm2nii_linux -a N -d Y -e Y -f N -g N -i Y -n N -p Y -s N -v Y -o ',OutputDir,' ',InputFilename]);
                cd(OldDirTemp); %Added by YAN Chao-Gan 100130.
            end
            fprintf(['Converting Functional Images:',AutoDataProcessParameter.SubjectID{i},' OK\n']);
            
            cd(OutputDir);
            DirImg=give_filelist('*.img');
            all_timepoints(i,SES)=length(DirImg);
            
            if AutoDataProcessParameter.TimePoints>0 && AutoDataProcessParameter.TimePoints~=length(DirImg)
                error('Given timepoint count (%i) does not match IMG file count (%i)!',AutoDataProcessParameter.TimePoints,length(DirImg));
            end
            
            clear_fun_reorient([AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,'T1Img',filesep,AutoDataProcessParameter.SubjectID{i}]);
            
        end
    end
    SourceDir = 'FunImg';
    
    %    AutoDataProcessParameter.TimePoints = all_timepoints;
    
    for SES = 1:AutoDataProcessParameter.Sessions
        if length(unique(all_timepoints(:,SES)))>1
            %unique(all_timepoints)
            warning('Not all subjects have the same timepoint count!')
        end
    end
    
    fprintf('\n');
    
else
    % Initialize source and target directories
    TargetDir = AutoDataProcessParameter.SourceDir;
    SourceDir = AutoDataProcessParameter.SourceDir;
end

%****************************************************************Processing of fMRI BOLD images*****************

fprintf('\n------------- TR and slice-number verification -----------------\n\n')
%Check TR and store Subject ID, TR, Slice Number, Time Points, Voxel Size into TRInfo.tsv if needed.

if ~( strcmpi(AutoDataProcessParameter.StartingDirName,'T1Raw') || strcmpi(AutoDataProcessParameter.StartingDirName,'T1Img') )  %Only need for functional processing
    
    try
        
        fprintf('Checking & saving scanning parameters\n');
        
        %         if (2==exist([AutoDataProcessParameter.DataProcessDir,filesep,'TRInfo.tsv'],'file'))  %If the TR information is stored in TRInfo.tsv. %YAN Chao-Gan, 130612
        %
        %             fid = fopen([AutoDataProcessParameter.DataProcessDir,filesep,'TRInfo.tsv']);
        %             StringFilter = '%s';
        %             for iFunSession=1:AutoDataProcessParameter.FunctionalSessionNumber
        %                 StringFilter = [StringFilter,'\t%f']; %Get the TRs for the sessions.
        %             end
        %             StringFilter = [StringFilter,'%*[^\n]']; %Skip the else till end of the line
        %             tline = fgetl(fid); %Skip the title line
        %             TRInfoTemp = textscan(fid,StringFilter);
        %             fclose(fid);
        %
        %             for i=1:AutoDataProcessParameter.SubjectNum
        %                 if ~strcmp(AutoDataProcessParameter.SubjectID{i},TRInfoTemp{1}{i})
        %                     error(['The subject ID ',TRInfoTemp{1}{i},' in TRInfo.tsv doesn''t match the target subject ID: ',AutoDataProcessParameter.SubjectID{i},'!'])
        %                 end
        %             end
        %
        %             TRSet = zeros(AutoDataProcessParameter.SubjectNum,AutoDataProcessParameter.FunctionalSessionNumber);
        %             for iFunSession=1:AutoDataProcessParameter.FunctionalSessionNumber
        %                 TRSet(:,iFunSession) = TRInfoTemp{1+iFunSession}; %The first column is Subject ID
        %             end
        %
        %         elseif (2==exist([AutoDataProcessParameter.DataProcessDir,filesep,'TRSet.txt'],'file'))  %If the TR information is stored in TRSet.txt (DPARSF V2.2).
        %             TRSet = load([AutoDataProcessParameter.DataProcessDir,filesep,'TRSet.txt']);
        %             TRSet = TRSet'; %YAN Chao-Gan 130612. This is for the compatibility with DPARSFA V2.2. Cause the TRSet saved there is in a transpose manner.
        %         else
        
        TRSet = zeros(AutoDataProcessParameter.SubjectNum,AutoDataProcessParameter.Sessions);
        SliceNumber = zeros(AutoDataProcessParameter.SubjectNum,AutoDataProcessParameter.Sessions);
        nTimePoints = zeros(AutoDataProcessParameter.SubjectNum,AutoDataProcessParameter.Sessions);
        VoxelSize = zeros(AutoDataProcessParameter.SubjectNum,AutoDataProcessParameter.Sessions,3);
        for SES=1:AutoDataProcessParameter.Sessions
            for i=1:AutoDataProcessParameter.SubjectNum
                cd([AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,SourceDir,filesep,AutoDataProcessParameter.SubjectID{i}]);
                DirImg=give_filelist('*.img');
                if isempty(DirImg)  %YAN Chao-Gan, 111114. Also support .nii files. % Either in .nii.gz or in .nii
                    DirImg=dir('*.nii.gz');  % Search .nii.gz and unzip; YAN Chao-Gan, 120806.
                    if length(DirImg)==1
                        gunzip(DirImg(1).name);
                        delete(DirImg(1).name);
                    end
                    DirImg=dir('*.nii');
                end
                Nii  = nifti(DirImg(1).name);
                if (~isfield(Nii.timing,'tspace'))
                    error('Can NOT retrieve the TR information from the NIfTI images');
                end
                TRSet(i,SES) = Nii.timing.tspace;
                
                SliceNumber(i,SES) = size(Nii.dat,3);
                
                nii=load_nii_hdr(DirImg(1).name);
                if nii.dime.dim(4)~=SliceNumber(i,SES)
                    error('Slice number check inconsistent!')
                end
                
                if size(Nii.dat,4)==1 %Test if 3D volume
                    nTimePoints(i,SES) = length(DirImg);
                else %4D volume
                    nTimePoints(i,SES) = size(Nii.dat,4);
                end
                
                VoxelSize(i,SES,:) = sqrt(sum(Nii.mat(1:3,1:3).^2));
            end
        end
        %save([AutoDataProcessParameter.DataProcessDir,filesep,'TRSet.txt'], 'TRSet', '-ASCII', '-DOUBLE','-TABS'); %YAN Chao-Gan, 121214. Save the TR information.
        
        %YAN Chao-Gan, 130612. No longer save to TRSet.txt, but save to TRInfo.tsv with information of Slice Number, Time Points, Voxel Size.
        
        %Write the information as TRInfo.tsv
        fid = fopen([AutoDataProcessParameter.DataProcessDir,filesep,'TRInfo.tsv'],'w');
        
        fprintf(fid,'Subject ID');
        for iFunSession=1:AutoDataProcessParameter.Sessions
            fprintf(fid,['\t','TR']);
        end
        for iFunSession=1:AutoDataProcessParameter.Sessions
            fprintf(fid,['\t','Slice Number']);
        end
        for iFunSession=1:AutoDataProcessParameter.Sessions
            fprintf(fid,['\t','Time Points']);
        end
        for iFunSession=1:AutoDataProcessParameter.Sessions
            fprintf(fid,['\t','Voxel Size']);
        end
        
        fprintf(fid,'\n');
        for i=1:AutoDataProcessParameter.SubjectNum
            fprintf(fid,'%s',AutoDataProcessParameter.SubjectID{i});
            
            for SES=1:AutoDataProcessParameter.Sessions
                fprintf(fid,'\t%g',TRSet(i,SES));
            end
            for SES=1:AutoDataProcessParameter.Sessions
                fprintf(fid,'\t%g',SliceNumber(i,SES));
            end
            for SES=1:AutoDataProcessParameter.Sessions
                fprintf(fid,'\t%g',nTimePoints(i,SES));
            end
            for SES=1:AutoDataProcessParameter.Sessions
                fprintf(fid,'\t%g %g %g',VoxelSize(i,SES,1),VoxelSize(i,SES,2),VoxelSize(i,SES,3));
            end
            fprintf(fid,'\n');
        end
        
        fclose(fid);
        
        %end
        %AutoDataProcessParameter.TRSet = TRSet;
        
        if length(unique(TRSet(:)))>1
            warning('TR values do not match between subjects!')
        end
        if AutoDataProcessParameter.TR<=0
            AutoDataProcessParameter.TR = TRSet;
        else
            if max(abs(AutoDataProcessParameter.TR - TRSet(:)))>0.001
                error('Too large %f second difference between given and checked TR value!',max(abs(AutoDataProcessParameter.TR - TRSet(:))));
            end
            AutoDataProcessParameter.TR = AutoDataProcessParameter.TR*ones(size(TRSet));
        end
        
        if ~AutoDataProcessParameter.SliceTiming.IsAutoSliceNumber
            if max(abs(AutoDataProcessParameter.SliceTiming.SliceNumber - SliceNumber(:)))>0
                error('Checked slicenumber does not match the given!')
            end
        else
            AutoDataProcessParameter.SliceTiming.SliceNumber = SliceNumber;
        end
        
        %         if length(AutoDataProcessParameter.TimePoints)>1
        %             if max(abs(AutoDataProcessParameter.TimePoints-nTimePoints(:)))>0
        %                 error('Checked timepoint count does not match the given!')
        %             end
        %         else
        if AutoDataProcessParameter.TimePoints>0
            if max(abs(AutoDataProcessParameter.TimePoints-nTimePoints(:)))>0
                error('Given timepoint count does not match IMG file count!')
            else
                AutoDataProcessParameter.TimePoints = nTimePoints;
            end
        else
            AutoDataProcessParameter.TimePoints = nTimePoints;
        end
        
    catch err
        
        warning('Check failed, will assume that you entered corrects values: %s!',err.message)
        if any(AutoDataProcessParameter.TR<=0) || any(AutoDataProcessParameter.TimePoints<=0)
            error('TR and TIMEPOINTS info must be set manually');
        else
            AutoDataProcessParameter.TR = AutoDataProcessParameter.TR*ones(length(AutoDataProcessParameter.SubjectNum),AutoDataProcessParameter.Sessions);
            AutoDataProcessParameter.TimePoints = AutoDataProcessParameter.TimePoints(1)*ones(length(AutoDataProcessParameter.SubjectNum),AutoDataProcessParameter.Sessions);
        end
        
    end
    
end


%****************************************************************Processing of fMRI BOLD images*****************



%Remove First Time Points
if (AutoDataProcessParameter.RemoveFirstTimePoints>0 && AutoDataProcessParameter.IsRemoveFirstTimePoints)
    fprintf('\n------------- First volumes removal -----------------\n\n')
    
    for SES = 1:AutoDataProcessParameter.Sessions
        
        cd([AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,SourceDir]);
        for i=1:AutoDataProcessParameter.SubjectNum
            cd(AutoDataProcessParameter.SubjectID{i});
            DirImg=give_filelist('*.img');
            if length(DirImg)~=AutoDataProcessParameter.TimePoints(i,SES)
                error('Number of Images in Folder Does Not Match the Number of Volumes. Cannot Remove First ');
            end
            if isempty(strfind(DirImg(1).name,'_1.img')) ...
                    && isempty(strfind(DirImg(1).name,'_01.img')) ...
                    && isempty(strfind(DirImg(1).name,'_001.img'))...
                    && isempty(strfind(DirImg(1).name,'_0001.img'))...
                    && isempty(strfind(DirImg(1).name,'0001.img'))
                warning('!!! 1. slice not found - some volumes might be already deleted !!!')
            end
            for j=1:AutoDataProcessParameter.RemoveFirstTimePoints
                delete(DirImg(j).name);
                delete([DirImg(j).name(1:end-4),'.hdr']);
            end
            cd('..');
            fprintf(['Removing First ',num2str(AutoDataProcessParameter.RemoveFirstTimePoints),' Time Points:',AutoDataProcessParameter.SubjectID{i},' OK\n']);
        end
        
    end
    
    fprintf('\n');
    AutoDataProcessParameter.TimePoints=AutoDataProcessParameter.TimePoints-AutoDataProcessParameter.RemoveFirstTimePoints;
end

set(0,'units','pixels');
a = spm('WinSize','0',1);
if ~all(SPM_screensize==a)
    error('SPM screen bug!')
end

%Slice Timing
if (AutoDataProcessParameter.IsSliceTiming==1)
    fprintf('\n------------- Slice timing correction -----------------\n\n')
    if SPMversion==8
        load([ProgramPath,filesep,'Jobmats',filesep,'SliceTiming.mat']);
    else
        load([ProgramPath,filesep,'Jobmats',filesep,'SliceTimingSPM12.mat']);
    end
    for SES = 1:AutoDataProcessParameter.Sessions
        cd([AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,SourceDir]);
        for i=1:AutoDataProcessParameter.SubjectNum
            cd(AutoDataProcessParameter.SubjectID{i});
            DirImg=give_filelist('*.img');
            if length(DirImg)~=AutoDataProcessParameter.TimePoints(i,SES)
                error('Number of files does not match TimePoints!');
            end
            FileList=[];
            for j=1:length(DirImg)
                FileList=[FileList;{[AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,'FunImg',filesep,AutoDataProcessParameter.SubjectID{i},filesep,DirImg(j).name,',1']}];
            end
            if SPMversion==8
                jobs{1,1}.temporal{1,1}.st.scans{i}=FileList;
            else
                
                if AutoDataProcessParameter.SliceTiming.IsAutoSliceNumber
                    nii=load_nii_hdr(FileList{1}(1:end-2));
                    SliceNumber = nii.dime.dim(4);
                    if AutoDataProcessParameter.SliceTiming.SliceNumber(i,SES)~=SliceNumber
                        error('Slice number does not match!')
                    end
                    if SliceNumber<20 || SliceNumber>50
                        SliceNumber
                        error('Crazy SliceNumber, failed to set automatically')
                    end
                else
                    SliceNumber = AutoDataProcessParameter.SliceTiming.SliceNumber;
                end
                
                if AutoDataProcessParameter.SliceTiming.IsInterleaved
                    SliceOrder = [1:2:SliceNumber,2:2:SliceNumber];
                else
                    SliceOrder = AutoDataProcessParameter.SliceTiming.SliceOrder;
                end
                
                if AutoDataProcessParameter.SliceTiming.IsMiddleReference
                    ReferenceSlice = floor(SliceNumber/2);
                else
                    ReferenceSlice = AutoDataProcessParameter.SliceTiming.ReferenceSlice;
                end
                
                TR = AutoDataProcessParameter.TR(i,SES);
                TA = TR-(TR/SliceNumber);
                
                matlabbatch{i,1}.spm.temporal.st.scans{1}=FileList;
                matlabbatch{i,1}.spm.temporal.st.nslices=SliceNumber;
                matlabbatch{i,1}.spm.temporal.st.tr=TR;
                matlabbatch{i,1}.spm.temporal.st.ta=TA;
                matlabbatch{i,1}.spm.temporal.st.so=SliceOrder;
                matlabbatch{i,1}.spm.temporal.st.refslice=ReferenceSlice;
                
            end
            
            cd('..');
            fprintf(['Slice Timing Setup:',AutoDataProcessParameter.SubjectID{i},' OK\n']);
        end
        fprintf('\n');
        if SPMversion==8  %YAN Chao-Gan, 090925. SPM8 compatible.
            jobs{1,1}.temporal{1,1}.st.nslices=AutoDataProcessParameter.SliceTiming.SliceNumber;
            jobs{1,1}.temporal{1,1}.st.tr=AutoDataProcessParameter.TR(1);
            jobs{1,1}.temporal{1,1}.st.ta=AutoDataProcessParameter.SliceTiming.TA;
            jobs{1,1}.temporal{1,1}.st.so=AutoDataProcessParameter.SliceTiming.SliceOrder;
            jobs{1,1}.temporal{1,1}.st.refslice=AutoDataProcessParameter.SliceTiming.ReferenceSlice;
            jobs = spm_jobman('spm5tospm8',{jobs});
            run_batch(jobs{1},AutoDataProcessParameter.requested_nworker);
            clear jobs;
        elseif SPMversion==12
            run_batch(matlabbatch,AutoDataProcessParameter.requested_nworker);
            clear matlabbatch;
        else
            uiwait(msgbox('The current SPM version is not supported by fDPA. Please install SPM8 or SPM12 first.','Invalid SPM Version.'));
            return
        end
    end
end

set(0,'units','pixels');
a = spm('WinSize','0',1);
if ~all(SPM_screensize==a)
    error('SPM screen bug!')
end

%Realign
if (AutoDataProcessParameter.IsRealign==1)
    fprintf('\n------------- Realignment (motion-correction) -----------------\n\n')
    
    if SPMversion==8
        load([ProgramPath,filesep,'Jobmats',filesep,'Realign.mat']);
    else
        load([ProgramPath,filesep,'Jobmats',filesep,'RealignSPM12.mat']);
    end
       
    for i=1:AutoDataProcessParameter.SubjectNum
        for SES = 1:AutoDataProcessParameter.Sessions
            
            cd([AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,SourceDir]);
            
            cd(AutoDataProcessParameter.SubjectID{i});
            if (AutoDataProcessParameter.IsSliceTiming==1) % Compatibility with the new optional slice timing correction. /EP
                DirImg=give_filelist('a*.img');
            else
                DirImg=give_filelist('*.img');
            end
            if length(DirImg)~=AutoDataProcessParameter.TimePoints(i,SES)
                error('Number of images does not match timepoints!')
            end
            
            FileList=[];
            for j=1:length(DirImg)
                FileList=[FileList;{[AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,SourceDir,filesep,AutoDataProcessParameter.SubjectID{i},filesep,DirImg(j).name,',1']}];
            end
            if SPMversion==8
                if i~=1 && SES==1
                    jobs{1,1}.spatial{1,1}.realign=[jobs{1,1}.spatial{1,1}.realign,{jobs{1,1}.spatial{1,1}.realign{1,1}}];
                end
                jobs{1,1}.spatial{1,1}.realign{1,i}.estwrite.roptions.which = [0 1]; % "Only mean image" setting /EP
                jobs{1,1}.spatial{1,1}.realign{1,i}.estwrite.data{1,SES}=FileList;
            else
                if i>1 && SES==1
                    matlabbatch{i}=matlabbatch{1};
                end
                matlabbatch{i}.spm.spatial.realign.estwrite.data{1,SES}=FileList;
            end
        end
        cd('..');
        fprintf(['Realign Setup:',AutoDataProcessParameter.SubjectID{i},' OK\n']);
    end
    if SPMversion==8
        jobs = spm_jobman('spm5tospm8',{jobs});
        run_batch(jobs{1},AutoDataProcessParameter.requested_nworker);
        clear jobs;
    elseif SPMversion==12
        run_batch(matlabbatch,AutoDataProcessParameter.requested_nworker);
        clear matlabbatch;
    else
        uiwait(msgbox('The current SPM version is not supported by fDPA. Please install SPM5 or SPM8 first.','Invalid SPM Version.'));
        return
    end
    
    
    %YAN Chao-Gan, 101018. Check Head motion moved right after realign
    %Move the Realign Parameters to DataProcessDir\RealignParameter
    for SES = 1:AutoDataProcessParameter.Sessions
        cd([AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,SourceDir]);
        for i=1:AutoDataProcessParameter.SubjectNum
            cd(AutoDataProcessParameter.SubjectID{i});
            mkdir(['..',filesep,'..',filesep,'RealignParameter',filesep,AutoDataProcessParameter.SubjectID{i}]);
            movefile('rp*',['..',filesep,'..',filesep,'RealignParameter',filesep,AutoDataProcessParameter.SubjectID{i}]);
            cd('..');
            fprintf(['Moving Realign Parameters:',AutoDataProcessParameter.SubjectID{i},' OK\n']);
        end
        if ~isempty(dir('*.ps'))
            copyfile('*.ps',['..',filesep,'RealignParameter',filesep]);
        end
    end
    
    cd([AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,SourceDir]);
    for i=1:AutoDataProcessParameter.SubjectNum
        cd(AutoDataProcessParameter.SubjectID{i});
        movefile('mean*',['..',filesep,'..',filesep,'RealignParameter',filesep,AutoDataProcessParameter.SubjectID{i}]);
        cd('..');
        fprintf(['Moving Realign Parameters:',AutoDataProcessParameter.SubjectID{i},' OK\n']);
    end
    fprintf('\n');
    
    %     if AutoDataProcessParameter.IsMultisession==1
    %         for i=1:AutoDataProcessParameter.SubjectNum
    %             FileList=[];
    %             expression = '';
    %
    %             mean_tps = mean(AutoDataProcessParameter.TimePoints(i,:));
    %             tps = AutoDataProcessParameter.TimePoints(i,:)/mean_tps;
    %
    %             for SES = 1:AutoDataProcessParameter.Sessions
    %                 cd([AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,'RealignParameter']);
    %                 cd(AutoDataProcessParameter.SubjectID{i});
    %                 a = dir('mean*');
    %                 expression = [expression,num2str(tps(SES)),'*i',num2str(SES),'+'];
    %                 FileList=[FileList;{[pwd,filesep,a.name]}];
    %             end
    %             expression=[expression(1:end-1),'/',num2str(mean_tps)];
    %             if length(FileList)~=AutoDataProcessParameter.Sessions
    %                 error('Incorrect mean image count!')
    %             end
    %             matlabbatch{1}.spm.util.imcalc.input = FileList;
    %             matlabbatch{1}.spm.util.imcalc.output = ['grand_mean_EPI_',AutoDataProcessParameter.SubjectID{i}];
    %             matlabbatch{1}.spm.util.imcalc.outdir = {[AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'RealignParameter',AutoDataProcessParameter.SubjectID{i}]};
    %             matlabbatch{1}.spm.util.imcalc.expression = expression;
    %             matlabbatch{1}.spm.util.imcalc.var = struct('name', {}, 'value', {});
    %             matlabbatch{1}.spm.util.imcalc.options.dmtx = 0;
    %             matlabbatch{1}.spm.util.imcalc.options.mask = 0;
    %             matlabbatch{1}.spm.util.imcalc.options.interp = 1;
    %             matlabbatch{1}.spm.util.imcalc.options.dtype = 16;
    %         end
    %         fprintf('\n');
    %     end
    %
    %Check Head Motion
    for SES = 1:AutoDataProcessParameter.Sessions
        cd([AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,'RealignParameter']);
        
        HeadMotion=[];
        for i=1:AutoDataProcessParameter.SubjectNum
            cd(AutoDataProcessParameter.SubjectID{i});
            rpname=dir('rp*');
            b=load(rpname.name);
            c=max(abs(b));
            c(4:6)=c(4:6)*180/pi;
            HeadMotion=[HeadMotion;c];
            cd('..');
        end
        save('HeadMotion.mat','HeadMotion');
        
        ExcludeSub_Text=[];
        for ExcludingCriteria=3:-0.5:0.5
            BigHeadMotion=find(HeadMotion>ExcludingCriteria);
            if ~isempty(BigHeadMotion)
                [II JJ]=ind2sub([AutoDataProcessParameter.SubjectNum,6],BigHeadMotion);
                ExcludeSub=unique(II);
                ExcludeSub_ID=AutoDataProcessParameter.SubjectID(ExcludeSub);
                TempText='';
                for iExcludeSub=1:length(ExcludeSub_ID)
                    TempText=sprintf('%s%s\n',TempText,ExcludeSub_ID{iExcludeSub});
                end
            else
                TempText='None';
            end
            ExcludeSub_Text=sprintf('%s\nExcluding Criteria: %2.1fmm and %2.1f degree\n%s\n\n\n',ExcludeSub_Text,ExcludingCriteria,ExcludingCriteria,TempText);
        end
        fid = fopen('ExcludeSubjects.txt','at+');
        fprintf(fid,'%s',ExcludeSub_Text);
        fclose(fid);
    end
    
end


set(0,'units','pixels');
a = spm('WinSize','0',1);
if ~all(SPM_screensize==a)
    error('SPM screen bug!')
end

% Janne K. 15.1.2014
% apply manual reorient to functional images

if AutoDataProcessParameter.IsNormalize>1 && AutoDataProcessParameter.IsManualAlignment==1
    fprintf('\n------------- Apply manual reorient to functional images -----------------\n\n')
    
    for i=1:AutoDataProcessParameter.SubjectNum
        % In case there exist reorient matrix (interactive reorient after head motion correction and before T1-Fun coregistration)
        ReorientMat=eye(4);
        if exist([AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1Img',filesep,AutoDataProcessParameter.SubjectID{i},filesep,'ReorientT1ImgMat.mat'])==2
            ReorientMat_Interactively = load([AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1Img',filesep,AutoDataProcessParameter.SubjectID{i},filesep,'ReorientT1ImgMat.mat']);
            if ~isfield(ReorientMat_Interactively,'alreadyAppliedToFun') || AutoDataProcessParameter.IsNeedConvertFunDCM2IMG==1
                ReorientMat=ReorientMat_Interactively.mat*ReorientMat;
            else
                if isfield(ReorientMat_Interactively,'alreadyAppliedToFun') && ReorientMat_Interactively.alreadyAppliedToFun==0
                    ReorientMat=ReorientMat_Interactively.mat*ReorientMat;
                else
                    warning('Transformation already applied for subject %s, skipping orientation\n',AutoDataProcessParameter.SubjectID{i});
                end
            end
        else
            warning('No ReOrient matrix found for subject %s, skipping orientation\n',AutoDataProcessParameter.SubjectID{i});
        end
        
        if ~all(all(ReorientMat==eye(4)))
            
            for SES = 1:AutoDataProcessParameter.Sessions
                
                %Apply to the functional images
                cd([AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,SourceDir,filesep,AutoDataProcessParameter.SubjectID{i}]);
                
                if (AutoDataProcessParameter.IsSliceTiming==1) % Compatibility with the new optional slice timing correction. /EP
                    DirImg=give_filelist('a*.img');
                else
                    DirImg=give_filelist('*.img');
                end
                
                if isempty(DirImg)  %YAN Chao-Gan, 111114. Also support .nii files.
                    DirImg=dir('*.nii.gz');  % Search .nii.gz and unzip; YAN Chao-Gan, 120806.
                    if length(DirImg)==1
                        gunzip(DirImg(1).name);
                        delete(DirImg(1).name);
                    end
                    DirImg=dir('*.nii');
                end
                
                for j=1:length(DirImg)
                    OldMat = spm_get_space(DirImg(j).name);
                    spm_get_space(DirImg(j).name,ReorientMat*OldMat);
                end
                
                if length(DirImg)==1 % delete the .mat file generated by spm_get_space for 4D nii images
                    if exist([DirImg(j).name(1:end-4),'.mat'])==2
                        delete([DirImg(j).name(1:end-4),'.mat']);
                    end
                end
                
                % We must also transform EPI mean  !!! VERY IMPORTANT !!!
                cd([AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,'RealignParameter',filesep,AutoDataProcessParameter.SubjectID{i}]);
                DirImg=give_filelist('*.img');
                
                HasMean=false;
                %                 HasGrandMean=false;
                for j=1:length(DirImg)
                    if length(DirImg(j).name)>4 && strcmp(DirImg(j).name(1:4),'mean')
                        HasMean = true;
                    end
                    %                     if AutoDataProcessParameter.IsMultisession==1
                    %                         if length(DirImg(j).name)>10 && strcmp(DirImg(j).name(1:10),'grand_mean')
                    %                             HasGrandMean = true;
                    %                         end
                    %                     end
                    OldMat = spm_get_space(DirImg(j).name);
                    spm_get_space(DirImg(j).name,ReorientMat*OldMat);
                end
                if ~HasMean && AutoDataProcessParameter.IsRealign==1 && SES==1
                    error('Mean EPI image not found for reorienting (it must be also reoriented!)')
                end
                %                 if ~HasGrandMean && AutoDataProcessParameter.IsMultisession==1 && SES==1
                %                     error('Grand mean EPI image not found for reorienting (it must be also reoriented!)')
                %                 end
                
            end
            
            alreadyAppliedToFun=1;
            number_of_sessions = AutoDataProcessParameter.Sessions;
            mat=ReorientMat_Interactively.mat;
            save([AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1Img',filesep,AutoDataProcessParameter.SubjectID{i},filesep,'ReorientT1ImgMat.mat'],'mat','alreadyAppliedToFun','number_of_sessions');
            
            fprintf('Apply Reorient Mats to functional images for %s: OK\n',AutoDataProcessParameter.SubjectID{i});
            
        end
        
    end
end

set(0,'units','pixels');
a = spm('WinSize','0',1);
if ~all(SPM_screensize==a)
    error('SPM screen bug!')
end

%Normalize
if (AutoDataProcessParameter.IsNormalize>0 && AutoDataProcessParameter.IsNormalize<4)
    
    fprintf('\n------------- Segmentation and normalization -----------------\n\n')
    TargetDir = [SourceDir,'Norm'];
    
    if (AutoDataProcessParameter.IsNormalize==1) %Normalization by using the EPI template directly
        load([ProgramPath,filesep,'Jobmats',filesep,'Normalize.mat']);
        
        for SES = 1:AutoDataProcessParameter.Sessions
            cd([AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,SourceDir]);
            for i=1:AutoDataProcessParameter.SubjectNum
                cd(AutoDataProcessParameter.SubjectID{i});
                if (AutoDataProcessParameter.IsSliceTiming==1) % Compatibility with the new optional slice timing correction. /EP
                    DirImg=give_filelist('a*.img');
                else
                    DirImg=give_filelist('*.img');
                end
                if length(DirImg)~=AutoDataProcessParameter.TimePoints(i,SES)
                    error('Number of images does not match timepoints!');
                end
                FileList=[];
                for j=1:length(DirImg)
                    FileList=[FileList;{[AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,SourceDir,filesep,AutoDataProcessParameter.SubjectID{i},filesep,DirImg(j).name,',1']}];
                end
                MeanFilename=give_filelist([AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,'RealignParameter',filesep,AutoDataProcessParameter.SubjectID{i},filesep,'mean*.img']);
                MeanFilename=[AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,'RealignParameter',filesep,AutoDataProcessParameter.SubjectID{i},filesep,MeanFilename.name,',1'];
                if i~=1
                    jobs{1,1}.spatial{1,1}.normalise{1,1}.estwrite.subj=[jobs{1,1}.spatial{1,1}.normalise{1,1}.estwrite.subj,jobs{1,1}.spatial{1,1}.normalise{1,1}.estwrite.subj(1,1)];
                end
                jobs{1,1}.spatial{1,1}.normalise{1,1}.estwrite.subj(1,i).source={MeanFilename};
                jobs{1,1}.spatial{1,1}.normalise{1,1}.estwrite.subj(1,i).resample=FileList;
                cd('..');
                fprintf(['Normalize Setup:',AutoDataProcessParameter.SubjectID{i},' OK\n']);
            end
            fprintf('\n');
            [SPMPath, fileN, extn] = fileparts(which('spm.m'));
            jobs{1,1}.spatial{1,1}.normalise{1,1}.estwrite.eoptions.template={[SPMPath,filesep,'templates',filesep,'EPI.nii,1']};
            jobs{1,1}.spatial{1,1}.normalise{1,1}.estwrite.roptions.bb=AutoDataProcessParameter.Normalize.BoundingBox;
            jobs{1,1}.spatial{1,1}.normalise{1,1}.estwrite.roptions.vox=AutoDataProcessParameter.Normalize.VoxSize;
            if SPMversion==5
                spm_jobman('run',jobs);
            elseif SPMversion==8  %YAN Chao-Gan, 090925. SPM8 compatible.
                jobs = spm_jobman('spm5tospm8',{jobs});
                spm_jobman('run',jobs{1});
            else
                uiwait(msgbox('The current SPM version is not supported by fDPA. Please install SPM5 or SPM8 first.','Invalid SPM Version.'));
                return
            end
        end
    end
    
    if (AutoDataProcessParameter.IsNormalize>1) %Normalization by using the T1 image segment information
        
        %Backup the T1 images to T1ImgSegment
        try cd([AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1Img']);
        catch
            errordlg(['If the above command fails, you might have NOT checked the T1 DICOM to NIFTI checkbox the program expects the data in T1Img already'],'No T1Img directory found');
            return;
        end
        %if the above command fails, you might have NOT checked the T1 DICOM to
        %NIFTI checkbox (the program expects the data in T1Img already)
        %/Yevhen Hlushchuk 2011-05-26
        
        % Check in co* image exist. Added by YAN Chao-Gan 100510.
        cd(AutoDataProcessParameter.SubjectID{1});
        DirCo=give_filelist('co*.img');
        if isempty(DirCo)
            DirImg=give_filelist('*.img');
            if length(DirImg)==1
                warning('!!! No co* T1 image (T1 image which is reoriented to the nearest orthogonal direction to ''canonical space'' and removed excess air surrounding the individual as well as parts of the neck below the cerebellum) is found !!!');
            else
                errordlg(['No co* T1 image (T1 image which is reoriented to the nearest orthogonal direction to ''canonical space'' and removed excess air surrounding the individual as well as parts of the neck below the cerebellum) is found. And there are too many T1 images detected in T1Img directory. Please determine which T1 image you want to use in unified segmentation and delete the others from the T1Img directory, then re-run the analysis.'],'No co* T1 image is found');
                return;
            end
        end
        cd('..');
        
        %BiasCorrectmeanEPI
        %Getting BIAS-corrected EPI-mean to improve coregistration of EPI images to
        %anatomical /YH 2012-09-17
        %         if AutoDataProcessParameter.IsMultisession==1
        %             meanImageFileFilter = 'grand_mean*.img';% if no BIAS correction is applied (which adds 'm' as prefix) then one uses normal mean
        %         else
        meanImageFileFilter = 'mean*.img';% if no BIAS correction is applied (which adds 'm' as prefix) then one uses normal mean                
        
        %         end
        if (AutoDataProcessParameter.BiasCorrectmeanEPI == 1) % should be moved to before the coregistration step!!!!
            
            if SPMversion==8
                clear matlabbatch;
                run([ProgramPath,filesep,'Jobmats',filesep,'BiasCorrectmeanEPI_job.m']);
                for i = 1:AutoDataProcessParameter.SubjectNum
                    meanImageFileDir = give_filelist([AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,...
                        'RealignParameter',filesep,AutoDataProcessParameter.SubjectID{i},...
                        filesep,meanImageFileFilter]);
                    matlabbatch{i}.spm.spatial.preproc.data = {[AutoDataProcessParameter,MULTISESSION_PREFIX.DataProcessDir,filesep,...
                        'RealignParameter',filesep,AutoDataProcessParameter.SubjectID{i},...
                        filesep,meanImageFileDir(1).name]}; % Segment: Data - cfg_files
                    matlabbatch{i}.spm.spatial.preproc.opts.tpm = {...
                        [SPMPath,filesep,'tpm',filesep,'grey.nii'];...
                        [SPMPath,filesep,'tpm',filesep,'white.nii'];...
                        [SPMPath,filesep,'tpm',filesep,'csf.nii']};
                end
                
            else
                
                load([ProgramPath,filesep,'Jobmats',filesep,'BiasCorrectmeanEPISPM12.mat']);
                for i = 1:AutoDataProcessParameter.SubjectNum
                    meanImageFileDir = give_filelist([AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,...
                        'RealignParameter',filesep,AutoDataProcessParameter.SubjectID{i},...
                        filesep,meanImageFileFilter]);
                    matlabbatch{i,1}.spm.tools.oldseg.data = {[AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,...
                        'RealignParameter',filesep,AutoDataProcessParameter.SubjectID{i},...
                        filesep,meanImageFileDir(1).name]}; % Segment: Data - cfg_files
                    matlabbatch{i,1}.spm.tools.oldseg.opts.tpm = { ...
                        [SPMPath,filesep,'toolbox',filesep,'OldSeg',filesep,'grey.nii'];...
                        [SPMPath,filesep,'toolbox',filesep,'OldSeg',filesep,'white.nii'];...
                        [SPMPath,filesep,'toolbox',filesep,'OldSeg',filesep,'csf.nii']};
                    % Segment: Tissue probability maps - cfg_files
                end
            end
            run_batch(matlabbatch,AutoDataProcessParameter.requested_nworker);
            clear matlabbatch;  % clears the variable jobs, do the other modules work without this cleaning? YH 2012/09/18
            %             if AutoDataProcessParameter.IsMultisession==1
            %                 meanImageFileFilter = 'mgrand_mean*.img';
            %             else
            meanImageFileFilter = 'mmean*.img';
            %             end
            %ONE HAS GOT TO MOVE TME MMEAN FILE BACK FOR COREGISTRATION
        end
        
        %Coregister YH03/2013 moved this section to after the segmentation
        %because now it uses skull-stripped T1 by default
        %That is it uses the mean image in RealignmentParameter directory
        %for the coregistration
        if SPMversion==8
            load([ProgramPath,filesep,'Jobmats',filesep,'Coregister.mat']);
        else
            load([ProgramPath,filesep,'Jobmats',filesep,'CoregisterSPM12.mat']);
        end
                
        for i=1:AutoDataProcessParameter.SubjectNum
            %NOTE: below the source and the template(anat) images have
            %been swapped by EP and YH to correspond to SPM8 manual 05/2011
            MeanDir=give_filelist([AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'RealignParameter',...
                filesep,AutoDataProcessParameter.SubjectID{i},filesep,meanImageFileFilter]);
            SourceFile=[AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'RealignParameter',filesep,AutoDataProcessParameter.SubjectID{i},filesep,MeanDir(1).name,',1'];
            RefDir=dir([AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1ImgSegment',filesep,AutoDataProcessParameter.SubjectID{i},filesep,'skullstripped.img']);%YH 03/2013 modified the default coregistration to skull-stripped
            RefFile=[AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1ImgSegment',filesep,AutoDataProcessParameter.SubjectID{i},filesep,RefDir(1).name];
            if i~=1
                if SPMversion==8
                    jobs=[jobs,{jobs{1,1}}];
                else
                    matlabbatch{i} = matlabbatch{1};
                end
            end
            
            TotalFileList=[];
            for SES = 1:AutoDataProcessParameter.Sessions
                
                if (AutoDataProcessParameter.IsSliceTiming==1) % Compatibility with the new optional slice timing correction. /EP
                    DirImg=give_filelist([AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,SourceDir,filesep,AutoDataProcessParameter.SubjectID{i},filesep,'a*.img']);
                else
                    DirImg=give_filelist([AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,SourceDir,filesep,AutoDataProcessParameter.SubjectID{i},filesep,'*.img']);
                end
                
                FileList=cell(length(DirImg),1);
                for j=1:length(DirImg)
                    FileList(j)={[AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,SourceDir,filesep,AutoDataProcessParameter.SubjectID{i},filesep,DirImg(j).name,',1']};
                end
                TotalFileList = [TotalFileList;FileList];
            end
            
            if SPMversion==8
                jobs{1,i}.spatial{1,1}.coreg{1,1}.estimate.ref={RefFile};
                jobs{1,i}.spatial{1,1}.coreg{1,1}.estimate.source={SourceFile};
                jobs{1,i}.spatial{1,1}.coreg{1,1}.estimate.other=TotalFileList; % New. For compatibility with "only mean image" option in realignment. /EP
            else
                matlabbatch{i}.spm.spatial.coreg.estimate.ref={RefFile};
                matlabbatch{i}.spm.spatial.coreg.estimate.source={SourceFile};
                matlabbatch{i}.spm.spatial.coreg.estimate.other=TotalFileList;
            end
            
            fprintf(['Coregistering Setup:',AutoDataProcessParameter.SubjectID{i},' OK\n']);
        end
        fprintf('\n');
        if SPMversion==8  %YAN Chao-Gan, 090925. SPM8 compatible.
            jobs = spm_jobman('spm5tospm8',{jobs});
            run_batch(jobs{1},AutoDataProcessParameter.requested_nworker);
            clear jobs;
        elseif SPMversion==12
            run_batch(matlabbatch,AutoDataProcessParameter.requested_nworker);
            clear matlabbatch;
        else
            uiwait(msgbox('The current SPM version is not supported by fDPA. Please install SPM5 or SPM8 first.','Invalid SPM Version.'));
            return
        end
        
        if (AutoDataProcessParameter.IsNormalize==2)
            
            %Normalize-Write: Using the segment information
            load([ProgramPath,filesep,'Jobmats',filesep,'Normalize_Write.mat']);
            for SES = 1:AutoDataProcessParameter.Sessions
                cd([AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,SourceDir]);
                for i=1:AutoDataProcessParameter.SubjectNum
                    cd(AutoDataProcessParameter.SubjectID{i});
                    
                    if (AutoDataProcessParameter.IsSliceTiming==1) % Compatibility with the new optional slice timing correction. /EP
                        DirImg=give_filelist('a*.img');
                    else
                        DirImg=give_filelist('*.img');
                    end
                    
                    if length(DirImg)~=AutoDataProcessParameter.TimePoints(i,SES)
                        error('Number of images does not match timepoints!')
                    end
                    FileList=cell(length(DirImg),1);
                    for j=1:length(DirImg)
                        FileList(j)={[AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,SourceDir,filesep,AutoDataProcessParameter.SubjectID{i},filesep,DirImg(j).name,',1']};
                    end
                    
                    MatFileDir=dir([AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1ImgSegment',filesep,AutoDataProcessParameter.SubjectID{i},filesep,'*seg_sn.mat']);
                    MatFilename=[AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1ImgSegment',filesep,AutoDataProcessParameter.SubjectID{i},filesep,MatFileDir(1).name];
                    if i~=1
                        jobs=[jobs,{jobs{1,1}}];
                    end
                    jobs{1,i}.spatial{1,1}.normalise{1,1}.write.subj.matname={MatFilename};
                    jobs{1,i}.spatial{1,1}.normalise{1,1}.write.subj.resample=FileList;
                    jobs{1,i}.spatial{1,1}.normalise{1,1}.write.roptions.bb=AutoDataProcessParameter.Normalize.BoundingBox;
                    jobs{1,i}.spatial{1,1}.normalise{1,1}.write.roptions.vox=AutoDataProcessParameter.Normalize.VoxSize;
                    cd('..');
                    fprintf(['Normalize-Write Setup:',AutoDataProcessParameter.SubjectID{i},' OK\n']);
                end
                fprintf('\n');
                jobs = spm_jobman('spm5tospm8',{jobs});
                run_batch(jobs{1},AutoDataProcessParameter.requested_nworker);
            end
            
            %Normalize T1 images. 05/11 /EP
            jobs=[];
            for i=1:AutoDataProcessParameter.SubjectNum
                
                T1Dir=give_filelist([AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1ImgSegment',filesep,AutoDataProcessParameter.SubjectID{i},filesep,'mco*.img']);
                if isempty(T1Dir)
                    T1Dir=give_filelist([AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1ImgSegment',filesep,AutoDataProcessParameter.SubjectID{i},filesep,'co*.img']); %co...img will be used if mco...img cannot be found.
                end
                FileList=cell(1);
                FileList(1)={[AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1ImgSegment',filesep,AutoDataProcessParameter.SubjectID{i},filesep,T1Dir(1).name]};
                MatFileDir=dir([AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1ImgSegment',filesep,AutoDataProcessParameter.SubjectID{i},filesep,'*seg_sn.mat']);
                MatFilename=[AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1ImgSegment',filesep,AutoDataProcessParameter.SubjectID{i},filesep,MatFileDir(1).name];
                if i~=1
                    jobs=[jobs,{jobs{1,1}}];
                end
                jobs{1,i}.spatial{1,1}.normalise{1,1}.write.subj.matname={MatFilename};
                jobs{1,i}.spatial{1,1}.normalise{1,1}.write.subj.resample=FileList;
                jobs{1,i}.spatial{1,1}.normalise{1,1}.write.roptions.bb=AutoDataProcessParameter.Normalize.BoundingBox;
                jobs{1,i}.spatial{1,1}.normalise{1,1}.write.roptions.vox=[1 1 1];
                fprintf(['Normalize-Write Setup:',AutoDataProcessParameter.SubjectID{i},' OK\n']);
            end
            fprintf('\n');
            
            jobs = spm_jobman('spm5tospm8',{jobs});
            run_batch(jobs{1},AutoDataProcessParameter.requested_nworker);
            
        end
        
        if (AutoDataProcessParameter.IsNormalize==3)
            for SES = 1:AutoDataProcessParameter.Sessions
                cd([AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,SourceDir]);
                matlabbatch = {};
                for i=1:AutoDataProcessParameter.SubjectNum
                    cd(AutoDataProcessParameter.SubjectID{i});
                    if (AutoDataProcessParameter.IsSliceTiming==1) % Compatibility with the new optional slice timing correction. /EP
                        DirImg=give_filelist('a*.img');
                    else
                        DirImg=give_filelist('*.img');
                    end
                    MatFile=dir([AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1ImgSegment',filesep,AutoDataProcessParameter.SubjectID{i},filesep,'y_*.nii']);
                    if length(MatFile)>1
                        error('Multiple deformation fields found, there should be only one!');
                    end
                    a = [AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1ImgSegment',filesep,AutoDataProcessParameter.SubjectID{i},filesep,MatFile.name];
                    % must be in the right folder here!
                    if AutoDataProcessParameter.isNormalizeMNI152==1
                        matlabbatch{i}=NewNormalizeWriteMNI(DirImg,a,1,SPMversion);
                    else
                        matlabbatch{i}=NewNormalizeWrite(DirImg,a,AutoDataProcessParameter.Normalize.VoxSize,AutoDataProcessParameter.Normalize.BoundingBox,SPMversion);
                    end
                    cd('..');
                    fprintf(['New Normalize-Write for Fun OK:',AutoDataProcessParameter.SubjectID{i},'\n']);
                end
                run_batch(matlabbatch,AutoDataProcessParameter.requested_nworker);
                fprintf('\n')
            end
            
            cd([AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1ImgSegment']);
            matlabbatch = {};
            for i=1:AutoDataProcessParameter.SubjectNum
                cd(AutoDataProcessParameter.SubjectID{i});
                T1Dir=give_filelist('mco*.nii');
                if isempty(T1Dir)
                    T1Dir=give_filelist('co*.img'); %co...img will be used if mco...img cannot be found.
                end
                FileList=T1Dir;
                T1Dir = dir('c1co*.nii');
                FileList(end+1)=T1Dir(1);
                T1Dir = dir('c2co*.nii');
                FileList(end+1)=T1Dir(1);
                T1Dir = dir('c3co*.nii');
                FileList(end+1)=T1Dir(1);
                
                MatFile=dir([AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1ImgSegment',filesep,AutoDataProcessParameter.SubjectID{i},filesep,'y_*.nii']);
                if length(MatFile)>1
                    error('Multiple deformation fields found, there should be only one!');
                end
                matlabbatch{i}=NewNormalizeWriteMNI(FileList,[pwd,filesep,MatFile.name],1,SPMversion);
                fprintf(['New Normalize-Write for T1 OK:',AutoDataProcessParameter.SubjectID{i},'\n']);
                cd('..');
            end
            run_batch(matlabbatch,AutoDataProcessParameter.requested_nworker);
            
            fprintf('\n')
            
        end
        
        
        %Copy the normalized files to DataProcessDir\FunImgNormalized %YAN Chao-Gan, 101018. Check Head motion moved right after realign
        for SES = 1:AutoDataProcessParameter.Sessions
            cd([AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,SourceDir]);
            for i=1:AutoDataProcessParameter.SubjectNum
                cd(AutoDataProcessParameter.SubjectID{i});
                mkdir(['..',filesep,'..',filesep,TargetDir,filesep,AutoDataProcessParameter.SubjectID{i}])
                
                movefile('w*',['..',filesep,'..',filesep,TargetDir,filesep,AutoDataProcessParameter.SubjectID{i}])
                cd('..');
                fprintf(['Moving Normalized Files:',AutoDataProcessParameter.SubjectID{i},' OK\n']);
            end
        end
        fprintf('\n');
        
        %Generate the pictures for checking normalization %YAN Chao-Gan, 091001
        
        SourceDir = TargetDir;
        
        if license('test','image_toolbox') % needed for imshow etc.
            
            global DPARSF_rest_sliceviewer_Cfg;              
            
            for SES = 1:AutoDataProcessParameter.Sessions
                
                DPARSF_rest_sliceviewer_Cfg=[];
                
                if exist([AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,'PicturesForChkNormalization'],'dir')==0
                    mkdir([AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,'PicturesForChkNormalization']);
                end
                cd([AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,'PicturesForChkNormalization']);                                
                
                try
                    
                    h=DPARSF_rest_sliceviewer;
                    [RESTPath, fileN, extn] = fileparts(which('rest.m'));
                    Ch2Filename=[RESTPath,filesep,'Template',filesep,'ch2.nii'];
                    set(DPARSF_rest_sliceviewer_Cfg.Config(1).hOverlayFile, 'String', Ch2Filename);
                    DPARSF_rest_sliceviewer_Cfg.Config(1).Overlay.Opacity=0.2;
                    DPARSF_rest_sliceviewer('ChangeOverlay', h);
                    for i=1:AutoDataProcessParameter.SubjectNum
                        Dir=give_filelist([AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,SourceDir,filesep,AutoDataProcessParameter.SubjectID{i},filesep,'*.img']);
                        Filename=[AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,SourceDir,filesep,AutoDataProcessParameter.SubjectID{i},filesep,Dir(1).name];
                        fDPA_Normalized_TempImage =fullfile(tempdir,['DPARSF_Normalized_TempImage','_',rest_misc('GetCurrentUser'),'.img']);
                        y_Reslice(Filename,fDPA_Normalized_TempImage,[1 1 1],0)
                        set(DPARSF_rest_sliceviewer_Cfg.Config(1).hUnderlayFile, 'String', fDPA_Normalized_TempImage);
                        set(DPARSF_rest_sliceviewer_Cfg.Config(1).hMagnify ,'Value',2);
                        DPARSF_rest_sliceviewer('ChangeUnderlay', h);
                        eval(['print(''-dtiff'',''-r300'',''',AutoDataProcessParameter.SubjectID{i},'_EPI_first_vol_A.tiff'',h);']);
                        fprintf(['Generating the pictures for checking normalization (EPI): ',AutoDataProcessParameter.SubjectID{i},' OK\n']);
                    end
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
                    for i=1:AutoDataProcessParameter.SubjectNum
                        Dir=give_filelist([AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,SourceDir,filesep,AutoDataProcessParameter.SubjectID{i},filesep,'*.img']);
                        Filename=[AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,SourceDir,filesep,AutoDataProcessParameter.SubjectID{i},filesep,Dir(end).name];
                        fDPA_Normalized_TempImage =fullfile(tempdir,['DPARSF_Normalized_TempImage','_',rest_misc('GetCurrentUser'),'.img']);
                        y_Reslice(Filename,fDPA_Normalized_TempImage,[1 1 1],0);
                        nii=load_nii(fDPA_Normalized_TempImage);
                        mat=nii.img;
                        tit=['Subject ',AutoDataProcessParameter.SubjectID{i},' last EPI volume'];
                        save_EPI_preview(mat_base,mat,...
                            tit,...
                            [AutoDataProcessParameter.SubjectID{i},'_EPI_last_vol_B.tiff']);
                        fprintf(['Generating the pictures for checking normalization (EPI): ',AutoDataProcessParameter.SubjectID{i},' OK\n']);
                    end
                    clear mat_base mat
                    
                catch err
                    warning('Failed to create multislice EPI check: %s',err.message);
                end
            end
        else  % Added by YAN Chao-Gan, 100420.
            fprintf('Since Image Processing Toolbox of MATLAB is not valid, the pictures for checking normalization will not be generated.\n');
            %fid = fopen('Warning.txt','at+');
            %fprintf(fid,'%s','Since Image Processing Toolbox of MATLAB is not valid, the pictures for checking normalization will not be generated.\n');
            %fclose(fid);
        end                
        
    end
    
end

set(0,'units','pixels');
a = spm('WinSize','0',1);
if ~all(SPM_screensize==a)
    error('SPM screen bug!')
end

if (AutoDataProcessParameter.IsNormalize==4)
    
    fprintf('\n------------- Segmentation and normalization -----------------\n\n')
    TargetDir = [SourceDir,'Norm'];
    
    %BiasCorrectmeanEPI
    %Getting BIAS-corrected EPI-mean to improve coregistration of EPI images to
    %anatomical /YH 2012-09-17
    %     if AutoDataProcessParameter.IsMultisession==1
    %         meanImageFileFilter = 'grand_mean*.img';% if no BIAS correction is applied (which adds 'm' as prefix) then one uses normal mean
    %     else
    meanImageFileFilter = 'mean*.img';% if no BIAS correction is applied (which adds 'm' as prefix) then one uses normal mean
    %     end
    if (AutoDataProcessParameter.BiasCorrectmeanEPI == 1) % should be moved to before the coregistration step!!!!
        
        nrun = AutoDataProcessParameter.SubjectNum; % enter the number of runs here
        jobfile = {[ProgramPath,filesep,'Jobmats',filesep,'BiasCorrectmeanEPI_job.m']};
        jobs = repmat(jobfile, 1, nrun);
        inputs = cell(1, nrun);
        for crun = 1:nrun
            meanImageFileDir = dir([AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,...
                'RealignParameter',filesep,AutoDataProcessParameter.SubjectID{crun},...
                filesep,meanImageFileFilter]);
            inputs{1, crun} = {[AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,...
                'RealignParameter',filesep,AutoDataProcessParameter.SubjectID{crun},...
                filesep,meanImageFileDir(1).name]}; % Segment: Data - cfg_files
            inputs{2, crun} = {[SPMPath,filesep,'tpm',filesep,'grey.nii'];[SPMPath,filesep,'tpm',filesep,'white.nii'];[SPMPath,filesep,'tpm',filesep,'csf.nii']};
            % Segment: Tissue probability maps - cfg_files
        end
        spm_jobman('serial', jobs, '', inputs{:});
        clear jobs % clears the variable jobs, do the other modules work without this cleaning? YH 2012/09/18
        %         if AutoDataProcessParameter.IsMultisession==1
        %             meanImageFileFilter = 'mgrand_mean*.img';
        %         else
        meanImageFileFilter = 'mmean*.img';
        %         end
        %ONE HAS GOT TO MOVE TME MMEAN FILE BACK FOR COREGISTRATION
    end
    
    
    for i=1:AutoDataProcessParameter.SubjectNum
        skullstripped=[AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1ImgSegment',filesep,AutoDataProcessParameter.SubjectID{i},filesep,'skullstripped.nii'];
        functional_mean = dir([AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'RealignParameter',filesep,AutoDataProcessParameter.SubjectID{i},filesep,meanImageFileFilter]);
        functional_mean = [AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'RealignParameter',filesep,AutoDataProcessParameter.SubjectID{i},filesep,functional_mean(1).name];
        
        structural = dir([AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1ImgSegment',filesep,AutoDataProcessParameter.SubjectID{i},filesep,'FAST_biascorrected_*.nii']);
        structural = [AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1ImgSegment',filesep,AutoDataProcessParameter.SubjectID{i},filesep,structural(1).name];
        
        
        for SES = 1:AutoDataProcessParameter.Sessions
            cd([AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,SourceDir]);
            cd(AutoDataProcessParameter.SubjectID{i});
            if (AutoDataProcessParameter.IsSliceTiming==1) % Compatibility with the new optional slice timing correction. /EP
                DirImg=give_filelist('a*.img');
            else
                DirImg=give_filelist('*.img');
            end
            
            a = [AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,TargetDir,filesep,AutoDataProcessParameter.SubjectID{i}];
            mkdir(a);
            fsl_normalization_part2(skullstripped,structural,functional_mean,DirImg,a);
            fprintf(['FSL normalization for ',AutoDataProcessParameter.SubjectID{i},' OK\n']);
            cd ..
        end
        
    end
    
    SourceDir = TargetDir;
    
    if license('test','image_toolbox') % Added by YAN Chao-Gan, 100420.
        
        global DPARSF_rest_sliceviewer_Cfg;
        
        for SES = 1:AutoDataProcessParameter.Sessions
            
            DPARSF_rest_sliceviewer_Cfg=[];
            
            mkdir([AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,'PicturesForChkNormalization']);
            cd([AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,'PicturesForChkNormalization']);

            try
                
                h=DPARSF_rest_sliceviewer;
                [RESTPath, fileN, extn] = fileparts(which('rest.m'));
                Ch2Filename=[RESTPath,filesep,'Template',filesep,'ch2.nii'];
                set(DPARSF_rest_sliceviewer_Cfg.Config(1).hOverlayFile, 'String', Ch2Filename);
                DPARSF_rest_sliceviewer_Cfg.Config(1).Overlay.Opacity=0.2;
                DPARSF_rest_sliceviewer('ChangeOverlay', h);
                for i=1:AutoDataProcessParameter.SubjectNum
                    Dir=give_filelist([AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,SourceDir,filesep,AutoDataProcessParameter.SubjectID{i},filesep,'*.img']);
                    Filename=[AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,SourceDir,filesep,AutoDataProcessParameter.SubjectID{i},filesep,Dir(1).name];
                    fDPA_Normalized_TempImage =fullfile(tempdir,['DPARSF_Normalized_TempImage','_',rest_misc('GetCurrentUser'),'.img']);
                    y_Reslice(Filename,fDPA_Normalized_TempImage,[1 1 1],0)
                    set(DPARSF_rest_sliceviewer_Cfg.Config(1).hUnderlayFile, 'String', fDPA_Normalized_TempImage);
                    set(DPARSF_rest_sliceviewer_Cfg.Config(1).hMagnify ,'Value',2);
                    DPARSF_rest_sliceviewer('ChangeUnderlay', h);
                    eval(['print(''-dtiff'',''-r300'',''',AutoDataProcessParameter.SubjectID{i},'_EPI_first_vol_A.tiff'',h);']);
                    fprintf(['Generating the pictures for checking normalization (EPI): ',AutoDataProcessParameter.SubjectID{i},' OK\n']);
                end
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
                for i=1:AutoDataProcessParameter.SubjectNum
                    Dir=give_filelist([AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,SourceDir,filesep,AutoDataProcessParameter.SubjectID{i},filesep,'*.img']);
                    Filename=[AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,SourceDir,filesep,AutoDataProcessParameter.SubjectID{i},filesep,Dir(end).name];
                    fDPA_Normalized_TempImage =fullfile(tempdir,['DPARSF_Normalized_TempImage','_',rest_misc('GetCurrentUser'),'.img']);
                    y_Reslice(Filename,fDPA_Normalized_TempImage,[1 1 1],0);
                    nii=load_nii(fDPA_Normalized_TempImage);
                    mat=nii.img;
                    tit=['Subject ',AutoDataProcessParameter.SubjectID{i},' last EPI volume'];
                    save_EPI_preview(mat_base,mat,...
                        tit,...
                        [AutoDataProcessParameter.SubjectID{i},'_EPI_last_vol_B.tiff']);
                    fprintf(['Generating the pictures for checking normalization (EPI): ',AutoDataProcessParameter.SubjectID{i},' OK\n']);
                end
                clear mat_base mat
                
            catch err
                warning('Failed to create multislice EPI check: %s',err.message);
            end
            
            %         for i=1:AutoDataProcessParameter.SubjectNum
            %             cd([AutoDataProcessParameter.DataProcessDir,filesep,'T1ImgSegment',filesep,AutoDataProcessParameter.SubjectID{i}]);
            %             DirImg=dir('c1co*.img');
            %             if isempty(DirImg)
            %                 DirImg=dir('c1co*.nii');
            %             end
            %             fDPA_Normalized_TempImage =fullfile(tempdir,['DPARSF_Normalized_TempImage','_',rest_misc('GetCurrentUser'),'.img']);
            %             y_Reslice(DirImg(1).name,fDPA_Normalized_TempImage,[1 1 1],0)
            %             nii=load_nii(fDPA_Normalized_TempImage);
            %             cd([AutoDataProcessParameter.DataProcessDir,filesep,'PicturesForChkNormalization']);
            %             save_volume_slices(nii.img,...
            %                 [AutoDataProcessParameter.SubjectID{i},'_grey_matter.tiff'],...
            %                 [AutoDataProcessParameter.SubjectID{i},' segmented grey (co1)'])
            %             fprintf(['Generating the pictures for checking segmentation (grey matter): ',AutoDataProcessParameter.SubjectID{i},' OK\n']);
            %         end
            %         fprintf('\n');
            
            if SES==1
                for i=1:AutoDataProcessParameter.SubjectNum
                    cd([AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'T1ImgSegment',filesep,AutoDataProcessParameter.SubjectID{i}]);
                    DirImg=dir('skullstripped.img');
                    if isempty(DirImg)
                        DirImg=dir('skullstripped.nii');
                    end
                    fDPA_Normalized_TempImage =fullfile(tempdir,['DPARSF_Normalized_TempImage','_',rest_misc('GetCurrentUser'),'.img']);
                    y_Reslice(DirImg(1).name,fDPA_Normalized_TempImage,[1 1 1],0)
                    nii=load_nii(fDPA_Normalized_TempImage);
                    cd([AutoDataProcessParameter.DataProcessDir,filesep,'PicturesForChkNormalization']);
                    save_volume_slices(nii.img,...
                        [AutoDataProcessParameter.SubjectID{i},'_skullstripped.tiff'],...
                        [AutoDataProcessParameter.SubjectID{i},' skullstripped'])
                    fprintf(['Generating the pictures for checking skullstripping : ',AutoDataProcessParameter.SubjectID{i},' OK\n']);
                end
            end
            
            fprintf('\n');
        end
    else  % Added by YAN Chao-Gan, 100420.
        fprintf('Since Image Processing Toolbox of MATLAB is not valid, the pictures for checking normalization will not be generated.\n');
    end
    
    
end

close_all_new_images(original_fig_handles);
drawnow;

if (AutoDataProcessParameter.FinalizeEPIs==1)
    
    fprintf('\n------------- Reslicing unnormalized EPIs -----------------\n\n')
    
    if SPMversion==8
        error('Missing (not yet implemented)!')
        %load([ProgramPath,filesep,'Jobmats',filesep,'RealignWrite.mat']);
    else
        load([ProgramPath,filesep,'Jobmats',filesep,'RealignResliceSPM12.mat']);
    end
       
    for i=1:AutoDataProcessParameter.SubjectNum
        
        MeanDir=dir([AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'RealignParameter',...
            filesep,AutoDataProcessParameter.SubjectID{i},filesep,meanImageFileFilter]);
        SourceFile=[AutoDataProcessParameter.DataProcessDir,MULTISESSION_PREFIX,filesep,'RealignParameter',filesep,AutoDataProcessParameter.SubjectID{i},filesep,MeanDir(1).name,',1'];

        FileList=[];
        for SES = 1:AutoDataProcessParameter.Sessions
            
            cd([AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,'FunImg']);            
            cd(AutoDataProcessParameter.SubjectID{i});
            
            if (AutoDataProcessParameter.IsSliceTiming==1) % Compatibility with the new optional slice timing correction. /EP
                DirImg=give_filelist('a*.img');
            else
                DirImg=give_filelist('*.img');
            end
            if length(DirImg)~=AutoDataProcessParameter.TimePoints(i,SES)
                error('Number of images does not match timepoints!')
            end            
            
            for j=1:length(DirImg)
                FileList=[FileList;{[AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,'FunImg',filesep,AutoDataProcessParameter.SubjectID{i},filesep,DirImg(j).name,',1']}];
            end
            if SPMversion==8
%                 if i~=1 && SES==1
%                     jobs{1,1}.spatial{1,1}.realign=[jobs{1,1}.spatial{1,1}.realign,{jobs{1,1}.spatial{1,1}.realign{1,1}}];
%                 end
%                 jobs{1,1}.spatial{1,1}.realign{1,i}.write.roptions.which = [1,0]; % ""
%                 jobs{1,1}.spatial{1,1}.realign{1,i}.write.data{1,SES}=FileList;
            else
                if i>1 && SES==1
                    matlabbatch{i}=matlabbatch{1};
                end                
            end                        
        end
        
        FileList=[{SourceFile};FileList];
        matlabbatch{i}.spm.spatial.realign.write.data=FileList;
        
        fprintf(['Realign Setup:',AutoDataProcessParameter.SubjectID{i},' OK\n']);
    end
    if SPMversion==8
        jobs = spm_jobman('spm5tospm8',{jobs});
        run_batch(jobs{1},AutoDataProcessParameter.requested_nworker);
        clear jobs;
    elseif SPMversion==12
        run_batch(matlabbatch,AutoDataProcessParameter.requested_nworker);
        clear matlabbatch;
    else
        uiwait(msgbox('The current SPM version is not supported by fDPA. Please install SPM5 or SPM8 first.','Invalid SPM Version.'));
        return
    end            
    
    fprintf('\n------------- Creating 4Ds -----------------\n\n')    
    k=0;
    matlabbatch=[];
    for SES = 1:AutoDataProcessParameter.Sessions
        cd([AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES}]);
        MySourceDir = [AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,'FunImg'];
        
        for i=1:AutoDataProcessParameter.SubjectNum
            
            cd([MySourceDir,filesep,AutoDataProcessParameter.SubjectID{i}]);
            if (AutoDataProcessParameter.IsSliceTiming==1)
                DirImg=give_filelist('ra*.img');
            else
                DirImg=give_filelist('r*.img');
            end
            FileList=cell(length(DirImg),1);
            for j=1:length(DirImg)
                FileList(j)={[MySourceDir,filesep,AutoDataProcessParameter.SubjectID{i},filesep,DirImg(j).name,',1']};
            end
            
            % test that files really are aligned
            nii1=load_nii_hdr(DirImg(1).name);
            nii2=load_nii_hdr(DirImg(end).name);
            if max(abs(nii1.dime.dim-nii2.dime.dim))>0 ...
                    || max(abs(nii1.hist.srow_x-nii2.hist.srow_x))>1e-6 ...
                    || max(abs(nii1.hist.srow_y-nii2.hist.srow_y))>1e-6 ...
                    || max(abs(nii1.hist.srow_z-nii2.hist.srow_z))>1e-6
                error('Headers of resliced IMGs should be identical!')
            end
            
            k=k+1;
            matlabbatch{k}.spm.util.cat.vols = FileList;
            matlabbatch{k}.spm.util.cat.name = '4D.nii';
            matlabbatch{k}.spm.util.cat.dtype = 16;
            
            fprintf(['4D Conversion Setup:',AutoDataProcessParameter.SubjectID{i},' OK\n']);
        end
    end
    run_batch(matlabbatch,AutoDataProcessParameter.requested_nworker);
    
    % move 4D into new folder
    fprintf('\n------------- Moving 4Ds -----------------\n\n')   
    for SES = 1:AutoDataProcessParameter.Sessions
        cd([AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES}]);
        MyTargetDir = [AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,'FunImgNii'];
        if ~exist(MyTargetDir,'dir')
            mkdir(MyTargetDir);
        end
        MySourceDir = [AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,'FunImg'];
        
        for i=1:AutoDataProcessParameter.SubjectNum
            
            cd([MySourceDir,filesep,AutoDataProcessParameter.SubjectID{i}]);
            
            if ~exist([MyTargetDir,filesep,AutoDataProcessParameter.SubjectID{i}],'dir')
                mkdir([MyTargetDir,filesep,AutoDataProcessParameter.SubjectID{i}]);
            end
            movefile([MySourceDir,filesep,AutoDataProcessParameter.SubjectID{i},filesep,'4D.*'],[MyTargetDir,filesep,AutoDataProcessParameter.SubjectID{i}]);
        end
    end
    fprintf('\n')
        
end

%ECG and Respiration artifact removal. 06/11 /EP
%Using DRIFTER

if (AutoDataProcessParameter.Drifter==1)
    error('DIFTER CODE OUT OF DATE, SHOULDP BE UPDATED!')
    
    fprintf('\n------------- DRIFTER -----------------\n\n')
    spm_jobman('initcfg');
    TargetDir = [TargetDir,'Drift'];
    
    for i=1:AutoDataProcessParameter.SubjectNum
        DirEcg = dir([AutoDataProcessParameter.DataProcessDir,filesep,'Phys',filesep,AutoDataProcessParameter.SubjectID{i},filesep,'ECG*']);
        DirResp = dir([AutoDataProcessParameter.DataProcessDir,filesep,'Phys',filesep,AutoDataProcessParameter.SubjectID{i},filesep,'Resp*']);
        
        if (length(DirEcg) ~= 1) || (length(DirResp) ~= 1)
            Error={'Missing or invalid phys data. Please put the phys data under "Phys\[Subject_name]" folders. A single ECG data file and a single Respiration data file are expected per subject.'};
        end
        if ~isempty(Error)
            disp(Error);
            return;
        end
        
        ecg = load([AutoDataProcessParameter.DataProcessDir,filesep,'Phys',filesep,AutoDataProcessParameter.SubjectID{i},filesep,DirEcg(1).name]);
        resp = load([AutoDataProcessParameter.DataProcessDir,filesep,'Phys',filesep,AutoDataProcessParameter.SubjectID{i},filesep,DirResp(1).name]);
        
        data_path = [AutoDataProcessParameter.DataProcessDir,filesep,SourceDir,filesep,AutoDataProcessParameter.SubjectID{i},filesep];
        InputImages = spm_select('FPListRec', data_path, '^.*\.img$');
        
        clear jobs;
        
        jobs{1}.spm.tools.drifter.mode = 1; % 0 or 1
        jobs{1}.spm.tools.drifter.prefix = 'n';
        jobs{1}.spm.tools.drifter.epidata.files = InputImages;
        jobs{1}.spm.tools.drifter.visual = 1;
        
        jobs{1}.spm.tools.drifter.epidata.tr = -1; % AutoDataProcessParameter.SliceTiming.TR * 1000
        jobs{1}.spm.tools.drifter.refdata(1).name     = 'Cardiac Signal';
        
        if (strcmp(DirEcg(1).name((length(DirEcg(1).name)-3):length(DirEcg(1).name)),'.mat'))
            %fnames = fieldnames(ecg);
            %EcgName = strcat('ecg.', fnames(1));
            %jobs{1}.spm.tools.drifter.refdata(1).data    = genvarname(EcgName);
            jobs{1}.spm.tools.drifter.refdata(1).data     = ecg.ecg;
        else
            jobs{1}.spm.tools.drifter.refdata(1).data     = ecg;
        end
        
        jobs{1}.spm.tools.drifter.refdata(1).dt       = 2/1000;
        jobs{1}.spm.tools.drifter.refdata(1).downdt   = 1/10;
        jobs{1}.spm.tools.drifter.refdata(1).freqlist = 60:120;
        jobs{1}.spm.tools.drifter.refdata(1).sd = 0.8;
        
        % Number of periodics to estimate (fundamental + number of harmonics)
        jobs{1}.spm.tools.drifter.refdata(1).N        = 1;
        
        % There is no need to estimate as many periodics while finding the
        % frequency. Therefore we use only the fundamental here.
        jobs{1}.spm.tools.drifter.refdata(1).Nimm     = 1;
        
        jobs{1}.spm.tools.drifter.refdata(2).name     = 'Respiratory Signal';
        if (strcmp(DirResp(1).name((length(DirResp(1).name)-3):length(DirResp(1).name)),'.mat'))
            jobs{1}.spm.tools.drifter.refdata(2).data     = resp.resp;
        else
            jobs{1}.spm.tools.drifter.refdata(2).data     = resp;
        end
        
        jobs{1}.spm.tools.drifter.refdata(2).dt       = 2/1000;
        jobs{1}.spm.tools.drifter.refdata(2).downdt   = 1/10;
        jobs{1}.spm.tools.drifter.refdata(2).freqlist = 10:70;
        jobs{1}.spm.tools.drifter.refdata(2).N        = 1;rp_20110407_152339NeuroCine2011yevhen3YH05s004a1001_001
        jobs{1}.spm.tools.drifter.refdata(2).Nimm     = 1;
        
        spm_jobman('run',jobs);
        
        mkdir([AutoDataProcessParameter.DataProcessDir,filesep,TargetDir,filesep,AutoDataProcessParameter.SubjectID{i}]);
        DirImg=dir([AutoDataProcessParameter.DataProcessDir,filesep,SourceDir,filesep,AutoDataProcessParameter.SubjectID{i},filesep,'n*.*']);
        for j=1:length(DirImg)
            movefile([AutoDataProcessParameter.DataProcessDir,filesep,SourceDir,filesep,AutoDataProcessParameter.SubjectID{i},filesep,DirImg(j).name], [AutoDataProcessParameter.DataProcessDir,filesep,TargetDir,filesep,AutoDataProcessParameter.SubjectID{i}]);
        end
    end
end

%Detrend%03/2013 *YH moved in front of ArtRepair to avoid problems with
%default setting and scanner drift (due to slow magnet drift, ArtRepair
%would "fix" volumes deviating from average - a lot in the beginning and a
%lot in the end
if (AutoDataProcessParameter.IsDetrend==1)
    fprintf('\n------------- Detrending -----------------\n\n')
    SourceDir = TargetDir;
    TargetDir = [TargetDir,'Detrended'];
    
    AllTargetDirs{end+1}=TargetDir;
    
    for SES = 1:AutoDataProcessParameter.Sessions
        
        cd([AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,SourceDir]);
        
        if use_parallel==1
            AutoDataProcessParameter.available_nworker = open_pool(AutoDataProcessParameter.requested_nworker);
            parfor i=1:AutoDataProcessParameter.SubjectNum
                fprintf('Subject %s, polynomial order %i\n',AutoDataProcessParameter.SubjectID{i},AutoDataProcessParameter.DetrendPolyOrder);
                rest_detrend([AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,SourceDir,filesep,AutoDataProcessParameter.SubjectID{i}], '_detrend',AutoDataProcessParameter.DetrendPolyOrder);
            end
        else
            for i=1:AutoDataProcessParameter.SubjectNum
                fprintf('Subject %s, polynomial order %i\n',AutoDataProcessParameter.SubjectID{i},AutoDataProcessParameter.DetrendPolyOrder);
                rest_detrend([AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,SourceDir,filesep,AutoDataProcessParameter.SubjectID{i}], '_detrend',AutoDataProcessParameter.DetrendPolyOrder);
            end
        end
        
        %Copy the detrended files
        cd([AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,SourceDir]);
        for i=1:AutoDataProcessParameter.SubjectNum
            cd([AutoDataProcessParameter.SubjectID{i}, '_detrend']);
            mkdir(['..',filesep,'..',filesep,TargetDir,filesep,AutoDataProcessParameter.SubjectID{i}])
            movefile('*',['..',filesep,'..',filesep,TargetDir,filesep,AutoDataProcessParameter.SubjectID{i}])
            cd('..');
            rmdir([AutoDataProcessParameter.SubjectID{i}, '_detrend']);
            fprintf(['Moving Detrended Files:',AutoDataProcessParameter.SubjectID{i},' OK\n']);
        end
        fprintf('\n');
    end
end

% Volume Artifact Removal 05/11 /EP
% Uses ArtRepair toolbox (http://spnl.stanford.edu/tools/ArtRepair/Docs/ArtRepairHBM2009.html)
if (AutoDataProcessParameter.VolumeArtifactRemoval==1)
    
    fprintf('\n------------- Artifact correction -----------------\n\n')
    SourceDir = TargetDir;
    TargetDir = [TargetDir,'Artrep'];
    
    AllTargetDirs{end+1}=TargetDir;
    
    for SES = 1:AutoDataProcessParameter.Sessions
        
        cd([AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,SourceDir]);
        for i=1:AutoDataProcessParameter.SubjectNum
            OutputDir=[AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,TargetDir,filesep,AutoDataProcessParameter.SubjectID{i}];
            mkdir(OutputDir);
            
            DirImg=give_filelist([AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,SourceDir,filesep,AutoDataProcessParameter.SubjectID{i},filesep,'*.img']);
            InputImages=[];
            for j=1:length(DirImg)
                InputImages = [InputImages; AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,SourceDir,filesep,AutoDataProcessParameter.SubjectID{i},filesep,DirImg(j).name];
            end
            
            DirImg=dir([AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,'RealignParameter',filesep,AutoDataProcessParameter.SubjectID{i},filesep,'rp*.txt']);
            MvParams=[AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,'RealignParameter',filesep,AutoDataProcessParameter.SubjectID{i},filesep,DirImg(1).name];
            
            % Run art_global (ArtRepair)
            art_global_fdpa(InputImages, MvParams, 4, 2, AutoDataProcessParameter.PercentThresh, AutoDataProcessParameter.ZThresh, AutoDataProcessParameter.MvmtThresh);
            
            DirImg=dir([AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,SourceDir,filesep,AutoDataProcessParameter.SubjectID{i},filesep,'v*.*']);
            for j=1:length(DirImg)
                movefile([AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,SourceDir,filesep,AutoDataProcessParameter.SubjectID{i},filesep,DirImg(j).name], OutputDir);
            end
            
            OutputDir=[AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,'ArtRepair_log',filesep,AutoDataProcessParameter.SubjectID{i}];
            mkdir(OutputDir);
            DirImg=dir([AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,SourceDir,filesep,AutoDataProcessParameter.SubjectID{i},filesep,'art*.*']);
            for j=1:length(DirImg)
                movefile([AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,SourceDir,filesep,AutoDataProcessParameter.SubjectID{i},filesep,DirImg(j).name], OutputDir);
            end
            DirImg=dir([AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,SourceDir,filesep,'art*.*']);
            movefile([AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,SourceDir,filesep,DirImg(1).name], OutputDir);
            
            fprintf(['Removing Volume Artifacts from Functional Images:',AutoDataProcessParameter.SubjectID{i},' OK\n']);
        end
        fprintf('\n');
    end
end

%Smooth
if (AutoDataProcessParameter.IsSmooth==1)
    
    fprintf('\n------------- Spatial smoothing -----------------\n\n')
    SourceDir = TargetDir;
    TargetDir = [TargetDir,'Smoothed'];
    
    AllTargetDirs{end+1}=TargetDir;
    
    if SPMversion == 8
        load([ProgramPath,filesep,'Jobmats',filesep,'Smooth.mat']);
    else
        load([ProgramPath,filesep,'Jobmats',filesep,'SmoothSPM12.mat']);
    end
    
    for SES = 1:AutoDataProcessParameter.Sessions
        cd([AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,SourceDir]);
        for i=1:AutoDataProcessParameter.SubjectNum
            cd(AutoDataProcessParameter.SubjectID{i});
            DirImg=give_filelist('*.img');
            if length(DirImg)~=AutoDataProcessParameter.TimePoints(i,SES)
                error('Number of images does not match timepoints!')
            end
            FileList=cell(length(DirImg),1);
            for j=1:length(DirImg)
                FileList(j)={[AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,SourceDir,filesep,AutoDataProcessParameter.SubjectID{i},filesep,DirImg(j).name,',1']};
            end
            if SPMversion == 8
                jobs{1,1}.spatial{1,1}.smooth.data=[jobs{1,1}.spatial{1,1}.smooth.data;FileList];
            else
                matlabbatch{i,1}.spm.spatial.smooth.data=FileList;
                matlabbatch{i,1}.spm.spatial.smooth.fwhm=AutoDataProcessParameter.Smooth.FWHM;
            end
            cd('..');
            fprintf(['Smooth Setup:',AutoDataProcessParameter.SubjectID{i},' OK\n']);
        end
        fprintf('\n');
        if SPMversion==8  %YAN Chao-Gan, 090925. SPM8 compatible.
            jobs{1,1}.spatial{1,1}.smooth.fwhm=AutoDataProcessParameter.Smooth.FWHM;
            jobs = spm_jobman('spm5tospm8',{jobs});
            run_batch(jobs{1},AutoDataProcessParameter.requested_nworker);
            clear jobs;
        elseif SPMversion==12
            run_batch(matlabbatch,AutoDataProcessParameter.requested_nworker);
            clear matlabbatch;
        else
            uiwait(msgbox('The current SPM version is not supported by fDPA. Please install SPM5 or SPM8 first.','Invalid SPM Version.'));
            return
        end
        
        %Copy the smoothed files
        cd([AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,SourceDir]);
        for i=1:AutoDataProcessParameter.SubjectNum
            cd(AutoDataProcessParameter.SubjectID{i});
            mkdir(['..',filesep,'..',filesep,TargetDir,filesep,AutoDataProcessParameter.SubjectID{i}])
            movefile('s*',['..',filesep,'..',filesep,TargetDir,filesep,AutoDataProcessParameter.SubjectID{i}])
            cd('..');
            fprintf(['Moving Smoothed Files:',AutoDataProcessParameter.SubjectID{i},' OK\n']);
        end
        fprintf('\n');
    end
end

%Filter
if (AutoDataProcessParameter.IsFilter==1 && AutoDataProcessParameter.IsNormalize>0)
    
    old_TargetDir = TargetDir;
    
    try
        
        fprintf('\n------------- Temporal filtering -----------------\n\n')
        SourceDir = TargetDir;
        TargetDir = [TargetDir,'Filtered'];
        
        for SES = 1:AutoDataProcessParameter.Sessions
            
            cd([AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,SourceDir]);
            
            for i=1:AutoDataProcessParameter.SubjectNum
                
                cd(AutoDataProcessParameter.SubjectID{i});
                
                DirImg=give_filelist('*.img');
                if ~isCorrectOrder(DirImg)
                    error('Wrong order!')
                end
                fprintf('Subject %s\n  Loading data...',AutoDataProcessParameter.SubjectID{i});
                for j=1:length(DirImg)
                    struc = load_nii([DirImg(j).name]);
                    if j==1
                        imgs = zeros([size(struc.img), length(DirImg)], 'single');% the FMRI data were single precision anyway..YH 2013/03/29
                    end
                    imgs(:,:,:,j) = struc.img;
                end
                fprintf(' done\n');
                cfg.filtertype = 'butter';% 
                cfg.filter_limits = [0,...
                    AutoDataProcessParameter.Filter.AHighPass_LowCutoff,...
                    AutoDataProcessParameter.Filter.ALowPass_HighCutoff,...
                    inf];
                cfg.TR = AutoDataProcessParameter.TR(i,SES);
                cfg.vol=imgs;
                imgs=single(fdpa_filter(cfg));
                
                mkdir(['..',filesep,'..',filesep,TargetDir,filesep,AutoDataProcessParameter.SubjectID{i}])
                
                fprintf('  Saving data...');
                for j=1:length(DirImg)
                    struc = load_nii([DirImg(j).name]);
                    struc.img=imgs(:,:,:,j);
                    s=[AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,TargetDir,filesep,AutoDataProcessParameter.SubjectID{i},filesep,DirImg(j).name];
                    save_nii(struc,s);
                    s = [s(1:end-4),'.mat'];
                    if exist(s,'file')==2
                        delete(s);
                    end
                end
                fprintf(' done\n');
                cd ..
                
            end
            fprintf('\n');
            
        end
        
    catch err
        
        warning('Failed to filter data!: %s',err.message);
        TargetDir = old_TargetDir;
        
    end
    
    fprintf('\n');
    
end

%Convert output to 4D .nii 09/2011 /EP
if (AutoDataProcessParameter.NiiConversion==1 && AutoDataProcessParameter.IsNormalize>0)
    
    old_TargetDir = TargetDir;
    
    try
        
        fprintf('\n------------- 4D NIFTI conversion -----------------\n\n')
        fprintf('Converting output to 4D NIFTI format.\n');
        
        % for SourceDir = AllTargetDirs
        
        SourceDir = TargetDir;
        TargetDir = [TargetDir,'Nii'];
        
        for SES = 1:AutoDataProcessParameter.Sessions
            
            for i=1:AutoDataProcessParameter.SubjectNum
                
                cd([AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,SourceDir,filesep,AutoDataProcessParameter.SubjectID{i}]);
                DirImg=give_filelist('*.img');
                
                if ~isCorrectOrder(DirImg)
                    error('Order of slices incorrect!');
                end
                
                fprintf('Subject %s\n  Loading data...',AutoDataProcessParameter.SubjectID{i});
                for j=1:length(DirImg)
                    struc = load_nii([DirImg(j).name]);
                    if j==1
                        ref = struc; % use first figure as a reference
                        imgs = zeros([size(struc.img), length(DirImg)], 'single');% the FMRI data were single precision anyway..YH 2013/03/29
                    end
                    imgs(:,:,:,j) = struc.img;
                end
                fprintf(' done\n');
                
                ref.hdr.dime.bitpix=16;
                ref.hdr.dime.datatype=16;
                ref.img = imgs;
                ref.hdr.dime.cal_max=1000;
                ref.hdr.dime.cal_min=0;
                siz = size(imgs);
                if length(siz)==4
                    ref.hdr.dime.dim(1)=4;
                    ref.hdr.dime.dim(5)=siz(4);
                end
                save_nii(ref,'4D.nii');

%                 nii = make_nii(imgs,AutoDataProcessParameter.Normalize.VoxSize);
%                 save_nii(nii,'4D.nii');

                clear nii;
                
                mkdir([AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,TargetDir,filesep,AutoDataProcessParameter.SubjectID{i}]);
                DirNii=dir([AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,SourceDir,filesep,AutoDataProcessParameter.SubjectID{i},filesep,'*.nii']);
                for k=1:length(DirNii)
                    movefile([AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,SourceDir,filesep,AutoDataProcessParameter.SubjectID{i},filesep,DirNii(k).name],...
                        [AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,TargetDir,filesep,AutoDataProcessParameter.SubjectID{i}]);
                end
                fprintf(['4D NIFTI conversion: ',AutoDataProcessParameter.SubjectID{i},' OK\n']);
                
            end
            fprintf('\n');
        end
                
    catch err
        
        warning('4D NIFTI conversion failed: %s',err.message);
        TargetDir = old_TargetDir;
        
    end
    
end

if (AutoDataProcessParameter.CreateGroupMask==1 && AutoDataProcessParameter.IsNormalize>0)
    
    try
        
        fprintf('\n------------- EPI group mask computation -----------------\n\n')
        fprintf('Computing group EPI mask: ')
        
        SourceDir = TargetDir;
        
        for SES = 1:AutoDataProcessParameter.Sessions
            
            for i=1:AutoDataProcessParameter.SubjectNum
                if (AutoDataProcessParameter.NiiConversion==1)
                    struc=load_nii([AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,SourceDir,filesep,AutoDataProcessParameter.SubjectID{i},filesep,'4D.nii']);
                    imgs=struc.img;
                else
                    DirImg=give_filelist('*.img');
                    if ~isCorrectOrder(DirImg)
                        error('Order of slices incorrect!');
                    end
                    for j=1:length(DirImg)
                        struc = load_nii([AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,SourceDir,filesep,AutoDataProcessParameter.SubjectID{i},filesep,DirImg(j).name]);
                        if j==1
                            imgs = zeros([size(struc.img), length(DirImg)], 'single');% the FMRI data were single precision anyway..YH 2013/03/29
                        end
                        imgs(:,:,:,j) = struc.img;
                    end
                end
                
                if i==1
                    s=size(imgs);
                    groupmask = ones(s(1:3));
                    T=s(4);
                end
                
                %T=size(imgs,4);
                for t=1:T
                    temp=squeeze(imgs(:,:,:,t));
                    groupmask=groupmask.*(temp>0.1*quantile(temp(:),.98));
                end
                fprintf('%i ',i);
            end
            
            fprintf('done\nGroup mask size %i voxels\n',nnz(groupmask));
            
            struc.hdr.dime.bitpix=16;
            struc.hdr.dime.datatype=16;
            struc.img = groupmask;
            struc.hdr.dime.cal_max=1;
            struc.hdr.dime.cal_min=0;
            struc.hdr.dime.dim(1)=3;
            
            save_nii(struc,[AutoDataProcessParameter.DataProcessDir,SESSION_PREFIX{SES},filesep,TargetDir,filesep,'group_EPI_mask.nii']);
            
            %save_nii(make_nii(groupmask,AutoDataProcessParameter.Normalize.VoxSize),[AutoDataProcessParameter.DataProcessDir,filesep,TargetDir,filesep,'group_EPI_mask.nii']);
            
        end
        
    catch err
        
        fprintf('\n');
        warning('Failed to compute group mask: %s',err.message);
        
    end
    
end


% close all figures created during pipeline, keep old ones
close_all_new_images(original_fig_handles);
drawnow;

cd(AutoDataProcessParameter.DataProcessDir);

fprintf('\n\n ALL DONE!! \n\n');

end

% function AllNii2Img(path)
%
% startpath = pwd;
% cd(path);
% DirImg=dir('*.nii');
% for i=1:length(DirImg)
%
%     nii=load_nii(DirImg(i).name);
%     [a,b,c]=fileparts(DirImg(i).name);
%     save_nii(nii,[b,'.img']);
%     delete(DirImg(i).name);
%
% end
% cd(startpath);
%
% end
function close_all_new_images(original_fig_handles)

new_fig_handles = findall(0,'Type','figure');
for i=1:length(new_fig_handles)
    is_old=false;
    for j=1:length(original_fig_handles)
        if new_fig_handles(i)==original_fig_handles(j)
            is_old=true;
            break;
        end
    end
    if ~is_old
        close(new_fig_handles(i));
    end
end

end

function res = isCorrectOrder(DirImg)

res=0;
numbers = zeros(1,length(DirImg));
for j=1:(length(DirImg)-1)
    [~,name1,~]=fileparts(DirImg(j).name);
    [~,name2,~]=fileparts(DirImg(j+1).name);
    name1 = extractnum(name1);
    numbers(j)=name1;
    name2 = extractnum(name2);
    if name2~=name1+1
        return;
    end
end
numbers(j+1)=name2;
res=1;

end

function num = extractnum(str)

new_str=[];
L=length(str);
for i=L:-1:1
    a=str2double(str(i));
    if ~isnan(a)
        new_str=[str(i),new_str];
    else
        break;
    end
end
num=str2double(new_str);
if isnan(num)
    num
    error('Failed to convert str to num (BUG)')
end

end

%New functions 05/11 /EP & YH
% function FileList = removeFiles (SourceList, prefix)
% % Removes files with certain prefix from the list. Returns new FileList.
% FileList=[];
% for j=1:length(SourceList)
%     if (~strncmp(SourceList(j).name,prefix,length(prefix)))
%         FileList=[FileList; SourceList(j)];
%     end
% end
% end

% function newjobs = loadSPM8job(fname)
% try
%     fid = fopen(fname,'rt');
%     str = fread(fid,'*char');
%     fclose(fid);
%     eval(str);
% catch
%     warning('spm:spm_jobman:LoadFailed','Load failed:''%s''',fname);
% end
% newjobs = {};
% if exist('matlabbatch','var')
%     newjobs = [newjobs(:),{matlabbatch}];
% end
% end
%03/2013 YH added the skullstripping to teh default segmentation to improve
%the coregistration
function segmentT1Image(T1ImageFile, type)% note , this  segmentation uses the defaults values for AMI     centre () GE, European Template)

[dirToGoTo,  notneeded1, notneeded2] = fileparts(T1ImageFile);% the skull tripped anatomical will be written to teh current directory so
%so we have to change to it before performing the job
startingDir = pwd;
cd (dirToGoTo);
[ProgramPath, notneeded1, notneeded2] = fileparts(which('fDPA_run.m'));
[SPMPath, notneeded1, notneeded2] = fileparts(which('spm.m'));
if strcmpi(type,'mni')
    segmentjobfile = {[ProgramPath,filesep,'Jobmats',filesep,'Segment2012MNI_skullstrip_job.m']};
else
    segmentjobfile = {[ProgramPath,filesep,'Jobmats',filesep,'Segment2012Eastern_skullstrip_job.m']};
end
segmentjobs = repmat(segmentjobfile, 1, 1);
inputs = cell(2, 1);
inputs{1,1} = {[T1ImageFile]}; % Segment: Data - cfg_files
inputs{2,1} = {[SPMPath,filesep,'tpm',filesep,'grey.nii'];[SPMPath,filesep,'tpm',filesep,'white.nii'];[SPMPath,filesep,'tpm',filesep,'csf.nii']};
% Segment: Tissue probability maps - cfg_files
spm('defaults', 'FMRI');
spm_jobman('initcfg');
spm_jobman('serial', segmentjobs, '', inputs{:});
clear segmentjobs % clears the variable segmentjobs
cd (startingDir);
end

function NewNormalizeWrite(fun_imgs_to_normalize,deformation_field_file,voxelsize,boundingbox,SPMversion)

[ProgramPath, notneeded1, notneeded2] = fileparts(which('fDPA_run.m'));
if SPMversion==8
    
    load([ProgramPath,filesep,'Jobmats',filesep,'NewNormalize_Write.mat']);
    matlabbatch{1,1}.spm.util.defs.comp{1}.def{1}=deformation_field_file;
    matlabbatch{1,1}.spm.util.defs.comp{2}.idbbvox.vox = voxelsize;
    matlabbatch{1,1}.spm.util.defs.comp{2}.idbbvox.bb = boundingbox;
    for i=1:length(fun_imgs_to_normalize)
        matlabbatch{1,1}.spm.util.defs.fnames{i,1}=[pwd,filesep,fun_imgs_to_normalize(i).name,',1'];
    end
    spm('defaults', 'FMRI');
    spm_jobman('initcfg');
    spm_jobman('run',matlabbatch);
else
    error('NON-STANDARD NORMALIZATION NOT YET IMPLEMENTED FOR SPM12!!')
end

end

function batch = NewNormalizeWriteMNI(fun_imgs_to_normalize,deformation_field_file,kumpi,SPMversion)

[ProgramPath, notneeded1, notneeded2] = fileparts(which('fDPA_run.m'));

if SPMversion==8
    SPMJOB = load([ProgramPath,filesep,'Jobmats',filesep,'NewNormalize_Write_MNI.mat']);
    SPMJOB.matlabbatch{1,1}.spm.util.defs.comp{1}.def{1}=deformation_field_file;
    if kumpi==1
        reffile = [ProgramPath,filesep,'Templates',filesep,'MNI152_T1_2mm_brain_mask.nii,1'];
    else
        reffile = [ProgramPath,filesep,'Templates',filesep,'MNI152_T1_1mm_brain_mask.nii,1'];
    end
    SPMJOB.matlabbatch{1}.spm.util.defs.comp{2}.id.space{1} = reffile;
    for i=1:length(fun_imgs_to_normalize)
        SPMJOB.matlabbatch{1,1}.spm.util.defs.fnames{1,i}=[pwd,filesep,fun_imgs_to_normalize(i).name,',1'];
    end
    %spm('defaults', 'FMRI');
    %spm_jobman('initcfg');
    %spm_jobman('run',);
    batch = SPMJOB.matlabbatch;
    
else
    load([ProgramPath,filesep,'Jobmats',filesep,'Normalize_Write_MNI_SPM12.mat']);
    matlabbatch{1,1}.spm.spatial.normalise.write.subj.def{1}=deformation_field_file;
    matlabbatch{1,1}.spm.spatial.normalise.write.woptions.bb = [-90 -126 -72;90 90 108];
    if kumpi==1
        matlabbatch{1,1}.spm.spatial.normalise.write.woptions.vox = [2,2,2];
    else
        matlabbatch{1,1}.spm.spatial.normalise.write.woptions.vox = [1,1,1];
    end
    for i=1:length(fun_imgs_to_normalize)
        matlabbatch{1,1}.spm.spatial.normalise.write.subj.resample{i,1}=[pwd,filesep,fun_imgs_to_normalize(i).name,',1'];
    end
    %     spm('defaults', 'FMRI');
    %     spm_jobman('initcfg');
    %     spm_jobman('run',matlabbatch);
    batch = matlabbatch;
end

end

function segmentT1Image_NEW(T1ImageFile, Cfg) %type, SPMver)

[ProgramPath, notneeded1, notneeded2] = fileparts(which('fDPA_run.m'));

type = Cfg.Normalize.AffineRegularisationInSegmentation;
SPMver = Cfg.SPMver;
isaggressive = Cfg.doAggressive;

if SPMver==8 % non-standard "new segment" tool
    
    run([ProgramPath,filesep,'Jobmats',filesep,'NewSegment_job.m']);
    %load([ProgramPath,filesep,'Jobmats',filesep,'NewSegment.mat']);
    [SPMPath, fileN, extn] = fileparts(which('spm.m'));
    for T1ImgSegmentDirectoryNameue=1:6
        matlabbatch{1,1}.spm.tools.preproc8.tissue(1,T1ImgSegmentDirectoryNameue).tpm{1,1}=[SPMPath,filesep,'toolbox',filesep,'Seg',filesep,'TPM.nii',',',num2str(T1ImgSegmentDirectoryNameue)];
    end
    if strcmpi(type,'mni')  %Added by YAN Chao-Gan 091110. Use different Affine Regularisation in Segmentation: East Asian brains (eastern) or European brains (mni).
        matlabbatch{1,1}.spm.tools.preproc8.warp.affreg='mni';
    else
        matlabbatch{1,1}.spm.tools.preproc8.warp.affreg='eastern';
    end
    
    SourceFile=T1ImageFile;
    
    matlabbatch{1,1}.spm.tools.preproc8.channel.vols={SourceFile};
    spm('defaults', 'FMRI');
    spm_jobman('initcfg');
    spm_jobman('run',matlabbatch);
    
    skullstrip(SourceFile(1:end-2),1,SPMver);
    
elseif SPMver==12 % Standard way
    
    if isaggressive==1
        run([ProgramPath,filesep,'Jobmats',filesep,'SegmentSPM12_aggressive_job.m']);
    else
        run([ProgramPath,filesep,'Jobmats',filesep,'SegmentSPM12_job.m']);
    end
    %load([ProgramPath,filesep,'Jobmats',filesep,'NewSegment.mat']);
    [SPMPath, fileN, extn] = fileparts(which('spm.m'));
    for T1ImgSegmentDirectoryNameue=1:6
        matlabbatch{1,1}.spm.spatial.preproc.tissue(1,T1ImgSegmentDirectoryNameue).tpm{1,1}=[SPMPath,filesep,'tpm',filesep,'TPM.nii',',',num2str(T1ImgSegmentDirectoryNameue)];
    end
    if strcmpi(type,'mni')  %Added by YAN Chao-Gan 091110. Use different Affine Regularisation in Segmentation: East Asian brains (eastern) or European brains (mni).
        matlabbatch{1,1}.spm.spatial.preproc.warp.affreg='mni';
    else
        matlabbatch{1,1}.spm.spatial.preproc.warp.affreg='eastern';
    end
    
    SourceFile=T1ImageFile;
    
    matlabbatch{1,1}.spm.spatial.preproc.channel.vols={SourceFile};
    spm('defaults', 'FMRI');
    spm_jobman('initcfg');
    spm_jobman('run',matlabbatch);
    
    skullstrip(SourceFile(1:end-2),1,SPMver);
    
else
    error('Unknown SPM version!!! (should be 1=SPM8 pr 2=SPM12)');
end

end

%03/2013 YH for already existing segmentations without skullstripped file
%added a separate skull stripping function, according to Ashburner
%suggestion https://www.jiscmail.ac.uk/cgi-bin/webadmin?A2=spm;8b458744.1011
function skullstrip(mT1ImageFile,isnii,SPMversion)

if nargin<2 || isnii==0
    ending = '.img';
else
    ending = '.nii';
end

[dirToGoTo,  notneeded1, notneeded2] = fileparts(mT1ImageFile);% the skull tripped anatomical will be written to teh current directory so
%so we have to change to it before performing the job
startingDir = pwd;
cd (dirToGoTo);
[ProgramPath, notneeded1, notneeded2] = fileparts(which('fDPA_run.m'));
if SPMversion==8
    stripJobfile = {[ProgramPath,filesep,'Jobmats',filesep,'skullstrip_job.m']};
elseif SPMversion==12
    stripJobfile = {[ProgramPath,filesep,'Jobmats',filesep,'skullstrip_job_SPM12.m']};
else
    error('SPM version must be 8 or 12!!');
end
stripjobs = repmat(stripJobfile, 1, 1);
cDir= dir(['c1*',ending]);
c1Img=cDir(1).name;
cDir= dir(['c2*',ending]);
c2Img=cDir(1).name;
cDir= dir(['c3*',ending]);
c3Img=cDir(1).name;
images =cell(4,1);
images{1} = mT1ImageFile;
images{2} = [dirToGoTo filesep c1Img];
images{3} = [dirToGoTo filesep c2Img];
images{4} = [dirToGoTo filesep c3Img];
inputs{1, 1} = images; % Image Calculator: Input Images - cfg_files
%spm('defaults', 'FMRI');
spm('defaults', 'FMRI');
spm_jobman('initcfg');
spm_jobman('serial', stripjobs, '', inputs{:});
cd (startingDir)
end


function n_out = open_pool(n_in)

n_out = 0;
try
    myCluster = gcp('nocreate');
    if ~isempty(myCluster) && myCluster.NumWorkers<n_in
        delete(gcp);
        myCluster=[];
    end
    if isempty(myCluster)
        myCluster = parcluster('local');
        myCluster.NumWorkers=n_in;
        parpool(myCluster);
    end
    n_out  = myCluster.NumWorkers;
catch err % old matlab?
    n = matlabpool('size');
    if n>0 && n<n_in
        matlabpool('close');
        n=0;
    end
    if n==0
        matlabpool('open','local',n_in);
    end
    n_out = matlabpool('size');
end

if n_out<1
    warning('Failed to open parallel pool (zero workers)!!');
end

end

function run_batch(matlabbatch,nworker)

if nworker>1
    open_pool(nworker);
    parfor i=1:length(matlabbatch)
        spm_jobman('initcfg');
        spm_jobman('run',matlabbatch(i));
    end
else
    spm_jobman('initcfg');
    spm_jobman('run',matlabbatch);
end

end


function [res,new_str] = give_filelist(str)

res = dir(str);

if isempty(res) 
    ind = strfind(str,'.img');
    if ~isempty(ind)
        ind = ind(end);
        str(ind:(ind+3))='.nii';
        res = dir(str);  
    end
end

new_str = str;

end
function create_preview_T1_pictures()

disp('Creating new T1 preview images');

home=pwd;

if ~exist('PicturesForChkNormalization','dir')
    error('PicturesForChkNormalization does not exist');
end
cd('PicturesForChkNormalization');
savepath = pwd;
cd ..

if ~exist('T1ImgSegment','dir')
    error('T1ImgSegment does not exist')
end
cd T1ImgSegment
fol = dir('*');
rem=[];
for i=1:length(fol)
    if ~(fol(i).isdir==1) || strcmp(fol(i).name,'.') || strcmp(fol(i).name,'..')
        rem(end+1)=i;
    end
    SubjectID{i}=fol(i).name;
end
fol(rem)=[];
SubjectID(rem)=[];

for i=1:length(fol)
    cd(fol(i).name);
    temppath=pwd;
    DirImg=dir('c1co*.img');
    if isempty(DirImg)
        DirImg=dir('c1co*.nii');
    end
    if isempty(DirImg)
        fprintf('No co1* image\n');
    else
        fDPA_Normalized_TempImage =fullfile(tempdir,['DPARSF_Normalized_TempImage','_previewtemp.img']);
        reslice_nii(DirImg(1).name,fDPA_Normalized_TempImage,[1,1,1],1,0,2);
        nii=load_nii(fDPA_Normalized_TempImage);
        cd(savepath);
        save_volume_slices(nii.img,...
            [SubjectID{i},'_grey_matter_co1.tiff'],...
            [SubjectID{i},' segmented grey matter (co1*.img)'])
        fprintf(['Generating the pictures for checking segmentation (GM): ',SubjectID{i},' OK\n']);
    end
    cd(temppath);
    DirImg=dir('skullstripped.img');
    if isempty(DirImg)
        DirImg=dir('skullstripped.nii');
    end
    fDPA_Normalized_TempImage =fullfile(tempdir,['DPARSF_Normalized_TempImage','_previewtemp.img']);
    reslice_nii(DirImg(1).name,fDPA_Normalized_TempImage,[1,1,1],1,0,2);
    nii=load_nii(fDPA_Normalized_TempImage);
    cd(savepath);
    save_volume_slices(nii.img,...
        [SubjectID{i},'_skullstripped.tiff'],...
        [SubjectID{i},' skullstripped'])
    fprintf(['Generating the pictures for checking skullstripping : ',SubjectID{i},' OK\n\n']);
    cd(temppath);
    cd ..
end
disp('All done!');
cd(home);

end
function FileList = reorient (SourceList, prefix)
% Removes files with certain prefix from the list. Returns new FileList.
    FileList=[];
    for j=1:length(SourceList)
        if (~strncmp(SourceList(j).name,prefix,length(prefix)))
            FileList=[FileList; SourceList(j)];
        end
    end
end
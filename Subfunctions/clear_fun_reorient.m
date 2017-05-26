function clear_fun_reorient(path)

if nargin==0
    
    % session root
    home = pwd;
    
    cd T1Img
    d = dir('*');
    for i=1:length(d)
        
        if d(i).isdir && ~strcmp(d(i).name,'.') && ~strcmp(d(i).name,'..')
            cd(d(i).name)
            
            clear alreadyAppliedToFun mat
            
            if exist('ReorientT1ImgMat.mat','file')
                load('ReorientT1ImgMat.mat');
                %fprintf('file %s\n',d(i).name);
                if ~exist('mat','var')                    
                    warning('Corrupted transformation file - no mat variable!')
                end
                
                alreadyAppliedToFun=0;
                
                save('ReorientT1ImgMat.mat','alreadyAppliedToFun','mat');
                
                fprintf('  Fixed file %s \n',[pwd,filesep,'ReorientT1ImgMat.mat'])
            end
            cd ..
            
        end
        
    end
    
    cd(home);
    
else
    if exist([path,filesep,'ReorientT1ImgMat.mat'],'file')
        load([path,filesep,'ReorientT1ImgMat.mat']);
        %fprintf('file %s\n',d(i).name);
        if ~exist('mat','var')
            warning('Corrupted transformation file - no mat variable!')
        end
        
        alreadyAppliedToFun=0;
        
        save([path,filesep,'ReorientT1ImgMat.mat'],'alreadyAppliedToFun','mat');
        
        fprintf('  Fixed file %s \n',[path,filesep,'ReorientT1ImgMat.mat'])
    end    
end

fprintf('Done!\n');

end


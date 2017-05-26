function save_volume_slices(mat,filename,tit)

DO_CUT_OFF = 1;

colormapp = gray(256);

N_graycolors=0;

N_colors = size(colormapp,1);

mat = double(mat);

mat_zeros = (mat == 0 | isnan(mat));
val = mat(:);
val(val==0 | isnan(val))=[];
if DO_CUT_OFF==1
    cut_off = prctile(val,99.9);
    val(val>cut_off) = cut_off;
    mat(mat>cut_off)=cut_off;
end
ma = max(val);
mi = min(val);

mat = mat - mi + 10*eps;
mat = ceil(N_colors*mat/(ma-mi)) + N_graycolors;
mat(mat_zeros)=0;

for i=1:size(mat,3)
 a=squeeze(mat(:,:,i));
 dist(i)=mean(a(:));
end

good_levels = find(dist>((max(dist)-min(dist))/2)/5000);

NSlices = 24;

Z_mat = round(linspace(good_levels(1),good_levels(end),NSlices));

rows = 4;%ceil(sqrt(NSlices));
cols = 6;%ceil(sqrt(NSlices));

set(0,'Units','centimeters');
s = get(0,'ScreenSize');

X = s(3)*3/4;                  % A3 paper size
Y = s(4)*3/4;                  % A3 paper size
% xMargin = 1;               % left/right margins from page borders
% yMargin = 1;               % bottom/top margins from page borders
% xSize = X - 2*xMargin;     % figure size on paper (widht & hieght)
% ySize = Y - 2*yMargin;     % figure size on paper (widht & hieght)

handle = figure('Units','centimeters', 'Position',[0 0 X Y],'Name',tit,'visible','off','Menubar','none'); % 'Position',[20,20,1150,900]
%set(handle, 'Renderer', 'painters'); 

set(gcf, 'PaperUnits','centimeters')
set(gcf, 'PaperSize',[X Y])
%set(gcf, 'PaperPosition',[xMargin yMargin xSize ySize])
%set(gcf, 'PaperOrientation','portrait')
set(handle, 'PaperPositionMode', 'auto');

annotation('textbox',[0.1 0.96 0.8 0.05],'string',tit,'Interpreter', 'none','FontSize',14,'Color',[1,0,0],'HorizontalAlignment','center','VerticalAlignment','middle','EdgeColor','none')

for i=1:NSlices
    
    tight_subplot(rows,cols,i);
    
    image2 = squeeze(mat(:,:,Z_mat(i)));
    
    imshow(image2,colormapp, 'InitialMagnification','fit');
    
    title(['z=',num2str(Z_mat(i)),'/',num2str(size(mat,3))],'FontSize',8,'Color',[0,1,0]);%' (',num2str(aa),')']);
    set(gca,'YTick',[]);
    set(gca,'XTick',[]);
    box on;
end
%print(handle,'-dtiff','-r100',filename);
set(handle,'visible','on'); % since r2014b saving invisible windows is broken
export_fig(filename,handle);
set(handle,'visible','off'); % since r2014b saving invisible windows is broken
%saveas(handle,[filename,'.fig']);
close(handle);

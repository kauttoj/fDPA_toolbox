function handle = show_volume_slices(mat_base,mat,tit,id)

DO_CUT_OFF = 1;

colormapp = winter(256);
colormapp_gray = gray(256);

N_graycolors=size(colormapp_gray,1);
N_colors = size(colormapp,1);

mat_base = double(mat_base);
mat_zeros = (mat_base == 0 | isnan(mat_base));
val = mat_base(:);
if DO_CUT_OFF==1
    cut_off = prctile(val,99.9);
    val(val>cut_off) = cut_off;
    mat_base(mat_base>cut_off)=cut_off;
end
val(val==0 | isnan(val))=[];
ma = max(val);
mi = min(val);
mat_base = mat_base - mi + 10*eps;
mat_base = ceil(N_graycolors*mat_base/(ma-mi));
mat_base(mat_zeros)=0;

mat = double(mat);
mat_zeros = (mat == 0 | isnan(mat));
val = mat(:);
if DO_CUT_OFF==1
    cut_off = prctile(val,99.9);
    val(val>cut_off) = cut_off;
    mat(mat>cut_off)=cut_off;
end
val(val==0 | isnan(val))=[];
ma = max(val);
mi = min(val);
mat = mat - mi + 10*eps;
mat = ceil(N_colors*mat/(ma-mi)) + N_graycolors;
mat(mat_zeros)=0;

colormap = [colormapp_gray;colormapp];

z_min = 5/91;
z_max = 90/91;
NSlices = 24;

Z_mat = round(linspace(z_min,z_max,NSlices)*size(mat,3));

rows = 4;%ceil(sqrt(NSlices));
cols = 6;%ceil(sqrt(NSlices));

set(0,'Units','centimeters');
s = get(0,'ScreenSize');

X = s(3)*5/8;                  %# A3 paper size
Y = s(4)*3/4;                  %# A3 paper size
xMargin = s(3)*(3/(8*10))*id;               %# left/right margins from page borders
yMargin = s(4)*(1/(8*10))*id;              %# bottom/top margins from page borders
% xSize = X - 2*xMargin;     %# figure size on paper (widht & hieght)
% ySize = Y - 2*yMargin;     %# figure size on paper (widht & hieght)

handle = figure('Units','centimeters', 'Position',[xMargin yMargin X Y],'Name',tit,'visible','on','Menubar','none'); % 'Position',[20,20,1150,900]

% set(gcf, 'PaperUnits','centimeters')
% set(gcf, 'PaperSize',[X Y])
% %set(gcf, 'PaperPosition',[xMargin yMargin xSize ySize])
% set(gcf, 'PaperOrientation','portrait')
% set(handle, 'PaperPositionMode', 'auto');

annotation('textbox',[0.1 0.96 0.8 0.05],'string',tit,'FontSize',16,'Color',[0,0,1],'HorizontalAlignment','center','VerticalAlignment','middle','EdgeColor','none')

for i=1:NSlices
    
    tight_subplot(rows,cols,i);
    
    image = squeeze(mat_base(:,:,Z_mat(i)));
    image_overlay = squeeze(mat(:,:,Z_mat(i)));
    image(image_overlay>0)=image_overlay(image_overlay>0);
    
    imshow(image,colormap, 'InitialMagnification','fit');
    
    title(['z=',num2str(Z_mat(i)),'/',num2str(size(mat,3))],'FontSize',10,'Color',[1,0,0]);%' (',num2str(aa),')']);
    set(gca,'YTick',[]);
    set(gca,'XTick',[]);
    box on;
    
end

%print(handle,'-dtiff','-r300',filename);
%close(handle);

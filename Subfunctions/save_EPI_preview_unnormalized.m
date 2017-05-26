function save_EPI_preview_unnormalized(mat_base,mat,tit,filename)

DO_CUT_OFF = 1;

colormapp = flipud(autumn(256));
colormapp_gray = gray(256);

N_graycolors=size(colormapp_gray,1);
N_colors = size(colormapp,1);

mat_base = double(mat_base);
mat_zeros = (mat_base == 0 | isnan(mat_base));
val = mat_base(:);
if DO_CUT_OFF==1
    cut_off = prctile(val,99);
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
val = mat(:);

low_cut = 0.1*quantile(val,.98);
val(val<low_cut)=0;
mat(mat<low_cut)=0;
mat_zeros = (mat == 0 | isnan(mat));

val(val==0 | isnan(val))=[];
high_cut = prctile(val,99);
val(val>high_cut) = high_cut;
mat(mat>high_cut)=high_cut;

ma = max(val);
mi = min(val);
mat = mat - mi + 10*eps;
mat = ceil(N_colors*mat/(ma-mi)) + N_graycolors;
mat(mat_zeros)=0;

colormap = [colormapp_gray;colormapp];


clear dist;
for i=1:size(mat,3)
 a=squeeze(mat(:,:,i));
 dist(i)=mean(a(:));
end
good_levels = find(dist>((max(dist)-min(dist))/2)/5000);
z_min = good_levels(1)/size(mat,3);
z_max = good_levels(end)/size(mat,3);

clear dist;
for i=1:size(mat,1)
 a=squeeze(mat(i,:,:));
 dist(i)=mean(a(:));
end
good_levels = find(dist>((max(dist)-min(dist))/2)/5000);
x_min = good_levels(1)/size(mat,1);
x_max = good_levels(end)/size(mat,1);

clear dist;
for i=1:size(mat,2)
 a=squeeze(mat(:,i,:));
 dist(i)=mean(a(:));
end
good_levels = find(dist>((max(dist)-min(dist))/2)/5000);
y_min = good_levels(1)/size(mat,2);
y_max = good_levels(end)/size(mat,2);

rows = 3;%ceil(sqrt(NSlices));
cols = 6;%ceil(sqrt(NSlices));

NSlices = cols;

Z_mat = round(linspace(z_min,z_max,NSlices)*size(mat,3));
X_mat = round(linspace(x_min,x_max,NSlices)*size(mat,1));
Y_mat = round(linspace(y_min,y_max,NSlices)*size(mat,2));

set(0,'Units','centimeters');
s = get(0,'ScreenSize');

X = s(3)*3/4;                  %# A3 paper size
Y = s(4)*3/4;                  %# A3 paper size
% xMargin = 1;               %# left/right margins from page borders
% yMargin = 1;               %# bottom/top margins from page borders
% xSize = X - 2*xMargin;     %# figure size on paper (widht & hieght)
% ySize = Y - 2*yMargin;     %# figure size on paper (widht & hieght)

handle = figure('Units','centimeters', 'Position',[0 0 X Y],'Name',tit,'visible','off','Menubar','none'); % 'Position',[20,20,1150,900]
set(gcf, 'PaperUnits','centimeters')
set(gcf, 'PaperSize',[X Y])
set(gcf, 'PaperOrientation','portrait')
set(handle, 'PaperPositionMode', 'auto');

annotation('textbox',[0.1 0.95 0.8 0.05],'string',tit,'Interpreter', 'none','FontSize',16,'Color',[0,0,1],'HorizontalAlignment','center','VerticalAlignment','middle','EdgeColor','none')

for i=1:NSlices
        
    tight_subplot(rows,cols,1,i);
    
    image = squeeze(mat_base(:,:,Z_mat(i)));
    imshow(image,colormap, 'InitialMagnification','fit');hold on;
    image_overlay = squeeze(mat(:,:,Z_mat(i)));
    h = imshow(image_overlay,colormap, 'InitialMagnification','fit');
    %image(image_overlay>0)=image_overlay(image_overlay>0);    
    %alpha = 0.5*size(image_overlay);    
    set(h, 'AlphaData', 0.4);
    
    %imshow(image,colormap, 'InitialMagnification','fit');
    
    title(['z=',num2str(Z_mat(i)),'/',num2str(size(mat,3))],'FontSize',10,'Color',[1,0,0]);%' (',num2str(aa),')']);
    set(gca,'YTick',[]);
    set(gca,'XTick',[]);
    box on;
    
end

for i=1:NSlices
        
    tight_subplot(rows,cols,2,i);
    
    image = squeeze(mat_base(:,Y_mat(i),:));
    imshow(flipud(image'),colormap, 'InitialMagnification','fit');hold on;
    image_overlay = squeeze(mat(:,Y_mat(i),:));
    h = imshow(flipud(image_overlay'),colormap, 'InitialMagnification','fit');
    %image(image_overlay>0)=image_overlay(image_overlay>0);    
    %alpha = 0.5*size(image_overlay);    
    set(h, 'AlphaData', 0.5);
    
    title(['y=',num2str(Y_mat(i)),'/',num2str(size(mat,2))],'FontSize',10,'Color',[1,0,0]);%' (',num2str(aa),')']);
    set(gca,'YTick',[]);
    set(gca,'XTick',[]);
    box on;
    
end

for i=1:NSlices
        
    tight_subplot(rows,cols,3,i);
    
    image = squeeze(mat_base(X_mat(i),:,:));
    imshow(flipud(image'),colormap, 'InitialMagnification','fit');hold on;
    image_overlay = squeeze(mat(X_mat(i),:,:));
    h = imshow(flipud(image_overlay'),colormap, 'InitialMagnification','fit');
    %image(image_overlay>0)=image_overlay(image_overlay>0);    
    %alpha = 0.5*size(image_overlay);    
    set(h, 'AlphaData', 0.5);
    
    title(['x=',num2str(X_mat(i)),'/',num2str(size(mat,1))],'FontSize',10,'Color',[1,0,0]);%' (',num2str(aa),')']);
    set(gca,'YTick',[]);
    set(gca,'XTick',[]);
    box on;
    
end
set(handle,'visible','on'); % since r2014b saving invisible windows is broken
export_fig(filename,handle);
set(handle,'visible','off'); % since r2014b saving invisible windows is broken
%print(handle,'-dtiff','-r100',filename);
close(handle);



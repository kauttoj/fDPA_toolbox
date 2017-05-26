function h = tight_subplot(rows,cols,j,i)

if nargin<3
    error('not enough inputs')
elseif nargin<4
    row = (rows - 1) - fix((j - 1) / cols) + 1;
    col = rem(j - 1, cols) + 1;
else
    row = j;
    col = i;
end

x_rako=0.001;
y_rako=0.006;

x_reuna=0.004;
y_reuna_up=0.010;
y_reuna_down=0.003;

h = subplot('position',...
    [x_reuna + ((1-2*x_reuna)/cols)*(col-1) + (cols-1)*x_rako/2,...
    y_reuna_down + ((1-y_reuna_up-y_reuna_down)/rows)*(row-1) + (rows-1)*y_rako/2,...
    ((1-2*x_reuna)/cols)-(cols-1)*x_rako,...
    ((1-y_reuna_up-y_reuna_down)/rows)-(rows-1)*y_rako]);
set(h,'YTickLabel','','XTick',[],'XTickLabel','','YTick',[]);
box on;
 
end


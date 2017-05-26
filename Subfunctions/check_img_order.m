function check_img_order(DirImg)
%CHECK_IMG_ORDER Summary of this function goes here
%   Detailed explanation goes here

if nargin<1
    DirImg=dir('*.img');
    res = isCorrectOrder(DirImg);
else
    res = isCorrectOrder(DirImg);
end

if res==1
    fprintf('\n Order is correct :)\n')
else
    fprintf('\n CHECK FAILED - INCORRECT ORDER FOUND !!!!)\n')
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
function data = load_img_data(max_num)
%LOAD_IMG_DATA Summary of this function goes here
%   Detailed explanation goes here

DirImg=dir('*.img');
if ~isCorrectOrder(DirImg)
    error('Wrong order!')
end

N = length(DirImg);
if nargin>0
    N = min(max_num,N);
end

for j=1:N
    struct = load_nii(DirImg(j).name);
    if j==1
        imgs = zeros([size(struct.img), N], 'single');% the FMRI data were single precision anyway..YH 2013/03/29
    end
    imgs(:,:,:,j) = struct.img;
end

data = imgs;

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
iszero=[];
for i=L:-1:1
    a=str2double(str(i));
    if ~isnan(a)
        new_str=[str(i),new_str];        
        if a==0
            iszero=[1,iszero]; 
        else
            iszero=[0,iszero];
        end
    else
        break;
    end
end
rem=false(1,length(iszero));
for i=1:length(iszero)
    if iszero(i)==1
       rem(i)=true;
    else
       break; 
    end
end
new_str(rem)=[];

num=str2double(new_str);

if isnan(num)
    new_str
    error('Failed to convert str to num (BUG)')
end

end
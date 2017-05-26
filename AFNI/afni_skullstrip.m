function afni_skullstrip(input_file,input_opts)

% wrapper function for AFNI skullstrip routine to used with fDPA
% Janne K. 15.1.2014

% http://afni.nimh.nih.gov/pub/dist/doc/program_help/3dSkullStrip.html
%   o 3dSkullStrip -input VOL -prefix VOL_PREFIX -push_to_edge
%      Adds an agressive push to brain edges. Use this option
%      when the chunks of gray matter are not included. This option
%      might cause the mask to leak into non-brain areas.
%   o 3dSkullStrip -input VOL -prefix VOL_PREFIX -ld 30
%      Use a denser mesh, in the cases where you have lots of 
%      csf between gyri. Also helps when some of the brain is clipped
%      close to regions of high curvature.
%  Clipping in frontal areas, close to the eye balls:
%         + Try -push_to_edge option first.
%           Can also try -no_avoid_eyes option.
%      Clipping in general:
%         + Try -push_to_edge option first.
%           Can also use lower -shrink_fac, start with 0.5 then 0.4
%      Problems down below:
%         + Piece of cerbellum missing, reduce -shrink_fac_bot_lim 
%           from default value.
%         + Leakage in lower areas, increase -shrink_fac_bot_lim 
%           from default value.
%      Some lobules are not included:
%         + Use a denser mesh. Start with -ld 30. If that still fails,
%         try even higher density (like -ld 50) and increase iterations 
%         (say to -niter 750). 
%         Expect the program to take much longer in that case.
%         + Instead of using denser meshes, you could try blurring the data 
%         before skull stripping. Something like -blur_fwhm 2 did
%         wonders for some of my data with the default options of 3dSkullStrip
%         Blurring is a lot faster than increasing mesh density.
%         + Use also a smaller -shrink_fac is you have lots of CSF between
%         gyri.
%      Massive chunks missing:
%         + If brain has very large ventricles and lots of CSF between gyri,
%         the ventricles will keep attracting the surface inwards. 
%         This often happens with older brains. In such 
%         cases, use the -visual option to see what is happening.
%         For example, the options below did the trick in various
%         instances. 
%             -blur_fwhm 2 -use_skull  
%         or for more stubborn cases increase csf avoidance with this cocktail
%             -blur_fwhm 2 -use_skull -avoid_vent -avoid_vent -init_radius 75 
%         + Too much neck in the volume might throw off the initialization
%           step. You can fix this by clipping tissue below the brain with 
%                  @clip_volume -below ZZZ -input INPUT  
%           where ZZZ is a Z coordinate somewhere below the brain.
% 
%      Large regions outside brain included:
%        + Usually because noise level is high. Try @NoisySkullStrip.

default_opts.use_noisy = 0; % if LOTS of skull etc.
default_opts.push_to_edge = 'push_to_edge'; % use 'push_to_edge' if missing grey matter (otherwise 'no_push_to_edge')
default_opts.niter = 350; % 750 for LD50 (default=250)
default_opts.ld = 38; % go to 50 if some brain is missing (default=30)
default_opts.shrink_fac = 0.30; % decrease to 0.4-0.5 if some grey matter missing or lots of CSF (default = 0.6)
default_opts.shrink_fac_bot_lim = 0.45; % lower brain: reduce if cerbellum is missing, increase if too much (default = 0.4)
%default_opts.blur_fwhm=2; % otherwise blur_fwhm 2 (default=0)
%default_opts.use_skull = 'no_use_skull'; % 'use_skull' if lots of brain missing
%default_opts.norm_vol = 'norm_vol'; % use '-orig_vol' with no intensity changes
default_opts.prefix = 'afni_skullstripped_';
%default_opts.avoid_vent = 'avoid_vent';

default_opts_postprocess.use_noisy = 0;
%default_opts_postprocess.push_to_edge = 'push_to_edge'; % use 'push_to_edge' if missing grey matter (otherwise 'no_push_to_edge')
default_opts_postprocess.niter = 400; % 750 for LD50 (default=250)
default_opts_postprocess.ld = 40; % go to 50 if some brain is missing (default=30)
default_opts_postprocess.shrink_fac = 0.04; % decrease to 0.4-0.5 if some grey matter missing or lots of CSF (default = 0.6)
default_opts_postprocess.shrink_fac_bot_lim = 0.40; % lower brain: reduce if cerbellum is missing, increase if too much (default = 0.4)
%afni_opts.no_var_shrink_fac = 'no_var_shrink_fac';
default_opts_postprocess.avoid_vent='avoid_vent -avoid_vent';
%afni_opts.perc_int=0.0;
%default_opts_postprocess.touchup = 'touchup -touchup';
default_opts_postprocess.no_use_edge='no_use_edge';
default_opts_postprocess.prefix = 'afni_skullstripped_';

fprintf('---- AFNI SkullStrip for file ''%s'' ----\n',input_file);

if nargin>1
    
    if input_opts.doPostprocessing==1
        opts = default_opts_postprocess; 
    else
        opts = default_opts; 
    end
        
   
    %fprintf('..parsing options struct\n');
    orig_fnames = fieldnames(default_opts);
    input_fnames = fieldnames(input_opts);
    for i=1:length(input_fnames)
        found=0;
        for j=1:length(orig_fnames)
            if strcmp(input_fnames{i},orig_fnames{j})
                opts.(input_fnames{i})=input_opts.(input_fnames{i});
                found=1;
                break;
            end
        end
        if found==0
            opts.(input_fnames{i})=input_opts.(input_fnames{i});
        end
    end   
    
else
   opts = default_opts; 
end

opts_str = [];
fnames = fieldnames(opts);
for i=1:length(fnames)
    if strcmp(fnames{i},'use_noisy')
        use_noisy = opts.use_noisy;
    elseif strcmp(fnames{i},'prefix')
        prefix = opts.prefix;
    elseif strcmp(fnames{i},'doPostprocessing')
        
    else
        if isnumeric(opts.(fnames{i}))
            opts_str = [opts_str,' -',fnames{i},' ',num2str(opts.(fnames{i}))];
        else
            opts_str = [opts_str,' -',opts.(fnames{i})];
        end
    end
end

if length(input_file)>4 && strcmp(input_file(end-4),'.')
    file_id = input_file(end-3:end);
    input_file = input_file(1:end-4);
else    
    if exist([input_file,'.img']) && exist([input_file,'.hdr'])
        file_id = '.hdr';
    elseif exist([input_file,'.nii']) 
        file_id = '.nii';
    else
       error('Proper input file not found (img/hdr or nii)!!!') 
    end
end  

output_file = [prefix,input_file];
tic
if use_noisy == 1
    
    str = ['./NoisySkullStrip',opts_str,' -input ',input_file,file_id,' -prefix ',output_file];
    disp(['Command: ',str]);
    fprintf('..running NoisySkullStrip...');        
    unix(['chmod +x NoisySkullStrip']);
    [status,cmdout] = unix(str);    
    if status~=0
        fprintf('failed!');
        disp(cmdout)
        error('AFNI NoisySkullStrip failed')
    end
    
else
    
    str = ['./3dSkullStrip',opts_str,' -input ',input_file,file_id,' -prefix ',output_file];
    disp(['Command: ',str]);
    fprintf('..running 3dSkullStrip...');
    
	%/scratch/braindata/shared/toolboxes/AFNI_linux_xorg7_64    
    unix(['chmod +x 3dSkullStrip']);
    [status,cmdout] = unix(str);
    if status~=0
        fprintf('failed!');
        disp(cmdout)
        error('AFNI 3dSkullStrip failed')        
    end
    
end

a=toc;
fprintf('success! (duration %s)\n',sec2min(a));

data_id = '+orig';
if exist([output_file,'+tlrc.BRIK'],'file')
    warning('BRIK has ''+tlrc'' instead of ''+orig''');
    data_id = '+tlrc';
    
%     [status,cmdout]=unix(['./3dWarp -deoblique -prefix ',output_file,'_temp ',output_file,'+tlrc']);         
%     if status~=0
%         fprintf('warping failed!');
%         disp(cmdout)
%         error('AFNI 3dWarp failed')
%     end
%     movefile([output_file,'_temp+tlrc.BRIK'],[output_file,'+orig.BRIK'])    
%     movefile([output_file,'_temp+tlrc.HEAD'],[output_file,'+orig.HEAD'])
%     delete([output_file,'+tlrc.BRIK'])
%     delete([output_file,'+tlrc.HEAD']) 
end   

fprintf('..running 3dAFNItoNIFTI...');
unix(['chmod +x 3dAFNItoNIFTI']);
str = ['./3dAFNItoNIFTI -prefix ',output_file,' ',output_file,data_id];
[status,cmdout] = unix(str);
if status==0
    fprintf('success!\n');
else
    fprintf(' failed!');
    disp(cmdout)
    error('AFNI 3dAFNItoNIFTI failed')
end   

fprintf('..deleting HEAD+BRIK files\n')
delete([output_file,data_id,'.HEAD']);
delete([output_file,data_id,'.BRIK']);

end


function res = sec2min(sec)

sec = round(sec);

for i=1:length(sec)
    min = floor(sec(i)/60);
    a = round(sec(i) - 60*min);    
    if a<10
        a=sprintf('%1.0f',a);
        a=['0',a];
    else
        a=sprintf('%2.0f',a);
    end    
    if i==1
        str = [num2str(min),':',a];
    else
        str = [str,', ',[num2str(min),':',a]];
    end
end

res = str;

end




% 
% 
% Usage: A program to extract the brain from surrounding.
%   tissue from MRI T1-weighted images. 
%   The simplest command would be:
%         3dSkullStrip <-input DSET>
% 
%   The fully automated process consists of three steps:
%   1- Preprocessing of volume to remove gross spatial image 
%   non-uniformity artifacts and reposition the brain in
%   a reasonable manner for convenience.
%   2- Expand a spherical surface iteratively until it envelopes
%   the brain. This is a modified version of the BET algorithm:
%      Fast robust automated brain extraction, 
%       by Stephen M. Smith, HBM 2002 v 17:3 pp 143-155
%     Modifications include the use of:
%      . outer brain surface
%      . expansion driven by data inside and outside the surface
%      . avoidance of eyes and ventricles
%      . a set of operations to avoid the clipping of certain brain
%        areas and reduce leakage into the skull in heavily shaded
%        data
%      . two additional processing stages to ensure convergence and
%        reduction of clipped areas.
%      . use of 3d edge detection, see Deriche and Monga references
%        in 3dedge3 -help.
%   3- The creation of various masks and surfaces modeling brain
%      and portions of the skull
% 
%   Common examples of usage:
%   -------------------------
%   o 3dSkullStrip -input VOL -prefix VOL_PREFIX
%      Vanilla mode, should work for most datasets.
%   o 3dSkullStrip -input VOL -prefix VOL_PREFIX -push_to_edge
%      Adds an agressive push to brain edges. Use this option
%      when the chunks of gray matter are not included. This option
%      might cause the mask to leak into non-brain areas.
%   o 3dSkullStrip -input VOL -surface_coil -prefix VOL_PREFIX -monkey
%      Vanilla mode, for use with monkey data.
%   o 3dSkullStrip -input VOL -prefix VOL_PREFIX -ld 30
%      Use a denser mesh, in the cases where you have lots of 
%      csf between gyri. Also helps when some of the brain is clipped
%      close to regions of high curvature.
% 
%   Tips:
%   -----
%      I ran the program with the default parameters on 200+ datasets.
%      The results were quite good in all but a couple of instances, here
%      are some tips on fixing trouble spots:
% 
%      Clipping in frontal areas, close to the eye balls:
%         + Try -push_to_edge option first.
%           Can also try -no_avoid_eyes option.
%      Clipping in general:
%         + Try -push_to_edge option first.
%           Can also use lower -shrink_fac, start with 0.5 then 0.4
%      Problems down below:
%         + Piece of cerbellum missing, reduce -shrink_fac_bot_lim 
%           from default value.
%         + Leakage in lower areas, increase -shrink_fac_bot_lim 
%           from default value.
%      Some lobules are not included:
%         + Use a denser mesh. Start with -ld 30. If that still fails,
%         try even higher density (like -ld 50) and increase iterations 
%         (say to -niter 750). 
%         Expect the program to take much longer in that case.
%         + Instead of using denser meshes, you could try blurring the data 
%         before skull stripping. Something like -blur_fwhm 2 did
%         wonders for some of my data with the default options of 3dSkullStrip
%         Blurring is a lot faster than increasing mesh density.
%         + Use also a smaller -shrink_fac is you have lots of CSF between
%         gyri.
%      Massive chunks missing:
%         + If brain has very large ventricles and lots of CSF between gyri,
%         the ventricles will keep attracting the surface inwards. 
%         This often happens with older brains. In such 
%         cases, use the -visual option to see what is happening.
%         For example, the options below did the trick in various
%         instances. 
%             -blur_fwhm 2 -use_skull  
%         or for more stubborn cases increase csf avoidance with this cocktail
%             -blur_fwhm 2 -use_skull -avoid_vent -avoid_vent -init_radius 75 
%         + Too much neck in the volume might throw off the initialization
%           step. You can fix this by clipping tissue below the brain with 
%                  @clip_volume -below ZZZ -input INPUT  
%           where ZZZ is a Z coordinate somewhere below the brain.
% 
%      Large regions outside brain included:
%        + Usually because noise level is high. Try @NoisySkullStrip.
% 
%   Make sure that brain orientation is correct. This means the image in 
%   AFNI's axial slice viewer should be close to the brain's axial plane.
%   The same goes for the other planes. Otherwise, the program might do a lousy
%   job removing the skull.
% 
%   Eye Candy Mode: 
%   ---------------
%   You can run BrainWarp and have it send successive iterations
%  to SUMA and AFNI. This is very helpful in following the
%  progression of the algorithm and determining the source
%  of trouble, if any.
%   Example:
%      afni -niml -yesplugouts &
%      suma -niml &
%      3dSkullStrip -input Anat+orig -o_ply anat_brain -visual
% 
%   Help section for the intrepid:
%   ------------------------------
%   3dSkullStrip  < -input VOL >
%              [< -o_TYPE PREFIX >] [< -prefix VOL_PREFIX >] 
%              [< -spatnorm >] [< -no_spatnorm >] [< -write_spatnorm >]
%              [< -niter N_ITER >] [< -ld LD >] 
%              [< -shrink_fac SF >] [< -var_shrink_fac >] 
%              [< -no_var_shrink_fac >] [< -shrink_fac_bot_lim SFBL >]
%              [< -pushout >] [< -no_pushout >] [< -exp_frac FRAC]
%              [< -touchup >] [< -no_touchup >]
%              [< -fill_hole R >] [< -NN_smooth NN_SM >]
%              [< -smooth_final SM >] [< -avoid_vent >] [< -no_avoid_vent >]
%              [< -use_skull >] [< -no_use_skull >] 
%              [< -avoid_eyes >] [< -no_avoid_eyes >] 
%              [< -use_edge >] [< -no_use_edge >] 
%              [< -push_to_edge >] [<-no_push_to_edge>]
%              [< -perc_int PERC_INT >] 
%              [< -max_inter_iter MII >] [-mask_vol | -orig_vol | -norm_vol]
%              [< -debug DBG >] [< -node_debug NODE_DBG >]
%              [< -demo_pause >]
%              [< -monkey >] [< -marmoset >] [<-rat>]
% 
%   NOTE: Please report bugs and strange failures
%         to saadz@mail.nih.gov
% 
%   Mandatory parameters:
%      -input VOL: Input AFNI (or AFNI readable) volume.
%                  
% 
%   Optional Parameters:
%      -monkey: the brain of a monkey.
%      -marmoset: the brain of a marmoset. 
%                 this one was tested on one dataset
%                 and may not work with non default
%                 options. Check your results!
%      -rat: the brain of a rat.
%            By default, no_touchup is used with the rat.
%      -surface_coil: Data acquired with a surface coil.
%      -o_TYPE PREFIX: prefix of output surface.
%         where TYPE specifies the format of the surface
%         and PREFIX is, well, the prefix.
%         TYPE is one of: fs, 1d (or vec), sf, ply.
%         More on that below.
%      -skulls: Output surface models of the skull.
%      -4Tom:   The output surfaces are named based
%              on PREFIX following -o_TYPE option below.
%      -prefix VOL_PREFIX: prefix of output volume.
%         If not specified, the prefix is the same
%         as the one used with -o_TYPE.
%         The output volume is skull stripped version
%         of the input volume. In the earlier version
%         of the program, a mask volume was written out.
%         You can still get that mask volume instead of the
%         skull-stripped volume with the option -mask_vol . 
%         NOTE: In the default setting, the output volume does not 
%               have values identical to those in the input. 
%               In particular, the range might be larger 
%               and some low-intensity values are set to 0.
%               If you insist on having the same range of values as in
%               the input, then either use option -orig_vol, or run:
%          3dcalc -nscale -a VOL+VIEW -b VOL_PREFIX+VIEW \
%                 -expr 'a*step(b)' -prefix VOL_SAME_RANGE
%               With the command above, you can preserve the range
%               of values of the input but some low-intensity voxels would
%               still be masked. If you want to preserve them, then use
%               -mask_vol in the 3dSkullStrip command that would produce 
%               VOL_MASK_PREFIX+VIEW. Then run 3dcalc masking with voxels
%               inside the brain surface envelope:
%          3dcalc -nscale -a VOL+VIEW -b VOL_MASK_PREFIX+VIEW \
%                 -expr 'a*step(b-3.01)' -prefix VOL_SAME_RANGE_KEEP_LOW
%      -norm_vol: Output a masked and somewhat intensity normalized and 
%                 thresholded version of the input. This is the default,
%                 and you can use -orig_vol to override it.
%      -orig_vol: Output a masked version of the input AND do not modify
%                 the values inside the brain as -norm_vol would.
%      -mask_vol: Output a mask volume instead of a skull-stripped
%                 volume.
%                 The mask volume containes:
%                  0: Voxel outside surface
%                  1: Voxel just outside the surface. This means the voxel
%                     center is outside the surface but inside the 
%                     bounding box of a triangle in the mesh. 
%                  2: Voxel intersects the surface (a triangle), but center
%                     lies outside.
%                  3: Voxel contains a surface node.
%                  4: Voxel intersects the surface (a triangle), center lies
%                     inside surface. 
%                  5: Voxel just inside the surface. This means the voxel
%                     center is inside the surface and inside the 
%                     bounding box of a triangle in the mesh. 
%                  6: Voxel inside the surface. 
%      -spat_norm: (Default) Perform spatial normalization first.
%                  This is a necessary step unless the volume has
%                  been 'spatnormed' already.
%      -no_spatnorm: Do not perform spatial normalization.
%                    Use this option only when the volume 
%                    has been run through the 'spatnorm' process
%      -spatnorm_dxyz DXYZ: Use DXY for the spatial resolution of the
%                           spatially normalized volume. The default 
%                           is the lowest of all three dimensions.
%                           For human brains, use DXYZ of 1.0, for
%                           primate brain, use the default setting.
%      -write_spatnorm: Write the 'spatnormed' volume to disk.
%      -niter N_ITER: Number of iterations. Default is 250
%         For denser meshes, you need more iterations
%         N_ITER of 750 works for LD of 50.
%      -ld LD: Parameter to control the density of the surface.
%              Default is 20 if -no_use_edge is used,
%              30 with -use_edge. See CreateIcosahedron -help
%              for details on this option.
%      -shrink_fac SF: Parameter controlling the brain vs non-brain
%              intensity threshold (tb). Default is 0.6.
%               tb = (Imax - t2) SF + t2 
%              where t2 is the 2 percentile value and Imax is the local
%              maximum, limited to the median intensity value.
%              For more information on tb, t2, etc. read the BET paper
%              mentioned above. Note that in 3dSkullStrip, SF can vary across 
%              iterations and might be automatically clipped in certain areas.
%              SF can vary between 0 and 1.
%              0: Intensities < median inensity are considered non-brain
%              1: Intensities < t2 are considered non-brain
%      -var_shrink_fac: Vary the shrink factor with the number of
%              iterations. This reduces the likelihood of a surface
%              getting stuck on large pools of CSF before reaching
%              the outer surface of the brain. (Default)
%      -no_var_shrink_fac: Do not use var_shrink_fac.
%      -shrink_fac_bot_lim SFBL: Do not allow the varying SF to go
%              below SFBL . Default 0.65, 0.4 when edge detection is used. 
%              This option helps reduce potential for leakage below 
%              the cerebellum.
%              In certain cases where you have severe non-uniformity resulting
%              in low signal towards the bottom of the brain, you will need to
%              reduce this parameter.
%      -pushout: Consider values above each node in addition to values
%                below the node when deciding on expansion. (Default)
%      -no_pushout: Do not use -pushout.
%      -exp_frac FRAC: Speed of expansion (see BET paper). Default is 0.1.
%      -touchup: Perform touchup operations at end to include
%                areas not covered by surface expansion. 
%                Use -touchup -touchup for aggressive makeup.
%                (Default is -touchup)
%      -no_touchup: Do not use -touchup
%      -fill_hole R: Fill small holes that can result from small surface
%                    intersections caused by the touchup operation.
%                    R is the maximum number of pixels on the side of a hole
%                    that can be filled. Big holes are not filled.
%                    If you use -touchup, the default R is 10. Otherwise 
%                    the default is 0.
%                    This is a less than elegant solution to the small
%                    intersections which are usually eliminated
%                    automatically. 
%      -NN_smooth NN_SM: Perform Nearest Neighbor coordinate interpolation
%                        every few iterations. Default is 72
%      -smooth_final SM: Perform final surface smoothing after all iterations.
%                        Default is 20 smoothing iterations.
%                        Smoothing is done using Taubin's method, 
%                        see SurfSmooth -help for detail.
%      -avoid_vent: avoid ventricles. Default.
%                   Use this option twice to make the avoidance more
%                   agressive. That is at times needed with old brains.
%      -no_avoid_vent: Do not use -avoid_vent.
%      -init_radius RAD: Use RAD for the initial sphere radius.
%                        For the automatic setting, there is an
%                        upper limit of 100mm for humans.
%                        For older brains with lots of CSF, you
%                        might benefit from forcing the radius 
%                        to something like 75mm
%      -avoid_eyes: avoid eyes. Default
%      -no_avoid_eyes: Do not use -avoid_eyes.
%      -use_edge: Use edge detection to reduce leakage into meninges and eyes.
%                 Default.
%      -no_use_edge: Do no use edges.
%      -push_to_edge: Perform aggressive push to edge at the end.
%                     This option might cause leakage.
%      -no_push_to_edge: (Default).
%      -use_skull: Use outer skull to limit expansion of surface into
%                  the skull due to very strong shading artifacts.
%                  This option is buggy at the moment, use it only 
%                  if you have leakage into skull.
%      -no_use_skull: Do not use -use_skull (Default).
%      -send_no_skull: Do not send the skull surface to SUMA if you are
%                      using  -talk_suma
%      -perc_int PERC_INT: Percentage of segments allowed to intersect
%                          surface. Ideally this should be 0 (Default). 
%                          However, few surfaces might have small stubborn
%                          intersections that produce a few holes.
%                          PERC_INT should be a small number, typically
%                          between 0 and 0.1. A -1 means do not do
%                          any testing for intersection.
%      -max_inter_iter N_II: Number of iteration to remove intersection
%                            problems. With each iteration, the program
%                            automatically increases the amount of smoothing
%                            to get rid of intersections. Default is 4
%      -blur_fwhm FWHM: Blur dset after spatial normalization.
%                       Recommended when you have lots of CSF in brain
%                       and when you have protruding gyri (finger like)
%                       Recommended value is 2..4. 
%      -interactive: Make the program stop at various stages in the 
%                    segmentation process for a prompt from the user
%                    to continue or skip that stage of processing.
%                    This option is best used in conjunction with options
%                    -talk_suma and -feed_afni
%      -demo_pause: Pause at various step in the process to facilitate
%                   interactive demo while 3dSkullStrip is communicating
%                   with AFNI and SUMA. See 'Eye Candy' mode below and
%                   -talk_suma option. 


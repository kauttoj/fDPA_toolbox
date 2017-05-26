# fDPA toolbox README

Current version of the toolbox is optimized and tested for SPM12
SPM8 is not recommended (some batch jobs missing & old segmentation)

KNOWN BUGS/LIMITATIONS:
(1) Detrending should be always used with Artifact Repair (ArtRep) tool, otherwise linear drifts may interfere ArtRep processing.
(2) DRIFTER code is outdated and not tested (not worth the effort for TR~2 or so)
(3) GUI code does some parameter checking, but not all different combinations are tested (bugs likely).
(5) Normalization is tested only for standard MNI152, trying custom bounding box and/or voxel sizes may fail.

TO DO LIST:
(1) fdpa_run.m is messy, should separate all processes in into separate functions
(2) a small manual or tutorial & comments are needed
(3) more testing with different processing combinations


Recommendations from John Ashburner:
"My guess is that disabling the MRF part (ie setting the parameter to zero), using 2 or 3 Gaussians to model the intensity distributions of the GM, WM and CSF, and reducing the amount of regularisation for the deformations (by about a factor of 4), may (or may not) give fractionally better segmentations."



Janne Kauttonen
9.5.2015
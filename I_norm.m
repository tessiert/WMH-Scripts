% Program to normalize intensities in nifti images

clear all;

close all;

dirData = '/home/trace/MRN/data/';

basename = 'M87145150_V1_flair_t2_no_skull';

in_fname = [dirData, basename, '.nii.gz'];

out_fname = [dirData, basename, '_matlab_norm'];

% Load file without applying header transformations
nii = load_untouch_nii(in_fname);

% Find indices of all voxels with nonzero intensity
pos_intensities = find(nii.img);

% Bin the intensity data (ignoring zero background)
%h=histogram(nii.img(pos_intensities));
counts=histcounts(nii.img(pos_intensities));

% Scale to most common image intensity

% Find largest bin count
%hist_peak = max(h.BinCounts)
hist_peak = max(counts);

% Find value of most common intensity
%mode_intensity = find(h.BinCounts==hist_peak)
mode_intensity = find(counts==hist_peak);

%figure(1);
%plot(counts);

% Scale every image to fixed value for most common intensity
intensity_scale = 100/mode_intensity;
scaled_img = nii.img .* intensity_scale;

%pos_intensities = find(scaled_img);

%figure(2);
%histogram(scaled_img(pos_intensities));

% Save scaled image
nii.img = scaled_img;
save_untouch_nii(nii, out_fname);



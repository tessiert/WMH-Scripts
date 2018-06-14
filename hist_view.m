% Program to normalize intensities in nifti images

clear all;

close all;

dirData1 = '/export/research/analysis/human/grosenberg/ugrant_20294/analysis_techdev/M87101020/Trace/results/';

n_bins=151;

file_list = {'difference_map_uncertainty_map'; 
             'white_matter_diff_map_1'; 
             'white_matter_diff_map_2'; 
             'V1_1_NAWM_flair_normalized'; 
             'V1_1_WMH_flair_normalized'; 
             'V1_2_NAWM_flair_normalized'; 
             'V1_2_WMH_flair_normalized';
             'V2_NAWM_flair_normalized'; 
             'V2_WMH_flair_normalized'};
         
tag='';

file_list=strcat(file_list, tag);



for m = 1:length(file_list)

  % Create full path filename
  in_fname{m} = [dirData1, file_list{m}, '.nii.gz'];

  % Load file without applying header transformations
  nii(m) = load_untouch_nii(in_fname{m});
  
  % Find indices of all voxels with nonzero intensity
  nonzero_intensities{m} = find(nii(m).img);
  
  % Bin the intensity data (ignoring zero background)
  [bin_count(m,:), intensities(m,:)]=hist(nii(m).img(nonzero_intensities{m}), n_bins);
  
  if m == 1
      % Symmetrize the histogram for difference_map_uncertainty_map
      bin_count(m,:)=(bin_count(m,:)+wrev(bin_count(m,:)))/2;
  end
  
  % Get total nonzero voxel counts for image
  tot_vox(m)=length(nonzero_intensities{m});
  
  % Convert histogram to probabilities
  p(m,:) = bin_count(m,:)/tot_vox(m);

end

h1=figure;
plot(intensities(1,:), p(1,:));
title('Difference Map Uncertainty Map:  V1_1 - V1_2 (Symmetrized)');
xlimits=xlim;

max_ind=find(p(2,:)==max(p(2,:)), 1);
intensities_shifted=intensities(1,:)+intensities(2,max_ind)-1;
h2=figure;
hold all
plot(intensities_shifted(1,:), p(1,:));
plot(intensities(2,:), p(2,:));
title('White Matter Difference Map (V2 - V1_1) - Green:  Consistent w/ No Change');
xlim(xlimits);

max_ind=find(p(3,:)==max(p(3,:)), 1);
intensities_shifted=intensities(1,:)+intensities(3,max_ind)-1;
h3=figure;
hold all
plot(intensities_shifted(1,:), p(1,:));
plot(intensities(3,:), p(3,:));
title('White Matter Difference Map (V2 - V1_2) - Green:  Consistent w/ No Change');
xlim(xlimits);

max_ind_NAWM=find(p(4,:)==max(p(4,:)), 1);
max_ind_WMH=find(p(5,:)==max(p(5,:)),1);
intensities_shifted_1=intensities(1,:)+intensities(4,max_ind_NAWM)-1;
h4=figure;
hold all
plot(intensities_shifted_1, p(1,:));
plot(intensities(4,:), p(4,:));
plot(intensities(5,:), p(5,:));

% Find NAWM and WMH curve intersection

% First find peaks of NAWM and WMH curves
NAWM_max_I = intensities(4, max_ind_NAWM)
WMH_max_I = intensities(5, max_ind_WMH);

% Intersection will be the minimum absolute difference of the two curves
% that occurs between the peaks
diff_vec = abs(p(4,:) - p(5,:));
intersection_pt = find(diff_vec==min(diff_vec(floor(NAWM_max_I):ceil(WMH_max_I))));
title(['V1_1: NAWM (Green) and WMH (Red) - Int = ', num2str(intersection_pt)]);

max_ind_NAWM=find(p(6,:)==max(p(6,:)), 1);
max_ind_WMH=find(p(7,:)==max(p(7,:)),1);
intensities_shifted_2=intensities(1,:)+intensities(6,max_ind_NAWM)-1;
h5=figure;
hold all
plot(intensities_shifted_2, p(1,:));
plot(intensities(6,:), p(6,:));
plot(intensities(7,:), p(7,:));

% Find NAWM and WMH curve intersection

% First find peaks of NAWM and WMH curves
NAWM_max_I = intensities(6, max_ind_NAWM)
WMH_max_I = intensities(7, max_ind_WMH);

% Intersection will be the minimum absolute difference of the two curves
% that occurs between the peaks
diff_vec = abs(p(6,:) - p(7,:));
intersection_pt = find(diff_vec==min(diff_vec(floor(NAWM_max_I):ceil(WMH_max_I))));
title(['V1_2: NAWM (Green) and WMH (Red) - Int = ', num2str(intersection_pt)]);

max_ind_NAWM=find(p(8,:)==max(p(8,:)), 1);
max_ind_WMH=find(p(9,:)==max(p(9,:)),1);
intensities_shifted_3=intensities(1,:)+intensities(8,max_ind_NAWM)-1;
h6=figure;
hold all
plot(intensities_shifted_3, p(1,:));
nawm_plot = plot(intensities(8,:), p(8,:));
plot(intensities(9,:), p(9,:));

% Find NAWM and WMH curve intersection

% First find peaks of NAWM and WMH curves
NAWM_max_I = intensities(8, max_ind_NAWM);
WMH_max_I = intensities(9, max_ind_WMH);

% Intersection will be the minimum absolute difference of the two curves
% that occurs between the peaks
diff_vec = abs(p(8,:) - p(9,:));
intersection_pt = find(diff_vec==min(diff_vec(floor(NAWM_max_I):ceil(WMH_max_I))));
%title(['V2: NAWM (Green) and WMH (Red) - Int = ', num2str(intersection_pt)]);
title('NAWM (Green) and WMH (Red) Normalized Intensity Histograms & WM Difference Map (Blue)');

% Relative proportion of WMH voxels at a particular intensity
h7=figure;
hold all

% Construct list of unique intensities for all WM
all_intensities = unique([intensities(8,:); intensities(9,:)]);

% Extrapolate the NAWM probability distribution to all intensities
NAWM_interp = interp1(intensities(8,:), p(8,:), all_intensities, 'nearest');

% Set NaNs to zero
NAWM_interp(isnan(NAWM_interp)) = 0;

% Normalize
NAWM_interp = NAWM_interp./sum(NAWM_interp);

% Same for WMH data
WMH_interp = interp1(intensities(9,:), p(9,:), all_intensities, 'nearest');

WMH_interp(isnan(WMH_interp)) = 0;

NAWM_interp = NAWM_interp./sum(NAWM_interp);

total = WMH_interp + NAWM_interp;

wmh_prop = WMH_interp./total;

all_wmh_prop_ind = 1:length(wmh_prop);

valid_wmh_prop_ind = all_wmh_prop_ind(not(isnan(wmh_prop)));

wmh_prop_interp = interp1(valid_wmh_prop_ind, wmh_prop(valid_wmh_prop_ind), all_wmh_prop_ind, 'nearest');

% Find the index of the first intensity above threshold
thr_ind = min(find(all_intensities >= 120))

% Extract the corresponding WMH proportion value
thr_prop = wmh_prop_interp(thr_ind)

% "Normalize" scores s.t. score at thr_ind = user_thr
adjusted_scores = wmh_prop_interp*(.9/thr_prop)

plot(all_intensities, wmh_prop_interp);
figure;
plot(all_intensities, adjusted_scores);

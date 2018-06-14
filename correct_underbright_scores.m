function correct_underbright_scores(DATADIR, NAWM_basename, WMH_basename, scores_basename, output_basename, user_thr, WMH_thr)

n_bins=151;

% Construct image filenames
NAWM_fname = [DATADIR, '/', NAWM_basename, '.nii.gz'];
WMH_fname = [DATADIR, '/', WMH_basename, '.nii.gz'];
scores_fname = [DATADIR, '/', scores_basename, '.nii.gz'];

% Load files without applying header transformations
NAWM_nii = load_untouch_nii(NAWM_fname);
WMH_nii = load_untouch_nii(WMH_fname);
scores_nii = load_untouch_nii(scores_fname);

% Calculate probability distributions (as a function of intensity) for
% input WM images
  
% Find indices of all voxels with nonzero intensity
nonzero_intensities_NAWM = find(NAWM_nii.img);
nonzero_intensities_WMH = find(WMH_nii.img);

% Bin the intensity data (ignoring zero background)
[bin_count_NAWM, intensities_NAWM]=hist(NAWM_nii.img(nonzero_intensities_NAWM), n_bins);
[bin_count_WMH, intensities_WMH]=hist(WMH_nii.img(nonzero_intensities_WMH), n_bins);

% Get total nonzero voxel counts for WM images
tot_vox_NAWM = length(nonzero_intensities_NAWM);
tot_vox_WMH = length(nonzero_intensities_WMH);

% Convert histograms to probabilities
p_NAWM = bin_count_NAWM/tot_vox_NAWM;
p_WMH = bin_count_WMH/tot_vox_WMH;

% Construct list of unique intensities for all WM voxels
all_intensities = unique([intensities_NAWM; intensities_WMH]);

% Extrapolate the NAWM data to all intensities
NAWM_interp = interp1(intensities_NAWM, p_NAWM, all_intensities, 'nearest');

% Set NaNs to zero
NAWM_interp(isnan(NAWM_interp)) = 0;

% Same for WMH data
WMH_interp = interp1(intensities_WMH, p_WMH, all_intensities, 'nearest');
WMH_interp(isnan(WMH_interp)) = 0;

% Sum the interpolated values
total = WMH_interp + NAWM_interp;

% Find the proportion of all WM voxels classified as WMH (within each
% histogram bin)
wmh_prop = WMH_interp./total;

% List of indices
all_wmh_prop_ind = 1:length(wmh_prop);

% Find proportions where 'total' bin was not empty
valid_wmh_prop_ind = all_wmh_prop_ind(not(isnan(wmh_prop)));

% Interpolate to correct for division by zero (empty bins)
wmh_prop_interp = interp1(valid_wmh_prop_ind, wmh_prop(valid_wmh_prop_ind), all_wmh_prop_ind, 'nearest');

% Find the index of the first intensity above threshold
thr_ind = min(find(all_intensities >= WMH_thr));

% Extract the corresponding WMH proportion value
thr_prop = wmh_prop_interp(thr_ind);

% If the histogram proportion at the intensity threshold suggests that the underbright voxels are scored too high 
if thr_prop < user_thr
    
    % Scale the underbright WMH scores by thr_prop
    scores_nii.img = scores_nii.img*thr_prop;

% If z-score, first scale s.t. max possible score for underbright voxels is
% user_thr, then scale by thr_prop
%scores_nii.img = scores_nii.img/max(max(max(scores_nii.img)))*user_thr*thr_prop;

end

% Save results
out_fname = [DATADIR, '/', output_basename, '.nii.gz'];
save_untouch_nii(scores_nii, out_fname);

% Terminates matlab (needed when called from bash script)
quit;
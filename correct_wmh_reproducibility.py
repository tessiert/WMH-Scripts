#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Thu May 31 15:47:56 2018

@author: ttessier
"""

import os
import csv
import glob
import numpy as np
import nibabel as nib    # Python neuroimaging file routines
from scipy import ndimage # N-dimensional image processing



def create_threshold_mask(thr, wmh_map):
    
    wmh_mask = np.zeros(wmh_map.shape)
    
    above_thr = wmh_map > thr

    wmh_mask[above_thr] = 1
            
    return wmh_mask



def dice(mask_1, mask_2):
    
    tot_mask = mask_1 + mask_2
    
    num_wmh_agree = tot_mask[tot_mask == 2].size
    
    num_wmh_disagree = tot_mask[tot_mask == 1].size
    
    dice_coeff = 2*num_wmh_agree/(2*num_wmh_agree + num_wmh_disagree)

    return dice_coeff  



def correct_wmh(thr, maps, masks):
    
    # Combining the two masks in this way yields:  
    #   '1' where voxel is marked WMH in first mask only,
    #   '2' where voxel is marked WMH in second mask only,
    #   '3' where voxel is marked WMH in both masks, 
    #   and zero elsewhere
    region_mask = masks[0] + 2*masks[1]
    
    wmh_overlap = (region_mask == 3)
    
    # Find the means of the two maps in the region in which they agree
    mean_1 = maps[0][wmh_overlap].mean()
    mean_2 = maps[1][wmh_overlap].mean()
        
    # Calculate new baseline WMH threshold
    base_thr = 0.6*min(mean_1, mean_2) - 0.3
    
    # Constrain base_thr to fall between 1.5 and 3.0
    if base_thr < 1.5:        
        base_thr = 1.5
    elif base_thr > 3.0:
        base_thr = 3.0
        
    diff = abs(mean_1 - mean_2)
    
    new_thr = max(base_thr, thr - diff)
    
    if mean_1 > mean_2:
        better_visit = 0
        worse_visit  = 1
    else:
        better_visit = 1
        worse_visit  = 0
        
    better_mask = masks[better_visit].copy()
    worse_map = maps[worse_visit].copy()
    worse_mask = masks[worse_visit].copy()
    better_region = better_visit + 1
       
    # Arvind's corrections to lower quality mask
    better_region_mask = np.zeros(region_mask.shape)
    
    better_region_mask[region_mask == better_region] = 1
    
    scores_to_revisit = better_region_mask*worse_map
    
    new_worse_mask = worse_mask.copy()
     
    new_worse_mask[scores_to_revisit > new_thr] = 1

    # New corrections to higher quality mask 
    
    # Recalculate region_mask using image quality correction results
    new_region_mask = better_mask + 2*new_worse_mask
    new_wmh_overlap = (new_region_mask == 3)  
    
    overlap_region_mask = np.zeros(new_region_mask.shape)
    
    overlap_region_mask[new_wmh_overlap] = 1
    
    # Dilate the region of agreement by one voxel
    dilated_mask = ndimage.morphology.binary_dilation(overlap_region_mask, iterations=1)
  
    border_mask = dilated_mask - overlap_region_mask
    
    worse_region_mask = np.zeros(new_region_mask.shape)

    worse_region_mask[new_region_mask == 2] = 1    
    
    vox_to_add = border_mask*worse_region_mask
    
    new_better_mask = np.zeros(new_region_mask.shape)
        
    new_better_mask[(better_mask + vox_to_add) > 0] = 1
      
    if better_visit == 0:
        
        return [new_better_mask, new_worse_mask]
    
    else: 
    
        return [new_worse_mask, new_better_mask]
    
        
    
def main():
    
    """Program description here"""
    
    thr = 3.0
    
    ddir = '/export/research/analysis/human/grosenberg/ugrant_20294/analysis_flair/'
    
    stats_file = 'wmh_stats.txt'
    
    start_dir = os.getcwd()
    
    os.chdir(ddir)
    
    with open(ddir + stats_file, 'w') as csvfile:
        
        csvwriter = csv.writer(csvfile, delimiter='\t')
        csv_header = ['Subject_Date_ID', 'WMH_1', 'WMH_2', 'Common', 'Only_1', 'Only_2', 'Dice']
        csvwriter.writerow(csv_header)
    
    for subj_dir in sorted(glob.glob('M*')):
    
        os.chdir(ddir + subj_dir)
        
        for study_dir in glob.glob('St*'):
            
            cur_dir = ddir + subj_dir +'/' + study_dir + '/ucd/'
            
            os.chdir(cur_dir)  
            
            study_date = study_dir[5:13]
            
            file_id = subj_dir + '_' + study_date           
    
            file1 = file_id + '_UCD_WMH_ZScore_to_template.nii.gz'
            file2 = file_id + '_UCD_WMH_ZScore_to_template_1.nii.gz'
    
            # Load the images
            v1_nii = nib.load(file1)
            v2_nii = nib.load(file2)
    
            wmh_map_1 = v1_nii.get_data().astype(float)
            wmh_map_2 = v2_nii.get_data().astype(float)
    
            # Create the WMH masks using the input threshold
            orig_mask_1 = create_threshold_mask(thr, wmh_map_1)
            orig_mask_2 = create_threshold_mask(thr, wmh_map_2)
    
            # Dice coefficient measures 'agreement' between two WMH masks
            orig_dice = dice(orig_mask_1, orig_mask_2)
    
            print('Dice coeff for uncorrected masks:  ' + str(orig_dice))
  
            # Apply correction subroutine
            new_masks = correct_wmh(thr, [wmh_map_1, wmh_map_2], [orig_mask_1, orig_mask_2])
  
            new_dice = dice(new_masks[0], new_masks[1])
    
            print('Dice coeff for corrected masks:  ' + str(new_dice))
            
            v1_mask_nii = nib.nifti1.Nifti1Image(new_masks[0], None, header=v1_nii.header.copy())
    
            nib.save(v1_mask_nii, cur_dir + 'v1_corrected_trace.nii.gz')
    
            v2_mask_nii = nib.nifti1.Nifti1Image(new_masks[1], None, header=v2_nii.header.copy())
    
            nib.save(v2_mask_nii, cur_dir + 'v2_corrected_trace.nii.gz')
    
            # Calculate and save stats
            orig_num_common_vox = int((orig_mask_1*orig_mask_2).sum())
    
            orig_diff_mask = orig_mask_1 - orig_mask_2
            orig_num_only_v1 = (orig_diff_mask > 0).sum()
            orig_num_only_v2 = (orig_diff_mask < 0).sum()
    
            new_num_common_vox = int((new_masks[0]*new_masks[1]).sum())
    
            new_diff_mask = new_masks[0] - new_masks[1]
            new_num_only_v1 = (new_diff_mask > 0).sum()
            new_num_only_v2 = (new_diff_mask < 0).sum()
    
            orig_wmh_totals = [file_id, int(orig_mask_1.sum()), int(orig_mask_2.sum()), orig_num_common_vox, orig_num_only_v1, orig_num_only_v2, orig_dice]
    
            new_wmh_totals  = [file_id, int(new_masks[0].sum()), int(new_masks[1].sum()), new_num_common_vox, new_num_only_v1, new_num_only_v2, new_dice]
    
            with open(ddir + stats_file, 'a') as csvfile:
        
                csvwriter = csv.writer(csvfile, delimiter='\t')
        
                csvwriter.writerow(orig_wmh_totals)
                csvwriter.writerow(new_wmh_totals)
          
    os.chdir(start_dir)

    
main()    
    
    
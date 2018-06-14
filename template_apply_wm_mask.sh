#!/bin/bash

# template_apply_wm_mask.sh v1.0

# If there are any input arguments
if [[ $# != 0 ]] ; then
   echo "Usage:  template_apply_wm_mask.sh"
   echo "Script takes no input arguments, and must be run in a directory containing one subdirectory per subject."
   echo "Assumes that median_template.sh, template_ucd_wmh.sh, template_bianca_wmh.sh, and template_wm_masks.sh, and optimize_bianca_and_masks.sh have already been run on the subject data."
   echo "Note:  The master script template_wmh_analyze.sh can be used to automatically run all pipeline scripts in the correct order."
   exit
fi

# Bianca threshold % for classifying voxel as WMH
THR=90

START_DIR=`pwd`

TEMPLATE_DIR_NAME="median_template_data"

# For calculation of total elapsed time
SECONDS=0

TIME_STAMP=`date '+%m%d%Y%H%M%S'`

LOG_FILE=${START_DIR}/template_apply_wm_mask_${TIME_STAMP}.log

echo "Applying postmasks to Bianca and UCD segmentation results in median template space..." > ${LOG_FILE}

SUBJ_COUNT=0

# Loop over each subject directory
for CUR_SUBJ_DIR in ${START_DIR}/M[0-9]*[0-9] 
do

  SUBJ=$(echo ${CUR_SUBJ_DIR} | awk -F/ '{print $NF}')

  CUR_OUT_DIR=${CUR_SUBJ_DIR}/${TEMPLATE_DIR_NAME}

  # If median template data exists for the current subject
  if [[ -d ${CUR_OUT_DIR} ]]; then

    # At this level, each 'Study' subdirectory contains image data that has already been mapped to the median template
    for CUR_STUDY_DIR in ${CUR_OUT_DIR}/Study*
    do

      CUR_STUDY=$(echo ${CUR_STUDY_DIR} | awk -F/ '{print $NF}')

      CUR_DATE=$(echo ${CUR_STUDY} | awk '{print substr($0,6,8)}')

      CUR_FILE_ID=${SUBJ}_${CUR_DATE}

      CUR_MASK_DIR=${CUR_STUDY_DIR}/bianca_masks

      CUR_BIANCA_DIR=${CUR_STUDY_DIR}/bianca

      CUR_UCD_DIR=${CUR_STUDY_DIR}/ucd

      # If Bianca and UCD segmentation outputs exists for the current visit
      if [[ -d ${CUR_BIANCA_DIR} && -d ${CUR_UCD_DIR} ]]; then

        #If a WM mask exists for the current visit
        if [[ -f ${CUR_MASK_DIR}/${CUR_FILE_ID}_t1n_to_template_wm_mask.nii.gz ]]; then

          echo "Applying visit-specific WM mask to Bianca and UCD segmentation results for visit "${CUR_STUDY}" for subject "${SUBJ} | tee -a ${LOG_FILE}
#          fslmaths ${CUR_BIANCA_DIR}/${CUR_FILE_ID}_bianca_output_to_template_T${THR}.nii.gz -mas ${CUR_MASK_DIR}/${CUR_FILE_ID}_t1n_to_template_wm_mask.nii.gz ${CUR_BIANCA_DIR}/${CUR_FILE_ID}_bianca_output_to_template_T${THR}_postmasked.nii.gz
          fslmaths ${CUR_UCD_DIR}/${CUR_FILE_ID}_UCD_WMH_mask.nii.gz -mas ${CUR_MASK_DIR}/${CUR_FILE_ID}_t1n_to_template_wm_mask.nii.gz ${CUR_UCD_DIR}/${CUR_FILE_ID}_UCD_WMH_mask_postmasked.nii.gz

        else

          echo "No visit-specific WM mask for visit "${CUR_STUDY}" for subject "${SUBJ}" found." | tee -a ${LOG_FILE}

        fi

        # If a multi-visit WM mask exists for the current subject
        if [[ -f ${CUR_OUT_DIR}/multi_visit_wm_mask.nii.gz ]]; then

          echo "Applying optimized WM mask to Bianca and UCD segmentation results for visit "${CUR_STUDY}" for subject "${SUBJ} | tee -a ${LOG_FILE}
#          fslmaths ${CUR_BIANCA_DIR}/${CUR_FILE_ID}_bianca_output_to_template_T${THR}_optimized.nii.gz -mas ${CUR_OUT_DIR}/multi_visit_wm_mask.nii.gz ${CUR_BIANCA_DIR}/${CUR_FILE_ID}_bianca_output_to_template_T${THR}_optimized_postmasked.nii.gz
          fslmaths ${CUR_UCD_DIR}/${CUR_FILE_ID}_UCD_WMH_mask.nii.gz -mas ${CUR_OUT_DIR}/multi_visit_wm_mask.nii.gz ${CUR_UCD_DIR}/${CUR_FILE_ID}_UCD_WMH_mask_optimal_postmasked.nii.gz

        else

          echo "No multi-visit mask for subject "${SUBJ}" found." | tee -a ${LOG_FILE}

        fi

      else

        echo "At least one of Bianca/UCD segmentation results not found for subject "${SUBJ} | tee -a ${LOG_FILE}

      fi

    done

  else 

    echo "No median template data found for subject "${SUBJ}".  If longitudinal data exists, run median_template.sh first, next template_wm_masks.sh, template_bianca_wmh.sh, and template_ucd_wmh.sh, and finally optimize_bianca_and_masks.sh" | tee -a ${LOG_FILE} 

  fi

  SUBJ_COUNT=$((SUBJ_COUNT + 1))

done

echo "template_apply_wm_mask.sh complete. "${SUBJ_COUNT}" subjects processed."  | tee -a ${LOG_FILE}

ELAPSED="Elapsed time: $(($SECONDS / 3600))hrs $((($SECONDS / 60) % 60))min $(($SECONDS % 60))sec"

echo ${ELAPSED} | tee -a ${LOG_FILE} 












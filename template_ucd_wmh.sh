#!/bin/bash

# template_ucd_wmh.sh v1.0

# If there are any input arguments
if [[ $# != 0 ]] ; then
   echo "Usage:  template_ucd_wmh.sh"
   echo "Script takes no input arguments, and must be run in a directory containing one subdirectory per subject."
   echo "Assumes that median_template.sh and (optionally for postmasking) template_wm_masks.sh have already been run on the subject data."
   echo "Note:  The master script template_wmh_analyze.sh can be used to automatically run all pipeline scripts in the correct order."
   exit
fi

START_DIR=`pwd`

# Directory containing wmh_detect code from deCarli group
CODE_DIR="/export/mialab/users/ttessier/code/external/wmh_detection"

TEMPLATE_DIR_NAME="median_template_data"

# For calculation of total elapsed time
SECONDS=0

TIME_STAMP=`date '+%m%d%Y%H%M%S'`

LOG_FILE=${START_DIR}/template_ucd_wmh_${TIME_STAMP}.log

echo "Starting UCD WMH segmentation routine in median template space..." > ${LOG_FILE}

MASK_COUNT=0
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

      CUR_RESULTS_DIR=${CUR_STUDY_DIR}/ucd

      CUR_TEMP_DIR=${CUR_STUDY_DIR}/tmp

      # Create subdirectory structure
      if [ ! -d ${CUR_RESULTS_DIR} ]; then
        mkdir ${CUR_RESULTS_DIR}
      fi

      # Map T1 brain images from template space to MDT3 (standard space used by IdeaLab software) in order to get the transformations between spaces
      echo "Transforming images for visit ${CUR_STUDY} for subject ${SUBJ} to MDT3 space" | tee -a ${LOG_FILE}

      # Get transform
      flirt -interp spline -in ${CUR_STUDY_DIR}/${CUR_FILE_ID}_t1n_brain_to_template.nii.gz -ref ${CODE_DIR}/MDT3 -dof 12 -omat ${CUR_TEMP_DIR}/${CUR_FILE_ID}_t1_brain_template_to_MDT3_lin.mat -out ${CUR_TEMP_DIR}/${CUR_FILE_ID}_t1_brain_template_to_MDT3_lin

      fnirt --in=${CUR_STUDY_DIR}/${CUR_FILE_ID}_t1n_brain_to_template.nii.gz --ref=${CODE_DIR}/MDT3 --fout=${CUR_TEMP_DIR}/${CUR_FILE_ID}_t1_brain_template_to_MDT3_nonlin_field --iout=${CUR_TEMP_DIR}/${CUR_FILE_ID}_t1_brain_template_to_MDT3_nonlin --cout=${CUR_TEMP_DIR}/${CUR_FILE_ID}_t1_brain_template_to_MDT3_nonlin_coeff --aff=${CUR_TEMP_DIR}/${CUR_FILE_ID}_t1_brain_template_to_MDT3_lin.mat

      # Use transform to map Flair to MDT3 space
      applywarp -i ${CUR_STUDY_DIR}/${CUR_FILE_ID}_flairn_t1n_brain_to_template.nii.gz -r ${CODE_DIR}/MDT3 -w ${CUR_TEMP_DIR}/${CUR_FILE_ID}_t1_brain_template_to_MDT3_nonlin_coeff -o ${CUR_TEMP_DIR}/${CUR_FILE_ID}_flairn_t1_brain_to_MDT3.nii.gz

      # Unzip the MDT3 Flair image
      gzip -d -f ${CUR_TEMP_DIR}/${CUR_FILE_ID}_flairn_t1_brain_to_MDT3.nii.gz

      # run UCD wmh_detect algorithm
      echo "Running UCD WMH segmentation for visit "${CUR_STUDY}" for subject "${SUBJ} | tee -a ${LOG_FILE}

      # Normalize the input image
      normalizeFlair ${CUR_TEMP_DIR}/${CUR_FILE_ID}_flairn_t1_brain_to_MDT3.nii 100

      # Run UCD WMH detection algorithm
      zScoresMultiplePassArgs ${CUR_TEMP_DIR}/${CUR_FILE_ID}_flairn_t1_brain_to_MDT3_normalized.nii ${CODE_DIR}/WMH_Template.nii ${CODE_DIR}/MDT3_mask.nii ${CODE_DIR}/WMHPercentage_mask.nii ${CODE_DIR}/confileg

      # Invert the above warp and transform wmh_detect results back to median template space
      invwarp -w ${CUR_TEMP_DIR}/${CUR_FILE_ID}_t1_brain_template_to_MDT3_nonlin_coeff -r ${CUR_STUDY_DIR}/${CUR_FILE_ID}_t1n_brain_to_template.nii.gz -o ${CUR_TEMP_DIR}/${CUR_FILE_ID}_t1_brain_MDT3_to_template_nonlin_coeff

      # Map WMH segmentation output (WMH z-score map) back to template space
      applywarp -i ${CUR_TEMP_DIR}/${CUR_FILE_ID}_flairn_t1_brain_to_MDT3_normalized_ZScore.nii -r ${CUR_STUDY_DIR}/${CUR_FILE_ID}_t1n_brain_to_template.nii.gz -w ${CUR_TEMP_DIR}/${CUR_FILE_ID}_t1_brain_MDT3_to_template_nonlin_coeff -o ${CUR_RESULTS_DIR}/${CUR_FILE_ID}_UCD_WMH_ZScore_to_template.nii.gz

      # Threshold the z-score map and binarize to get WMH Mask
      fslmaths ${CUR_RESULTS_DIR}/${CUR_FILE_ID}_UCD_WMH_ZScore_to_template.nii.gz -thr 3 -bin ${CUR_RESULTS_DIR}/${CUR_FILE_ID}_UCD_WMH_mask.nii.gz

      MASK_COUNT=$((MASK_COUNT + 1))

    done

  else

    echo "No median template data found for subject "${SUBJ}".  If longitudinal data exists, run median_template.sh first, then run template_ucd_wmh.sh"

  fi

  SUBJ_COUNT=$((SUBJ_COUNT + 1))

done

echo "template_ucd_wmh.sh complete. "${SUBJ_COUNT}" subjects processed and "${MASK_COUNT}" visits segmented."  | tee -a ${LOG_FILE}

ELAPSED="Elapsed time: $(($SECONDS / 3600))hrs $((($SECONDS / 60) % 60))min $(($SECONDS % 60))sec"

echo ${ELAPSED} | tee -a ${LOG_FILE} 








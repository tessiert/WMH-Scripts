#!/bin/bash

# template_optimize_bianca_and_masks.sh v1.0

# If there are any input arguments
if [[ $# != 0 ]] ; then
   echo "Usage:  template_optimize_bianca_and_masks.sh"
   echo "Script takes no input arguments, and must be run in a directory containing one subdirectory per subject."
   echo "Assumes that median_template.sh, template_bianca_wmh.sh, and template_wm_masks.sh have already been run on the subject data."
   echo "Note:  The master script template_wmh_analyze.sh can be used to automatically run all pipeline scripts in the correct order."
   exit
fi

function median_norm {
  MEDIAN=$(fslstats $1.nii.gz -P 50)
MEDIAN=${MEDIAN%.*}
  fslmaths $1.nii.gz -div ${MEDIAN} -mul 100 $1_norm.nii.gz
  return ${MEDIAN}
}

START_DIR=`pwd`

TEMPLATE_DIR_NAME="median_template_data"

# For calculation of total elapsed time
SECONDS=0

# Threshold used to create binary map from raw bianca output
THR=90

# Thresholds determined from Matlab histograms
WMH_THR=120
BRIGHT_THR=130

TIME_STAMP=`date '+%m%d%Y%H%M%S'`

LOG_FILE=${START_DIR}/template_optimize_bianca_and_masks_${TIME_STAMP}.log

echo "Optimizing Bianca output and WM masks in median template space..." > ${LOG_FILE}

SUBJ_COUNT=0
OPT_COUNT=0

# Loop over each subject directory
for CUR_SUBJ_DIR in ${START_DIR}/M[0-9]*[0-9] 
do

  SUBJ=$(echo ${CUR_SUBJ_DIR} | awk -F/ '{print $NF}')

  CUR_OUT_DIR=${CUR_SUBJ_DIR}/${TEMPLATE_DIR_NAME}

  # If median template data exists for the current subject
  if [[ -d ${CUR_OUT_DIR} ]]; then

    STUDY_COUNT=0

    # Construct multi-visit white matter mask in template space
    echo "Constructing multi-visit white matter mask for subject "${SUBJ} | tee -a ${LOG_FILE}

    # At this level, each 'Study' subdirectory contains image data that has already been mapped to the median template
    for CUR_STUDY_DIR in ${CUR_OUT_DIR}/Study*
    do

      CUR_MASK_DIR=${CUR_STUDY_DIR}/bianca_masks

      # If a wm mask exists for the current visit
      if [[ -d ${CUR_MASK_DIR} ]]; then

        CUR_STUDY=$(echo ${CUR_STUDY_DIR} | awk -F/ '{print $NF}')

        CUR_DATE=$(echo ${CUR_STUDY} | awk '{print substr($0,6,8)}')

        CUR_FILE_ID=${SUBJ}_${CUR_DATE}

        # If this is the first visit for the current subject
        if [[ ${STUDY_COUNT} -eq 0 ]]; then

          # Use visit #1 mask as starting point
          cp ${CUR_MASK_DIR}/${CUR_FILE_ID}_t1n_to_template_wm_mask.nii.gz ${CUR_OUT_DIR}/multi_visit_wm_mask.nii.gz

        else

          # Create (exclusive) composite white matter mask in template space
          fslmaths ${CUR_OUT_DIR}/multi_visit_wm_mask.nii.gz -mas ${CUR_MASK_DIR}/${CUR_FILE_ID}_t1n_to_template_wm_mask.nii.gz ${CUR_OUT_DIR}/multi_visit_wm_mask.nii.gz

        fi

        STUDY_COUNT=$((STUDY_COUNT + 1))

      fi

    done

    # Loop over visits again to apply (and correct) newly created composite white matter mask
    for CUR_STUDY_DIR in ${CUR_OUT_DIR}/Study*
    do

      CUR_STUDY=$(echo ${CUR_STUDY_DIR} | awk -F/ '{print $NF}')

      CUR_DATE=$(echo ${CUR_STUDY} | awk '{print substr($0,6,8)}')

      CUR_FILE_ID=${SUBJ}_${CUR_DATE}

      CUR_DATA_DIR=${CUR_SUBJ_DIR}/${CUR_STUDY}/preprocess

      CUR_TEMP_DIR=${CUR_STUDY_DIR}/tmp

      # Use mask to extract white matter portion of flair_brain
      fslmaths ${CUR_STUDY_DIR}/${CUR_FILE_ID}_flairn_t1n_brain_to_template.nii.gz -mas ${CUR_OUT_DIR}/multi_visit_wm_mask.nii.gz ${CUR_TEMP_DIR}/${CUR_FILE_ID}_white_matter.nii.gz

      # Normalize the white matter images to a common value (median normalization to 100) output is 'input'_norm.nii.gz
      median_norm ${CUR_TEMP_DIR}/${CUR_FILE_ID}_white_matter
      MEDIAN=$?

      # Include overbright voxels as WM (add to mask) since these are sometimes misclassified as GM
      fslmaths ${CUR_STUDY_DIR}/${CUR_FILE_ID}_flairn_t1n_brain_to_template.nii.gz -div ${MEDIAN} -mul 100 ${CUR_TEMP_DIR}/${CUR_FILE_ID}_flairn_t1n_brain_to_template_norm.nii.gz
      fslmaths ${CUR_TEMP_DIR}/${CUR_FILE_ID}_flairn_t1n_brain_to_template_norm.nii.gz -thr ${BRIGHT_THR} ${CUR_TEMP_DIR}/${CUR_FILE_ID}_overbright.nii.gz
      fslmaths ${CUR_OUT_DIR}/multi_visit_wm_mask.nii.gz -add ${CUR_TEMP_DIR}/${CUR_FILE_ID}_overbright.nii.gz -bin ${CUR_OUT_DIR}/multi_visit_wm_mask.nii.gz

      # Register flair brain mask to template space
      mri_convert -rl ${CUR_OUT_DIR}/multi_visit_template.nii.gz -at ${CUR_OUT_DIR}/${CUR_STUDY}/${CUR_STUDY}_to_tpl_concat.lta -odt float ${CUR_DATA_DIR}/${CUR_FILE_ID}_flairn_brain_mask.nii.gz ${CUR_TEMP_DIR}/${CUR_FILE_ID}_flairn_t1n_brain_to_template_mask.nii.gz

      # Rebinarize after transformation
      fslmaths ${CUR_TEMP_DIR}/${CUR_FILE_ID}_flairn_t1n_brain_to_template_mask.nii.gz -bin ${CUR_TEMP_DIR}/${CUR_FILE_ID}_flairn_t1n_brain_to_template_mask.nii.gz

      # Apply whole brain mask to ensure things like eyes/optic nerve, etc. don't get picked up and called WM
      fslmaths ${CUR_OUT_DIR}/multi_visit_wm_mask.nii.gz -mas ${CUR_TEMP_DIR}/${CUR_FILE_ID}_flairn_t1n_brain_to_template_mask.nii.gz -bin ${CUR_OUT_DIR}/multi_visit_wm_mask.nii.gz

    done

    # Loop over visits once again to optimize bianca output (remove underbright voxels tagged by bianca as WMH and restrict results to corrected mask generated above)
    for CUR_STUDY_DIR in ${CUR_OUT_DIR}/Study*
    do

      CUR_STUDY=$(echo ${CUR_STUDY_DIR} | awk -F/ '{print $NF}')

      CUR_DATE=$(echo ${CUR_STUDY} | awk '{print substr($0,6,8)}')

      CUR_FILE_ID=${SUBJ}_${CUR_DATE}

      CUR_BIANCA_DIR=${CUR_STUDY_DIR}/bianca

      CUR_TEMP_DIR=${CUR_STUDY_DIR}/tmp

      # If bianca output exists for the current visit, apply optimizations
      if [[ -d ${CUR_BIANCA_DIR} ]]; then

        echo "Optimizing bianca output for visit "${CUR_STUDY}" for subject "${SUBJ} | tee -a ${LOG_FILE}

        # Extract parts of Flair images tagged by bianca as WMH
        fslmaths ${CUR_TEMP_DIR}/${CUR_FILE_ID}_flairn_t1n_brain_to_template_norm.nii.gz -mas ${CUR_BIANCA_DIR}/${CUR_FILE_ID}_bianca_output_to_template_T${THR}.nii.gz ${CUR_TEMP_DIR}/${CUR_FILE_ID}_WMH_flair_norm.nii.gz

        # 'Correct' bianca results using Matlab histogram values
        fslmaths ${CUR_TEMP_DIR}/${CUR_FILE_ID}_WMH_flair_norm.nii.gz -thr ${WMH_THR} -bin ${CUR_BIANCA_DIR}/${CUR_FILE_ID}_bianca_output_to_template_T${THR}_optimized.nii.gz

        OPT_COUNT=$((OPT_COUNT + 1))

      else

        echo "No raw bianca results for visit ${CUR_STUDY} for subject ${SUBJ}.  template_bianca_wmh.sh must be run on this data before optimization can proceed." | tee -a ${LOG_FILE} 

      fi

    done

  else

    echo "No median template data found for subject "${SUBJ}".  If longitudinal data exists, run median_template.sh first, next template_wm_masks.sh and template_bianca_wmh.sh, and finally optimize_bianca_and_masks.sh" | tee -a ${LOG_FILE} 

  fi

  SUBJ_COUNT=$((SUBJ_COUNT + 1))

done

echo "template_optimize_bianca_and_masks.sh complete. "${SUBJ_COUNT}" subjects processed and "${OPT_COUNT}" optimizations completed." | tee -a ${LOG_FILE}

ELAPSED="Elapsed time: $(($SECONDS / 3600))hrs $((($SECONDS / 60) % 60))min $(($SECONDS % 60))sec"

echo ${ELAPSED} | tee -a ${LOG_FILE} 





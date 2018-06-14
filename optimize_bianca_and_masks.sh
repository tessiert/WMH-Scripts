#!/bin/bash

# optimize_bianca_and_masks.sh v1.0

# There should only be one compulsory argument
if [ $# != 1 ]; then
   echo "Usage:"
   echo "optimize_bianca_and_masks.sh <subject_list>"
   echo "Single argument must be the name <subject_list> of a .txt file containing one line for each subject of the form, e.g.,:"
   echo "{Abs_path}/M87104356"
   exit
fi

function median_norm {
  MEDIAN=$(fslstats $1.nii.gz -P 50)
MEDIAN=${MEDIAN%.*}
  fslmaths $1.nii.gz -div ${MEDIAN} -mul 100 $1_norm.nii.gz
  return ${MEDIAN}
}

SUBJ_LIST_FILE=${1}

START_DIR=`pwd`

BIANCA_DIR_NAME="bianca"

# For calculation of total elapsed time
SECONDS=0

# Threshold used to create binary map from raw bianca output
THR=90

# Thresholds determined from Matlab histograms
WMH_THR=120
BRIGHT_THR=130

TIME_STAMP=`date '+%m%d%Y%H%M%S'`

LOG_FILE=${START_DIR}/optimize_bianca_and_masks_${TIME_STAMP}.log

echo "Optimizing Bianca output and WM masks in native (T1) space..." > ${LOG_FILE}

VISIT_COUNT=0
SUBJ_COUNT=0

while read CUR_SUBJ_DIR
do

  SUBJ=$(echo ${CUR_SUBJ_DIR} | awk -F/ '{print $NF}')

  # Extract white matter portion of Flairs
  for CUR_STUDY_DIR in ${CUR_SUBJ_DIR}/Study*
  do

    CUR_STUDY=$(echo ${CUR_STUDY_DIR} | awk -F/ '{print $NF}')

    CUR_DATE=$(echo ${CUR_STUDY} | awk '{print substr($0,6,8)}')

    CUR_FILE_ID=${SUBJ}_${CUR_DATE}

    CUR_DATA_DIR=${CUR_STUDY_DIR}/preprocess

    CUR_BIANCA_DIR=${CUR_STUDY_DIR}/${BIANCA_DIR_NAME}

    CUR_TEMP_DIR=${CUR_STUDY_DIR}/tmp

    echo "Creating optimized WM mask for visit "${CUR_STUDY}" for subject "${SUBJ} | tee -a ${LOG_FILE}

    # Use mask to extract white matter portion of flair_brain
    fslmaths ${CUR_DATA_DIR}/${CUR_FILE_ID}_flairn_t1n_brain.nii.gz -mas ${CUR_BIANCA_DIR}/${CUR_FILE_ID}_t1n_bianca_mask.nii.gz ${CUR_TEMP_DIR}/${CUR_FILE_ID}_white_matter.nii.gz

    # Normalize the white matter image to a common value (median normalization to 100) output is 'input'_norm.nii.gz
    median_norm ${CUR_TEMP_DIR}/${CUR_FILE_ID}_white_matter
    MEDIAN=$?

    # Include overbright voxels as WM (add to mask) since these are sometimes misclassified as GM
    fslmaths ${CUR_DATA_DIR}/${CUR_FILE_ID}_flairn_t1n_brain.nii.gz -div ${MEDIAN} -mul 100 ${CUR_TEMP_DIR}/${CUR_FILE_ID}_flairn_t1n_brain_norm.nii.gz
    fslmaths ${CUR_TEMP_DIR}/${CUR_FILE_ID}_flairn_t1n_brain_norm.nii.gz -thr ${BRIGHT_THR} ${CUR_TEMP_DIR}/${CUR_FILE_ID}_overbright.nii.gz
    fslmaths ${CUR_BIANCA_DIR}/${CUR_FILE_ID}_t1n_bianca_mask.nii.gz -add ${CUR_TEMP_DIR}/${CUR_FILE_ID}_overbright.nii.gz -bin ${CUR_BIANCA_DIR}/${CUR_FILE_ID}_t1n_corrected_wm_mask.nii.gz

    # Register flair brain mask to t1 space
    flirt -in ${CUR_DATA_DIR}/${CUR_FILE_ID}_flairn_brain_mask.nii.gz -ref ${CUR_DATA_DIR}/${CUR_FILE_ID}_flairn_t1n_brain.nii.gz -applyxfm -init ${CUR_DATA_DIR}/xfms/${CUR_FILE_ID}_flairn_t1n.mtx -out ${CUR_DATA_DIR}/${CUR_FILE_ID}_flairn_t1n_brain_mask.nii.gz

    # Rebinarize after transformation
    fslmaths ${CUR_DATA_DIR}/${CUR_FILE_ID}_flairn_t1n_brain_mask.nii.gz -bin ${CUR_DATA_DIR}/${CUR_FILE_ID}_flairn_t1n_brain_mask.nii.gz

    # Apply whole brain mask to ensure things like eyes/optic nerve, etc. don't get picked up and called WM
    fslmaths ${CUR_BIANCA_DIR}/${CUR_FILE_ID}_t1n_corrected_wm_mask.nii.gz -mas ${CUR_DATA_DIR}/${CUR_FILE_ID}_flairn_t1n_brain_mask.nii.gz -bin ${CUR_BIANCA_DIR}/${CUR_FILE_ID}_t1n_corrected_wm_mask.nii.gz

  done

  # Loop over visits once again to remove underbright voxels tagged by bianca as WMH
  for CUR_STUDY_DIR in ${CUR_SUBJ_DIR}/Study*
  do

    CUR_STUDY=$(echo ${CUR_STUDY_DIR} | awk -F/ '{print $NF}')

    CUR_DATE=$(echo ${CUR_STUDY} | awk '{print substr($0,6,8)}')

    CUR_FILE_ID=${SUBJ}_${CUR_DATE}

    CUR_DATA_DIR=${CUR_STUDY_DIR}/preprocess

    CUR_BIANCA_DIR=${CUR_STUDY_DIR}/${BIANCA_DIR_NAME}

    echo "Optimizing bianca output for visit "${CUR_STUDY}" for subject "${SUBJ} | tee -a ${LOG_FILE}

    # Extract parts of Flair images tagged by bianca as WMH
    fslmaths ${CUR_TEMP_DIR}/${CUR_FILE_ID}_flairn_t1n_brain_norm.nii.gz -mas ${CUR_BIANCA_DIR}/bianca_output_${CUR_FILE_ID}_T${THR}.nii.gz ${CUR_TEMP_DIR}/${CUR_FILE_ID}_WMH_flair_norm.nii.gz

    # 'Correct' bianca results using Matlab histogram values
    fslmaths ${CUR_TEMP_DIR}/${CUR_FILE_ID}_WMH_flair_norm.nii.gz -thr ${WMH_THR} -bin ${CUR_BIANCA_DIR}/bianca_output_${CUR_FILE_ID}_T${THR}_optimized.nii.gz

    VISIT_COUNT=$((VISIT_COUNT + 1))

  done

  SUBJ_COUNT=$((SUBJ_COUNT + 1))

done < "$SUBJ_LIST_FILE"

echo "optimize_bianca_and_masks.sh complete. "${SUBJ_COUNT}" subjects processed and "${VISIT_COUNT}" optimizations completed." | tee -a ${LOG_FILE}

ELAPSED="Elapsed time: $(($SECONDS / 3600))hrs $((($SECONDS / 60) % 60))min $(($SECONDS % 60))sec"

echo ${ELAPSED} | tee -a ${LOG_FILE} 





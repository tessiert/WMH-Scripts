#!/bin/bash

# ucd_analyze.sh v1.0

# There should only be one compulsory argument
if [ $# != 1 ]; then
   echo "Usage:"
   echo "ucd_analyze.sh <subject_list>"
   echo "Single argument must be the name <subject_list> of a .txt file containing one line for each subject of the form, e.g.,:"
   echo "{Abs_path}/M87104356"
   exit
fi

START_DIR=`pwd`

# Directory containing wmh_detect code from deCarli group
CODE_DIR="/export/mialab/users/ttessier/code/external/wmh_detection"

SUBJ_LIST_FILE=${1}

RESULTS_DIR_NAME="ucd"

# For calculation of total elapsed time
SECONDS=0

TIME_STAMP=`date '+%m%d%Y%H%M%S'`

LOG_FILE=${START_DIR}/ucd_analyze_${TIME_STAMP}.log

echo "Starting UCD WMH segmentation routine..." > ${LOG_FILE}

VISIT_COUNT=0
SUBJ_COUNT=0

while read CUR_SUBJ_DIR
do

  SUBJ=$(echo ${CUR_SUBJ_DIR} | awk -F/ '{print $NF}')

  for CUR_STUDY_DIR in ${CUR_SUBJ_DIR}/Study*
  do

    CUR_STUDY=$(echo ${CUR_STUDY_DIR} | awk -F/ '{print $NF}')

    CUR_DATE=$(echo ${CUR_STUDY} | awk '{print substr($0,6,8)}')

    CUR_FILE_ID=${SUBJ}_${CUR_DATE}

    CUR_DATA_DIR=${CUR_STUDY_DIR}/preprocess

    CUR_RESULTS_DIR=${CUR_STUDY_DIR}/${RESULTS_DIR_NAME}

    # Create output directory
    if [ ! -d ${CUR_RESULTS_DIR} ]; then
      mkdir ${CUR_RESULTS_DIR}
    fi

    CUR_TEMP_DIR=${CUR_STUDY_DIR}/tmp

    # Create temp working directory
    if [ ! -d ${CUR_TEMP_DIR} ]; then
      mkdir ${CUR_TEMP_DIR}
    fi

    # Map T1 brain images from template space to MDT3 (standard space used by IdeaLab software) in order to get the transformations between spaces
    echo "Transforming images for visit ${CUR_STUDY} for subject ${SUBJ} to MDT3 space" | tee -a ${LOG_FILE}

    # Get transform
    flirt -interp spline -in ${CUR_DATA_DIR}/${CUR_FILE_ID}_t1n_brain.nii.gz -ref ${CODE_DIR}/MDT3 -dof 12 -omat ${CUR_TEMP_DIR}/${CUR_FILE_ID}_t1_brain_to_MDT3_lin.mat -out ${CUR_TEMP_DIR}/${CUR_FILE_ID}_t1_brain_to_MDT3_lin

    fnirt --in=${CUR_DATA_DIR}/${CUR_FILE_ID}_t1n_brain.nii.gz --ref=${CODE_DIR}/MDT3 --fout=${CUR_TEMP_DIR}/${CUR_FILE_ID}_t1_brain_to_MDT3_nonlin_field --iout=${CUR_TEMP_DIR}/${CUR_FILE_ID}_t1_brain_to_MDT3_nonlin --cout=${CUR_TEMP_DIR}/${CUR_FILE_ID}_t1_brain_to_MDT3_nonlin_coeff --aff=${CUR_TEMP_DIR}/${CUR_FILE_ID}_t1_brain_to_MDT3_lin.mat

    # Use transform to map Flair to MDT3 space
    applywarp -i ${CUR_DATA_DIR}/${CUR_FILE_ID}_flairn_t1n_brain.nii.gz -r ${CODE_DIR}/MDT3 -w ${CUR_TEMP_DIR}/${CUR_FILE_ID}_t1_brain_to_MDT3_nonlin_coeff -o ${CUR_TEMP_DIR}/${CUR_FILE_ID}_flairn_t1_brain_to_MDT3.nii.gz

    # Unzip the MDT3 Flair image
    gzip -d -f ${CUR_TEMP_DIR}/${CUR_FILE_ID}_flairn_t1_brain_to_MDT3.nii.gz

    # run UCD wmh_detect algorithm
    echo "Running UCD WMH segmentation for visit "${CUR_STUDY}" for subject "${SUBJ} | tee -a ${LOG_FILE}

    # Normalize the input image
    normalizeFlair ${CUR_TEMP_DIR}/${CUR_FILE_ID}_flairn_t1_brain_to_MDT3.nii 100

    # Run UCD WMH detection algorithm
    zScoresMultiplePassArgs ${CUR_TEMP_DIR}/${CUR_FILE_ID}_flairn_t1_brain_to_MDT3_normalized.nii ${CODE_DIR}/WMH_Template.nii ${CODE_DIR}/MDT3_mask.nii ${CODE_DIR}/WMHPercentage_mask.nii ${CODE_DIR}/confileg

    # Invert the above warp and transform wmh_detect results back to median template space
    invwarp -w ${CUR_TEMP_DIR}/${CUR_FILE_ID}_t1_brain_to_MDT3_nonlin_coeff -r ${CUR_DATA_DIR}/${CUR_FILE_ID}_t1n_brain.nii.gz -o ${CUR_TEMP_DIR}/${CUR_FILE_ID}_MDT3_to_t1_brain_nonlin_coeff

    # Map WMH segmentation output (WMH z-score map) back to template space
    applywarp -i ${CUR_TEMP_DIR}/${CUR_FILE_ID}_flairn_t1_brain_to_MDT3_normalized_ZScore.nii -r ${CUR_DATA_DIR}/${CUR_FILE_ID}_t1n_brain.nii.gz -w ${CUR_TEMP_DIR}/${CUR_FILE_ID}_MDT3_to_t1_brain_nonlin_coeff -o ${CUR_RESULTS_DIR}/${CUR_FILE_ID}_UCD_WMH_ZScore_to_template.nii.gz

    # Threshold the z-score map and binarize to get WMH Mask
    fslmaths ${CUR_RESULTS_DIR}/${CUR_FILE_ID}_UCD_WMH_ZScore_to_template.nii.gz -thr 3 -bin ${CUR_RESULTS_DIR}/${CUR_FILE_ID}_UCD_WMH_mask.nii.gz

    VISIT_COUNT=$((VISIT_COUNT + 1))

    rm -r ${CUR_TEMP_DIR}

  done

  SUBJ_COUNT=$((SUBJ_COUNT + 1))

done < "$SUBJ_LIST_FILE"

echo "ucd_analyze.sh complete. "${SUBJ_COUNT}" subjects processed and "${VISIT_COUNT}" visits segmented."  | tee -a ${LOG_FILE}

ELAPSED="Elapsed time: $(($SECONDS / 3600))hrs $((($SECONDS / 60) % 60))min $(($SECONDS % 60))sec"

echo ${ELAPSED} | tee -a ${LOG_FILE} 








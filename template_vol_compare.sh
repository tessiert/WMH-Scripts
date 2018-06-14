#!/bin/bash

START_DIR=`pwd`

TEMPLATE_DIR_NAME="median_template_data"

for CUR_SUBJ_DIR in ${START_DIR}/M[0-9]*[0-9] 
do

  SUBJ=$(echo ${CUR_SUBJ_DIR} | awk -F/ '{print $NF}')

  CUR_OUT_DIR=${CUR_SUBJ_DIR}/${TEMPLATE_DIR_NAME}

  # If median template data exists for the current subject
  if [[ -d ${CUR_OUT_DIR} ]]; then

    for CUR_STUDY_DIR in ${CUR_OUT_DIR}/Study*
    do

      CUR_STUDY=$(echo ${CUR_STUDY_DIR} | awk -F/ '{print $NF}')

      CUR_DATE=$(echo ${CUR_STUDY} | awk '{print substr($0,6,8)}')

      CUR_FILE_ID=${SUBJ}_${CUR_DATE}

      CUR_BIANCA_DIR=${CUR_STUDY_DIR}/bianca

      CUR_UCD_DIR=${CUR_STUDY_DIR}/ucd

      # Record volume statistics
      BIANCA_VOL=$(fslstats ${CUR_BIANCA_DIR}/${CUR_FILE_ID}_bianca_output_to_template_T90_postmasked.nii.gz -V | awk '{print $(NF - 1)}')
      BIANCA_OPT_VOL=$(fslstats ${CUR_BIANCA_DIR}/${CUR_FILE_ID}_bianca_output_to_template_T90_optimized_postmasked.nii.gz -V | awk '{print $(NF - 1)}')
      UCD_VOL=$(fslstats ${CUR_UCD_DIR}/${CUR_FILE_ID}_UCD_WMH_mask.nii.gz -V | awk '{print $(NF - 1)}')
      UCD_MASKED_VOL=$(fslstats ${CUR_UCD_DIR}/${CUR_FILE_ID}_UCD_WMH_mask_optimal_postmasked.nii.gz -V | awk '{print $(NF - 1)}')

      echo ${SUBJ}" "${CUR_DATE}" "${BIANCA_VOL}" "${BIANCA_OPT_VOL}" "${UCD_VOL}" "${UCD_MASKED_VOL} >> ${START_DIR}/bianca_ucd_comparison_stats

    done

  fi

done


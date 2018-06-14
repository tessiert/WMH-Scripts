#!/bin/bash

# median_template.sh v1.0

# If there are any input arguments
if [[ $# != 0 ]] ; then
   echo "Usage:  median_template.sh"
   echo "Script takes no input arguments, and must be run in the directory containing one subdirectory per subject."
   echo "This is typically the first script to be run in the wmh longitudinal pipeline."
   echo "Note:  The master script template_wmh_analyze.sh can be used to automatically run all pipeline scripts in the correct order."
   exit
fi

START_DIR=`pwd`

TEMPLATE_DIR_NAME="median_template_data"

# For calculation of total elapsed time
SECONDS=0

TIME_STAMP=`date '+%m%d%Y%H%M%S'`

LOG_FILE=${START_DIR}/median_template_${TIME_STAMP}.log

echo "Beginning median template creation routine..." > ${LOG_FILE}

TEMPLATE_COUNT=0
SUBJ_COUNT=0

# Loop over each subject directory
for CUR_SUBJ_DIR in ${START_DIR}/M[0-9]*[0-9] 
do

  SUBJ=$(echo ${CUR_SUBJ_DIR} | awk -F/ '{print $NF}')

  CUR_OUT_DIR=${CUR_SUBJ_DIR}/${TEMPLATE_DIR_NAME}

  T1_FILE_LIST=''
  LTA_FILE_LIST=''
  STUDY_COUNT=0

  for CUR_STUDY_DIR in ${CUR_SUBJ_DIR}/Study*
  do

    CUR_DATA_DIR=${CUR_STUDY_DIR}/preprocess

    CUR_STUDY=$(echo ${CUR_STUDY_DIR} | awk -F/ '{print $NF}')

    CUR_DATE=$(echo ${CUR_STUDY} | awk '{print substr($0,6,8)}')

    CUR_FILE_ID=${SUBJ}_${CUR_DATE}

    # If the required files exist
    if [[ -f ${CUR_DATA_DIR}/${CUR_FILE_ID}_t1n_brain.nii.gz && -f ${CUR_DATA_DIR}/${CUR_FILE_ID}_flairn_t1n_brain.nii.gz && -f ${CUR_DATA_DIR}/${CUR_FILE_ID}_t1n.nii.gz && -f ${CUR_DATA_DIR}/${CUR_FILE_ID}_t1n_brain_pve_0.nii.gz ]]; then

      # Create subdirectory structure (creating parents along the way)
      if [ ! -d ${CUR_OUT_DIR}/${CUR_STUDY} ]; then
        mkdir -p ${CUR_OUT_DIR}/${CUR_STUDY}/tmp
      fi

      T1_FILE_LIST=`echo ${T1_FILE_LIST}" "${CUR_DATA_DIR}/${CUR_FILE_ID}_t1n_brain.nii.gz`

      LTA_FILE_LIST=`echo ${LTA_FILE_LIST}' '${CUR_OUT_DIR}/${CUR_STUDY}/${CUR_STUDY}_to_tpl.lta`

      STUDY_COUNT=$((STUDY_COUNT + 1))

    else

      echo "At least one of the required 'preprocess' files is missing.  ${CUR_STUDY} data for subject "${SUBJ}" will not be included in the construction of a longitudinal template." | tee -a ${LOG_FILE}

    fi

  done

  # If there are at least two studies with good longitudinal data
  if [[ ${STUDY_COUNT} -gt 1 ]]; then

    echo "Creating median template from data from "${STUDY_COUNT}" visits for subject ${SUBJ}..." | tee -a ${LOG_FILE}

    # Create the median norm template for $COUNT visits identified above for the current subject
#    mri_robust_template --mov ${T1_FILE_LIST} --template ${CUR_OUT_DIR}/multi_visit_template.nii.gz --lta ${LTA_FILE_LIST} --satit --iscale

    TEMPLATE_COUNT=$((TEMPLATE_COUNT + 1))

    # Loop over studies for current subject again now that we have the median template
    for CUR_STUDY_DIR in ${CUR_SUBJ_DIR}/Study*
    do

      CUR_DATA_DIR=${CUR_STUDY_DIR}/preprocess

      CUR_STUDY=$(echo ${CUR_STUDY_DIR} | awk -F/ '{print $NF}')

      CUR_DATE=$(echo ${CUR_STUDY} | awk '{print substr($0,6,8)}')

      CUR_FILE_ID=${SUBJ}_${CUR_DATE}

      # If the required files exist for the current visit (so that the above processing will have succeeded) convert the images to template space
      if [[ -f ${CUR_DATA_DIR}/${CUR_FILE_ID}_t1n_brain.nii.gz && -f ${CUR_DATA_DIR}/${CUR_FILE_ID}_flairn_t1n_brain.nii.gz && -f ${CUR_DATA_DIR}/${CUR_FILE_ID}_t1n.nii.gz && -f ${CUR_DATA_DIR}/${CUR_FILE_ID}_t1n_brain_pve_0.nii.gz ]]; then

        echo "Registering visit ${CUR_STUDY} images for subject" ${SUBJ} "to median template space..." | tee -a ${LOG_FILE}

#        mri_convert -rl ${CUR_OUT_DIR}/multi_visit_template.nii.gz -at ${CUR_OUT_DIR}/${CUR_STUDY}/${CUR_STUDY}_to_tpl.lta -odt float ${CUR_DATA_DIR}/${CUR_FILE_ID}_t1n_brain.nii.gz ${CUR_OUT_DIR}/${CUR_STUDY}/${CUR_FILE_ID}_t1n_brain_to_template.nii.gz
#        mri_convert -rl ${CUR_OUT_DIR}/multi_visit_template.nii.gz -at ${CUR_OUT_DIR}/${CUR_STUDY}/${CUR_STUDY}_to_tpl.lta -odt float ${CUR_DATA_DIR}/${CUR_FILE_ID}_t1n.nii.gz ${CUR_OUT_DIR}/${CUR_STUDY}/${CUR_FILE_ID}_t1n_to_template.nii.gz
#        mri_convert -rl ${CUR_OUT_DIR}/multi_visit_template.nii.gz -at ${CUR_OUT_DIR}/${CUR_STUDY}/${CUR_STUDY}_to_tpl.lta -odt float ${CUR_DATA_DIR}/${CUR_FILE_ID}_t1n_brain_pve_0.nii.gz ${CUR_OUT_DIR}/${CUR_STUDY}/tmp/${CUR_FILE_ID}_t1n_brain_pve_0_to_template.nii.gz

        # Convert fsl transform from flairn_brain to t1n space to .lta (freesurfer) format
        tkregister2 --noedit --mov ${CUR_DATA_DIR}/${CUR_FILE_ID}_flairn_brain.nii.gz --targ ${CUR_DATA_DIR}/${CUR_FILE_ID}_t1n_brain.nii.gz --fsl ${CUR_DATA_DIR}/xfms/${CUR_FILE_ID}_flairn_t1n.mtx --ltaout ${CUR_OUT_DIR}/${CUR_STUDY}/${CUR_STUDY}_flairn_to_t1n.lta --reg ${CUR_OUT_DIR}/${CUR_STUDY}/tmp/${CUR_STUDY}_flairn_to_t1n.dat
       
        # Concatenate the transform that moves the original flair image to t1n space and the transform from t1n space to template space into a single transform
        mri_concatenate_lta ${CUR_OUT_DIR}/${CUR_STUDY}/${CUR_STUDY}_flairn_to_t1n.lta ${CUR_OUT_DIR}/${CUR_STUDY}/${CUR_STUDY}_to_tpl.lta ${CUR_OUT_DIR}/${CUR_STUDY}/${CUR_STUDY}_to_tpl_concat.lta

        # Transform the original flair to template space in one step (rather than using 'intermediate' flairn_t1n_brain image)
        # Note:  Above transforms are simple one-step transforms because t1n is the native space of all of those images
#Note:  If this becomes the standard, should rename _flairn_t1n_brain_to_template.nii.gz to _flairn_brain_to_template.nii.gz in all scripts in pipeline
        mri_convert -rl ${CUR_OUT_DIR}/multi_visit_template.nii.gz -at ${CUR_OUT_DIR}/${CUR_STUDY}/${CUR_STUDY}_to_tpl_concat.lta -odt float ${CUR_DATA_DIR}/${CUR_FILE_ID}_flairn_brain.nii.gz ${CUR_OUT_DIR}/${CUR_STUDY}/${CUR_FILE_ID}_flairn_t1n_brain_to_template.nii.gz

      fi

    done

  else

    echo "Number of valid visits ("${STUDY_COUNT}") for subject "${SUBJ}" is too few to create a median template.  Proceeding to the next subject." | tee -a ${LOG_FILE}

    # If only one valid visit, clean up unused subdirectory structure created above
    if [[ ${STUDY_COUNT} -eq 1 ]]; then

      rm -r ${CUR_OUT_DIR}

    fi

  fi

  SUBJ_COUNT=$((SUBJ_COUNT + 1))

done

echo "median_template.sh complete. "${SUBJ_COUNT}" subjects processed and "${TEMPLATE_COUNT}" median templates created."  | tee -a ${LOG_FILE}

ELAPSED="Elapsed time: $(($SECONDS / 3600))hrs $((($SECONDS / 60) % 60))min $(($SECONDS % 60))sec"

echo ${ELAPSED} | tee -a ${LOG_FILE} 


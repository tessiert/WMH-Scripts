#!/bin/bash

# template_bianca_wmh.sh v1.0

# If there are any input arguments
if [[ $# != 0 ]] ; then
   echo "Usage:  template_bianca_wmh.sh"
   echo "Script takes no input arguments, and must be run in a directory containing one subdirectory per subject."
   echo "Assumes that median_template.sh and (optionally for postmasking) template_wm_masks.sh have already been run on the subject data."
   echo "Note:  The master script template_wmh_analyze.sh can be used to automatically run all pipeline scripts in the correct order."
   exit
fi

# Threshold % for classifying voxel as WMH
THR=90

# Options passed to bianca
OPTIONSSTR="--selectpts=any --trainingpts=2000 --nonlespts=10000 --patch3D --patchsizes=3 --featuresubset=1,2 --matfeaturenum=4 --spatialweight=1"

START_DIR=`pwd`

TEMPLATE_DIR_NAME="median_template_data"

# Directory containing most up-to-date training masterfile
CODE_DIR="/export/mialab/users/ttessier/code/scripts"

# For calculation of total elapsed time
SECONDS=0

TIME_STAMP=`date '+%m%d%Y%H%M%S'`

LOG_FILE=${START_DIR}/template_bianca_wmh_${TIME_STAMP}.log

echo "Starting Bianca WMH segmentation routine in median template space..." > ${LOG_FILE}

MASK_COUNT=0
SUBJ_COUNT=0

# Loop over each subject directory
for CUR_SUBJ_DIR in ${START_DIR}/M[0-9]*[0-9] 
do

  SUBJ=$(echo ${CUR_SUBJ_DIR} | awk -F/ '{print $NF}')

  CUR_OUT_DIR=${CUR_SUBJ_DIR}/${TEMPLATE_DIR_NAME}

  # If median template data exists for the current subject
  if [[ -d ${CUR_OUT_DIR} ]]; then

    # Working directory (at subject level) for creation of longitudinal masterfile
    LONG_TEMP_DIR=${CUR_OUT_DIR}/tmp

    if [ ! -d ${LONG_TEMP_DIR} ]; then
      mkdir ${LONG_TEMP_DIR}
    fi

    CUR_MASTERFILE=${LONG_TEMP_DIR}/cur_masterfile.txt
    TMP_MASTERFILE=${LONG_TEMP_DIR}/tmp_masterfile.txt

    STUDY_COUNT=0

    # At this level, each 'Study' subdirectory contains image data that has already been mapped to the median template
    for CUR_STUDY_DIR in ${CUR_OUT_DIR}/Study*
    do

      CUR_STUDY=$(echo ${CUR_STUDY_DIR} | awk -F/ '{print $NF}')

      CUR_DATE=$(echo ${CUR_STUDY} | awk '{print substr($0,6,8)}')

      CUR_FILE_ID=${SUBJ}_${CUR_DATE}

      CUR_RESULTS_DIR=${CUR_STUDY_DIR}/bianca

      CUR_TEMP_DIR=${CUR_STUDY_DIR}/tmp

      # Create subdirectory structure
      if [ ! -d ${CUR_RESULTS_DIR} ]; then
        mkdir ${CUR_RESULTS_DIR}
      fi

      # File will have already been created by template_wm_masks if scripts are run in the recommended order (or the master script is used)
      if [[ ! -f ${CUR_TEMP_DIR}/${CUR_FILE_ID}_template_to_MNI_lin.mat ]]; then

        echo "Calling flirt to get transformation from template space to MNI space for visit "${CUR_STUDY}" for subject "${SUBJ} | tee -a ${LOG_FILE}
        # Use flirt to get transformations from template space to MNI space (so that bianca can use spatial information as a feature)
        flirt -interp spline -in ${CUR_STUDY_DIR}/${CUR_FILE_ID}_t1n_to_template.nii.gz -ref $FSLDIR/data/standard/MNI152_T1_2mm -dof 12 -omat ${CUR_TEMP_DIR}/${CUR_FILE_ID}_template_to_MNI_lin.mat -out ${CUR_TEMP_DIR}/${CUR_FILE_ID}_template_to_MNI_lin
      fi

      # If this is the first visit for the current subject
      if [[ ${STUDY_COUNT} -eq 0 ]]; then

        # Prepend the info for the current visit to a (freshly created) masterfile. Being listed as the first entry causes it to be treated as the query subject in the below call to bianca.
        echo ${CUR_STUDY_DIR}/${CUR_FILE_ID}_t1n_brain_to_template.nii.gz ${CUR_STUDY_DIR}/${CUR_FILE_ID}_flairn_t1n_brain_to_template.nii.gz ${CUR_RESULTS_DIR}/${CUR_FILE_ID}_bianca_output_to_template_T${THR}.nii.gz ${CUR_TEMP_DIR}/${CUR_FILE_ID}_template_to_MNI_lin.mat > ${CUR_MASTERFILE}
        cat ${CODE_DIR}/final_training_masterfile.txt >> ${CUR_MASTERFILE}

      else

        # Prepend followup visit info for the current subject to the current masterfile. This pushes previous visit data into lower positions, meaning that all but the first entry (query subject) 
        # will now be used as additional (and longitudinal) training data
        echo ${CUR_STUDY_DIR}/${CUR_FILE_ID}_t1n_brain_to_template.nii.gz ${CUR_STUDY_DIR}/${CUR_FILE_ID}_flairn_t1n_brain_to_template.nii.gz ${CUR_RESULTS_DIR}/${CUR_FILE_ID}_bianca_output_to_template_T${THR}.nii.gz ${CUR_TEMP_DIR}/${CUR_FILE_ID}_template_to_MNI_lin.mat > ${TMP_MASTERFILE}
        cat ${CUR_MASTERFILE} >> ${TMP_MASTERFILE}

        cp ${TMP_MASTERFILE} ${CUR_MASTERFILE}

      fi

      # run bianca algorithm
      echo "Running Bianca WMH segmentation for visit "${CUR_STUDY}" for subject "${SUBJ} | tee -a ${LOG_FILE}

      # Run bianca twice since keeping only voxels flagged as WMH in both passes reduces variability
      bianca --singlefile=${CUR_MASTERFILE} --brainmaskfeaturenum=1 --querysubjectnum=1 --labelfeaturenum=3 --trainingnums=all -o ${CUR_RESULTS_DIR}/${CUR_FILE_ID}_bianca_output_to_template_run_1.nii.gz ${OPTIONSSTR} | tee -a ${LOG_FILE}
      bianca --singlefile=${CUR_MASTERFILE} --brainmaskfeaturenum=1 --querysubjectnum=1 --labelfeaturenum=3 --trainingnums=all -o ${CUR_RESULTS_DIR}/${CUR_FILE_ID}_bianca_output_to_template_run_2.nii.gz ${OPTIONSSTR} | tee -a ${LOG_FILE}

      # Threshold and binarize output
      fslmaths ${CUR_RESULTS_DIR}/${CUR_FILE_ID}_bianca_output_to_template_run_1.nii.gz -thr 0.${THR} -bin ${CUR_TEMP_DIR}/${CUR_FILE_ID}_bianca_output_to_template_run_1_T${THR}.nii.gz 
      fslmaths ${CUR_RESULTS_DIR}/${CUR_FILE_ID}_bianca_output_to_template_run_2.nii.gz -thr 0.${THR} -bin ${CUR_TEMP_DIR}/${CUR_FILE_ID}_bianca_output_to_template_run_2_T${THR}.nii.gz

      # Combine the thresholded run 1 and run 2 data by taking the minimum value at each (binary) voxel, i.e., keep only voxels tagged in both runs in the final output file
      fslmaths ${CUR_TEMP_DIR}/${CUR_FILE_ID}_bianca_output_to_template_run_1_T${THR}.nii.gz -min ${CUR_TEMP_DIR}/${CUR_FILE_ID}_bianca_output_to_template_run_2_T${THR}.nii.gz ${CUR_RESULTS_DIR}/${CUR_FILE_ID}_bianca_output_to_template_T${THR}.nii.gz

      STUDY_COUNT=$((STUDY_COUNT + 1))
      MASK_COUNT=$((MASK_COUNT + 1))

    done

    #rm ${LONG_TEMP_DIR}

  else

    echo "No median template data found for subject "${SUBJ}".  If longitudinal data exists, run median_template.sh first, then run template_bianca_wmh.sh"

  fi

  SUBJ_COUNT=$((SUBJ_COUNT + 1))

done

echo "template_bianca_wmh.sh complete. "${SUBJ_COUNT}" subjects processed and "${MASK_COUNT}" visits segmented."  | tee -a ${LOG_FILE}

ELAPSED="Elapsed time: $(($SECONDS / 3600))hrs $((($SECONDS / 60) % 60))min $(($SECONDS % 60))sec"

echo ${ELAPSED} | tee -a ${LOG_FILE} 








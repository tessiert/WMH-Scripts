#!/bin/bash

# bianca_analyze.sh v.1.2

LONG_MODE=false
BAD_USAGE=false

# If option(s) specified, process them
while [[ $# -gt 1 ]]
do
key="$1"

case $key in
    -l)
    LONG_MODE=true
    shift # past option flag
    ;;
    *)
    echo Error: Unknown option        # unknown option
    BAD_USAGE=true
    shift # past the (invalid) option flag
    ;;
esac
done

# There should only be one compulsory argument remaining
if [[ $# != 1 || "${BAD_USAGE}" == "true" ]] ; then
   echo "Usage:  bianca_analyze.sh [options] [rel. path]<query_subject_masterfile>"
   echo "Options:"
   echo " -l		use longitudinal data for training (adds data for query subject(s) from earlier visits to the training set)"
   echo "Argument must be the name of the bianca 'masterfile' containing the data for the query subjects to be analyzed, i.e., image files (one row per subject) in the following order and adhering to the below naming conventions:"
   echo " "
   echo "1. brain extracted T1 image (used as feature data and for brain mask creation), ex. /{Abs. Path}/M87104302_20130920_t1n_brain.nii.gz"
   echo	"2. brain extracted flair image, ex. /{Abs. Path}/M87104302_20130920_flairn_t1n_brain.nii.gz"
   echo	"3. placeholder_name (required by bianca)"
   echo	"4. Name of linear T1 to MNI transformation matrix (name only needed - script will create file), ex. /{Abs. Path}/bianca/M87104302_20130920_T1_to_MNI_lin.mat"
   echo ""
   echo "NOTE:  make_masterfile.sh can be used to automatically generate the needed masterfile."
   exit
fi

START_DIR=`pwd`

# For calculation of total elapsed time
SECONDS=0

# Threshold % for classifying voxel as WMH
THR=90

TRAINING_MASTERFILE="/export/mialab/users/ttessier/code/scripts/final_training_masterfile.txt"

SUBJ_MASTERFILE=${1}

# Temp working directory and temp files
TIME_STAMP=`date '+%m%d%Y%H%M%S'`
TEMP_DIR=".bianca_analyze_temp_"${TIME_STAMP}
mkdir ${TEMP_DIR}

CUR_MASTERFILE=${TEMP_DIR}/cur_masterfile
# End - define temp resources

CODE_DIR=/export/mialab/users/ttessier/code/scripts

RESULTS_DIR_NAME="bianca"

LESION_FNAME_TAIL="_wmh_t1n.nii.gz"

OPTIONSSTR="--selectpts=noborder --trainingpts=2000 --nonlespts=10000 --patch3D --patchsizes=3 --featuresubset=1,2 --matfeaturenum=4 --spatialweight=1"

END_OF_FILE=0
SUBJECT_NUM=0

# Process each entry in SUBJ_MASTERFILE
while [[ $END_OF_FILE == 0 ]]
do

    read -r CUR_LINE

    # The last exit status is the flag of the end of file
    END_OF_FILE=$?
    if [ $END_OF_FILE != 0 ] ; then
       break;
    fi

    # Prepend the current new subject to a (freshly created) masterfile. Being listed as the first entry causes it to be treated as the query subject in the below call to bianca.
    echo ${CUR_LINE} > ${CUR_MASTERFILE}
    cat ${TRAINING_MASTERFILE} >> ${CUR_MASTERFILE}

    SUBJECT_NUM=$((SUBJECT_NUM + 1))

    SUBJ=$(echo ${CUR_LINE} | awk -F/ '{print $(NF - 3)}')
    STUDY_DIR=$(echo ${CUR_LINE} | awk -F/ '{print $(NF - 2)}')

    SCAN_DATE=$(echo ${STUDY_DIR} | awk '{print substr($0,6,8)}')
    DATA_DIR_NAME=$(echo ${CUR_LINE} | awk -F/ '{print $(NF - 1)}')

    FILE_ID="${SUBJ}_${SCAN_DATE}"

    CUR_SUBJ_DIR=$(echo ${CUR_LINE} | awk -F${STUDY_DIR} '{print $1}')

    DATA_DIR=${CUR_SUBJ_DIR}${STUDY_DIR}/${DATA_DIR_NAME}

    RESULTS_DIR=${CUR_SUBJ_DIR}${STUDY_DIR}/${RESULTS_DIR_NAME}

    LESION_FNAME=${FILE_ID}${LESION_FNAME_TAIL}

    if [ ! -d "$RESULTS_DIR" ]; then

      mkdir ${RESULTS_DIR}

    fi

    BIANCA_LOG=${RESULTS_DIR}/bianca_analyze_new_subj_log

    # Save script call with arguments to log
    echo "Calling bianca_analyze.sh with query subject masterfile: "${SUBJ_MASTERFILE} > ${BIANCA_LOG}

    if [[ "${LONG_MODE}" == "true" ]] ; then
      echo "Option to include longitudinal data in training set enabled - looking for candidate data..." | tee -a ${BIANCA_LOG}
      # Create training data file from any existing longitudinal data for current subject, and append to CUR_MASTERFILE
      for cur_study_dir in ${CUR_SUBJ_DIR}Study*/
      do
        CUR_LONG_SCAN_DATE=$(echo ${cur_study_dir} | awk 'BEGIN {FS="Study"}; {print substr($2,1,8)}')
        CUR_LONG_LESION_FNAME=${cur_study_dir}${DATA_DIR_NAME}/${SUBJ}_${CUR_LONG_SCAN_DATE}${LESION_FNAME_TAIL} 
        CUR_LONG_LIN_MAT_FNAME=${cur_study_dir}${DATA_DIR_NAME}/${SUBJ}_${CUR_LONG_SCAN_DATE}_T1_to_MNI_lin.mat
        CUR_LONG_DATAFILE_HDR=${cur_study_dir}${DATA_DIR_NAME}/${SUBJ}_${CUR_LONG_SCAN_DATE}
        # If the current directory contains data that is older than the data being analyzed, and both (i) a manual WMH mask (or the bianca-generated equivalent) and (ii) a T1 to MNI space linear transform exists, treat it as longitudinal training data for the current subject

# ***Note:  If bianca ever becomes the standard, we'll want to start using the appropriate bianca output as the WMH mask for training (maybe)???

        # If data is older than that being processed 
        if [[ ${CUR_LONG_SCAN_DATE} < ${SCAN_DATE} ]] ; then
          # Make sure the longitudinal data has been processed, i.e., the info needed to use it as training data exists
          if [[ -f ${CUR_LONG_LESION_FNAME} && -f ${CUR_LONG_LIN_MAT_FNAME} ]] ; then 
            echo "Including longitudinal data from date "${CUR_LONG_SCAN_DATE}" in training set" | tee -a ${BIANCA_LOG}
            echo ${CUR_LONG_DATAFILE_HDR}_t1n_brain.nii.gz ${CUR_LONG_DATAFILE_HDR}_flairn_t1n_brain.nii.gz ${CUR_LONG_LESION_FNAME} ${CUR_LONG_LIN_MAT_FNAME} >> ${CUR_MASTERFILE}	
          fi # end - see if longitudinal data has already been processed  
        # Otherwise, stop looking, since any other data would have been collected more recently than that being analyzed
        else
          break;
        fi # end - test for older data
      done # end - for loop
    fi # end - include longitudinal data in training set

    # If they don't already exist (for the current query subject), run flirt to get file (${FILE_ID}_T1_to_MNI_lin.mat) needed by bianca for making use of spatial information
    # and fnirt to get file (${FILE_ID}_MNI_to_T1_nonlin_field.nii.gz) needed by make_bianca_mask
    if [ ! -f ${DATA_DIR}"/"${FILE_ID}"_T1_to_MNI_lin.mat" ]; then
      echo "Computing linear transform to MNI space" | tee -a ${BIANCA_LOG}
      $FSLDIR/bin/flirt -interp spline -in ${DATA_DIR}/${FILE_ID}_t1n.nii.gz -ref $FSLDIR/data/standard/MNI152_T1_2mm -dof 12 \
          -omat ${DATA_DIR}/${FILE_ID}_T1_to_MNI_lin.mat -out ${DATA_DIR}/${FILE_ID}_T1_to_MNI_lin
    else
      echo "Linear transform to MNI space found" | tee -a ${BIANCA_LOG}
    fi

    if [ ! -f ${DATA_DIR}"/"${FILE_ID}"_MNI_to_T1_nonlin_field.nii.gz" ]; then
      echo "Computing nonlinear transform to MNI space (and inverse transform)" | tee -a ${BIANCA_LOG}
      $FSLDIR/bin/fnirt --in=${DATA_DIR}/${FILE_ID}_t1n.nii.gz --ref=$FSLDIR/data/standard/MNI152_T1_2mm --fout=${DATA_DIR}/${FILE_ID}_T1_to_MNI_nonlin_field \
          --cout=${DATA_DIR}/${FILE_ID}_T1_to_MNI_nonlin_coeff --config=$FSLDIR/etc/flirtsch/T1_2_MNI152_2mm.cnf --aff=${DATA_DIR}/${FILE_ID}_T1_to_MNI_lin.mat \
          --refmask=$FSLDIR/data/standard/MNI152_T1_2mm_brain_mask_dil1

      # Invert the nonlinear warp file - output needed by make_bianca_mask
      $FSLDIR/bin/invwarp --ref=${DATA_DIR}/${FILE_ID}_t1n.nii.gz -w ${DATA_DIR}/${FILE_ID}_T1_to_MNI_nonlin_coeff -o ${DATA_DIR}/${FILE_ID}_MNI_to_T1_nonlin_field
    else
      echo "Nonlinear transform to MNI space found" | tee -a ${BIANCA_LOG}
    fi

    echo "Calling bianca with options" ${OPTIONSSTR} | tee -a ${BIANCA_LOG}

    # bianca
    bianca --singlefile=${CUR_MASTERFILE} --brainmaskfeaturenum=1 --querysubjectnum=1 --labelfeaturenum=3 --trainingnums=all \
        -o ${RESULTS_DIR}/bianca_output_${FILE_ID}.nii.gz -v ${OPTIONSSTR}

    echo "Subject ${SUBJ} bianca analysis complete" | tee -a ${BIANCA_LOG}

    # Threshold and binarize output
    fslmaths ${RESULTS_DIR}/bianca_output_${FILE_ID}.nii.gz -thr 0.${THR} -bin ${RESULTS_DIR}/bianca_output_${FILE_ID}_T${THR}.nii.gz 

    echo "Calling make_bianca_mask for subject "${SUBJ} | tee -a ${BIANCA_LOG}

    # make_bianca_mask script must be run locally
    cd ${DATA_DIR}

    # If the CSF pve map isn't there, make it
    if [ ! -f ${FILE_ID}_t1n_brain_pve_0.nii.gz ]; then
      fast -p ${FILE_ID}_t1n_brain
    fi

    # Create the masks (Abs. path forces use of any modifications I make to the script)
    /export/mialab/users/ttessier/fsl/biancaCentos/bin/make_bianca_mask ${FILE_ID}_t1n.nii.gz ${FILE_ID}_t1n_brain_pve_0.nii.gz ${FILE_ID}_MNI_to_T1_nonlin_field.nii.gz

    # Move output files to results directory and return to starting directory
    mv ${FILE_ID}_t1n_bianca_mask.nii.gz ${RESULTS_DIR}/${FILE_ID}_t1n_bianca_mask.nii.gz
    mv ${FILE_ID}_t1n_ventmask.nii.gz ${RESULTS_DIR}/${FILE_ID}_t1n_ventmask.nii.gz
    cd ${START_DIR}

    # Apply the white matter mask
    fslmaths ${RESULTS_DIR}/bianca_output_${FILE_ID}.nii.gz -mas ${RESULTS_DIR}/${FILE_ID}_t1n_bianca_mask.nii.gz ${RESULTS_DIR}/postmasked_bianca_output_${FILE_ID}.nii.gz

    # Threshold postmasked output
    fslmaths ${RESULTS_DIR}/postmasked_bianca_output_${FILE_ID}.nii.gz -thr 0.${THR} -bin ${RESULTS_DIR}/postmasked_bianca_output_${FILE_ID}_T${THR}.nii.gz
    
    if [ -f ${DATA_DIR}"/"${LESION_FNAME} ]; then

      echo "Manual lesion mask found - creating overlap images and calculating overlap measures" | tee -a ${BIANCA_LOG}

      # Create the overlap images

      # unmasked
      fslmaths ${RESULTS_DIR}/bianca_output_${FILE_ID}_T${THR}.nii.gz -mul 2 -add ${DATA_DIR}/${LESION_FNAME} ${RESULTS_DIR}/overlap_img_${FILE_ID}_T${THR}.nii.gz

      # postmasked
      fslmaths ${RESULTS_DIR}/postmasked_bianca_output_${FILE_ID}_T${THR}.nii.gz -mul 2 -add ${DATA_DIR}/${LESION_FNAME} ${RESULTS_DIR}/overlap_img_${FILE_ID}_T${THR}_postmasked.nii.gz

      # Calculate the overlap measures

      # unmasked
      bianca_overlap_measures ${RESULTS_DIR}/bianca_output_${FILE_ID}_T${THR}.nii.gz 0 ${DATA_DIR}/${LESION_FNAME} 1

      # postmasked
      bianca_overlap_measures ${RESULTS_DIR}/postmasked_bianca_output_${FILE_ID}_T${THR}.nii.gz 0 ${DATA_DIR}/${LESION_FNAME} 1

    else

      echo "No manual lesion mask found - skipping overlap analysis for subject" ${SUBJ} | tee -a ${BIANCA_LOG}

    fi

done < "$SUBJ_MASTERFILE"

rm -r ${TEMP_DIR}

echo ${SUBJECT_NUM} "subject(s) analyzed" | tee -a ${BIANCA_LOG}

ELAPSED="Elapsed time: $(($SECONDS / 3600))hrs $((($SECONDS / 60) % 60))min $(($SECONDS % 60))sec"

#echo runtime: $SECONDS seconds | tee -a ${BIANCA_LOG}
echo ${ELAPSED} | tee -a ${BIANCA_LOG}


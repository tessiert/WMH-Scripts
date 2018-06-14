#!/bin/bash

START_DIR=`pwd`

SIGNAL=100

# There should be exactly three compulsory arguments
if [[ $# != 3 ]] ; then
   echo "Usage:  add_sim_noise.sh [rel. path]<input_image>.nii.gz <SNR> [rel. path]<out_dir>"
   echo ""
   echo "Output: Image with Rician noise added at the desired <SNR> level - [rel. path]<out_dir>/<input_image>_SNR_<SNR>.nii.gz"
   echo ""
   echo "Note:   This script requires that both Matlab and the \"Tools for NifTi and ANALYZE IMAGE\" (available from the Matlab file exchange) be installed and accessible via the default search path."
   exit
fi

# Process the arguments
FULL_INPUT_IMAGE=${START_DIR}/${1}

# Strip off '.nii.gz'
INPUT_IMAGE=$(echo ${FULL_INPUT_IMAGE} | awk -F. '{print $(NF - 2)}')

# Get image basename
INPUT_BASENAME=$(echo ${INPUT_IMAGE} | awk -F/ '{print $NF}')

SNR=${2}

RESULTS_DIR=${START_DIR}/${3}

if [ ! -d "$RESULTS_DIR" ]; then

  mkdir ${RESULTS_DIR}

fi

# Create temp working directory
TIME_STAMP=`date '+%m%d%Y%H%M%S'`
TMP_DIR=".add_sim_noise_"${TIME_STAMP}
mkdir ${TMP_DIR}

cp ${FULL_INPUT_IMAGE} ${TMP_DIR}

# Make mask from input image (This will be applied after noise is introduced, to clean up image background)
fslmaths ${FULL_INPUT_IMAGE} -thr 1 -bin ${TMP_DIR}/${INPUT_BASENAME}_mask

# Call Matlab to introduce Rician noise
#******Note: Don't put spaces between arguments, as matlab can't parse them correctly*******
FCN_CALL_STR="add_rician_noise('${TMP_DIR}','${INPUT_BASENAME}',${SIGNAL},${SNR})"
matlab -nodesktop -nosplash -r ${FCN_CALL_STR}

# Smooth final image
fslmaths ${TMP_DIR}/${INPUT_BASENAME}_SNR_${SNR} -kernel gauss 0.6 -fmean ${TMP_DIR}/${INPUT_BASENAME}_SNR_${SNR}

# Apply mask to remove noise from image background
fslmaths ${TMP_DIR}/${INPUT_BASENAME}_SNR_${SNR} -mas ${TMP_DIR}/${INPUT_BASENAME}_mask ${TMP_DIR}/${INPUT_BASENAME}_SNR_${SNR}

cp ${TMP_DIR}/${INPUT_BASENAME}_SNR_${SNR}.nii.gz ${RESULTS_DIR}

rm -r ${TMP_DIR}


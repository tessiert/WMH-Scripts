#!/bin/bash

START_DIR=`pwd`

# There should be exactly five compulsory arguments
if [[ $# != 5 ]] ; then
   echo "Usage:  add_random_rotation.sh <theta> [rel. path]<input_flair_image>.nii.gz [rel. path]<input_T1_image>.nii.gz [rel. path]<out_dir> <out_base_name>"
   echo ""
   echo "Input images are assumed to be in the same space, e.g., <input_flair_image> has already been registered to <input_T1_image>"
   echo ""
   echo "Outputs (saved to <out_dir>):"
   echo "	rotated versions of the input images (both images are rotated about the same - randomly generated - 3D axis by <theta> degrees):  <out_base_name>_flair.nii.gz and <out_base_name>_T1.nii.gz"
   echo "	the fsl-style rotation matrix:  <out_base_name>.mtx"
   echo ""
   exit
fi

# Process the arguments
THETA=${1}
INPUT_FLAIR=${START_DIR}/${2}
INPUT_T1=${START_DIR}/${3}

# Output directory
RESULTS_DIR=${START_DIR}/${4}

if [ ! -d "$RESULTS_DIR" ]; then

  mkdir ${RESULTS_DIR}

fi

OUT_BASENAME=${5}

# Create temp working directory
TIME_STAMP=`date '+%m%d%Y%H%M%S'`
TMP_DIR=".add_random_rotation_"${TIME_STAMP}
mkdir ${TMP_DIR}

AXIS_LIST=""

# Generate arbitrary (unnormalized) 3D axis of rotation
for ((i=1;i<=3;i++));
do
  # Generate a random integer between 1 and 10000 (minimize nonuniform selection effects)
  R_INT=$((RANDOM%10000+1))

  # Divide to get a random number between 0 and 1
  R_NUM=$(bc <<<"scale=3;$R_INT/10000")

  # Generate a random integer taking values 1 or 2
  FLIP=$((RANDOM%2+1))

  # Use above "coin flip" to choose whether to add or subtract from baseline vector coordinate (Uses default starting axis of 1,1,1)
  if [[ ${FLIP} -eq 1 ]]; then

    AXIS_LIST=${AXIS_LIST}' '$(bc <<<"scale=3;1+$R_NUM")

  else

    AXIS_LIST=${AXIS_LIST}' '$(bc <<<"scale=3;1-$R_NUM")

  fi

done

# Rotation axis needs to be input as a comma separated list
read -r A_X A_Y A_Z <<<$(echo ${AXIS_LIST})
AXIS=${A_X},${A_Y},${A_Z}

# Get center of gravity (in voxel coords.) of Flair image to use as rotation center
read -r C_X C_Y C_Z <<<$(fslstats ${INPUT_FLAIR} -C)

# Center of gravity needs to be input as a comma separated list
IMG_CENTER=${C_X},${C_Y},${C_Z}

# Create the rotation matrix
makerot -a ${AXIS} -c ${IMG_CENTER} -o ${RESULTS_DIR}/${OUT_BASENAME}.mtx -t ${THETA}

# Apply rotation to flair and T1 images.  Note: -in and -ref are the same file******
flirt -in ${INPUT_FLAIR} -ref ${INPUT_FLAIR} -applyxfm -init ${RESULTS_DIR}/${OUT_BASENAME}.mtx -out ${RESULTS_DIR}/${OUT_BASENAME}_flair.nii.gz
flirt -in ${INPUT_T1} -ref ${INPUT_T1} -applyxfm -init ${RESULTS_DIR}/${OUT_BASENAME}.mtx -out ${RESULTS_DIR}/${OUT_BASENAME}_T1.nii.gz

# Clean up
rm -r ${TMP_DIR}

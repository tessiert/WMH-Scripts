#!/bin/bash

OUTPUT_TRANS_IMAGES=false

START_DIR=`pwd`

# Test for option flag
if [[ $# -gt 0 ]] ; then

  key="$1"

  case $key in
      -t)
      OUTPUT_TRANS_IMAGES=true
      shift # past option flag
      ;;
  esac

else

   echo "Usage:  make_median_template.sh [options] [rel. path]<image_file_1>.nii.gz ... [rel. path]<image_file_n>.nii.gz [rel. path]<out_dir>"
   echo ""
   echo "Options:"
   echo " -t     Output input images mapped to template space"
   echo ""	
   echo "<image_file_i>.nii.gz - ith single subject MRI image (all input images must be the same modality) to be used to create the longitudinal template"
   echo ""
   echo "<out_dir> - directory that will contain:"
   echo "                the median template - median_template.nii.gz"
   echo "                freesurfer transforms (.lta) to template space, e.g., <image_file_1>_to_tpl.lta"
   echo "                the equivalent FSL transforms to template space, e.g., <image_file_1>_to_tpl.mtx"
   echo "                and, optionally, the input images transformed to template space, e.g., <image_file_1>_to_tpl.nii.gz"
   echo "Note:  Script requires that FreeSurfer and FSL routines be installed and accessible via the default search path."
   exit

fi

# Create temp working directory
TIME_STAMP=`date '+%m%d%Y%H%M%S'`
TMP_DIR=${START_DIR}/".make_median_template_"${TIME_STAMP}
mkdir ${TMP_DIR}

IMAGE_FILE_LIST=""
LTA_FILE_LIST=""
MAPMOV_OPTION="--mapmov"

# Create list of input filenames from which to create template, as well as lists of output transform filenames
while [[ $# -gt 1 ]]
do

  # Process the next argument
  FULL_INPUT_IMAGE=${START_DIR}/${1}

  # Strip off '.nii.gz'
  INPUT_IMAGE=$(echo ${FULL_INPUT_IMAGE} | awk -F. '{print $(NF - 2)}')

  # Get image basename
  INPUT_BASENAME=$(echo ${INPUT_IMAGE} | awk -F/ '{print $NF}')

  # Construct lists of image filenames needed by mri_robust_template
  IMAGE_FILE_LIST=${IMAGE_FILE_LIST}' '${FULL_INPUT_IMAGE}
  LTA_FILE_LIST=${LTA_FILE_LIST}' '${TMP_DIR}/${INPUT_BASENAME}"_to_tpl.lta"

  # Also construct the list of filenames for transformed images, in case user wants them
  MAPMOV_OPTION=${MAPMOV_OPTION}' '${TMP_DIR}/${INPUT_BASENAME}"_to_tpl.nii.gz"

  shift # past current argument
  
done

# If the user did not request output of transformed images, erase the option
if [[ "${OUTPUT_TRANS_IMAGES}" == "false" ]] ; then

  MAPMOV_OPTION=""

fi

# Last remaining argument is the output directory
RESULTS_DIR=${START_DIR}/${1}

if [ ! -d "$RESULTS_DIR" ] ; then

  mkdir ${RESULTS_DIR}

fi

# Create multi_visit template image from simulated images
mri_robust_template --mov ${IMAGE_FILE_LIST} --template ${RESULTS_DIR}/median_template.nii.gz --lta ${LTA_FILE_LIST} --satit --iscale ${MAPMOV_OPTION}

# LTA to FSL conversions
for CUR_LTA in ${TMP_DIR}/*.lta
do

  # Get the input image filename corresponding to the current .lta transform
  CUR_IMAGE=$(echo ${IMAGE_FILE_LIST} | awk '{print $1}')

  # Remove CUR_IMAGE from IMAGE_FILE_LIST (first awk deletes field #1 and second awk removes delimiting space)
  IMAGE_FILE_LIST=$(echo ${IMAGE_FILE_LIST} | awk '{$1=""}1' | awk '{$1=$1}1')

  # Extract the basename of the .lta transform
  LTA_BASENAME=$(echo ${CUR_LTA} | awk -F/ '{print $NF}' | awk -F. '{print $1}')

  # Convert .lta transform to fsl-style (.mtx) transform (Note:  .dat file is required but unused)
  tkregister2 --noedit --mov ${CUR_IMAGE} --targ ${RESULTS_DIR}/median_template.nii.gz --lta ${CUR_LTA} --fslregout ${TMP_DIR}/${LTA_BASENAME}.mtx --reg ${TMP_DIR}/unused.dat

done

# Save secondary output files
cp ${TMP_DIR}/*_to_tpl* ${RESULTS_DIR}

# Clean up
rm -r ${TMP_DIR}


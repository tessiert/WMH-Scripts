#!/bin/bash

START_DIR=`pwd`

ROTATE=false
ADD_NOISE=false
BAD_USAGE=false

# If option(s) specified, process them
while [[ $# -gt 3 ]]
do
key="$1"

case $key in
    -r)
    ROTATE=true
    shift # past option flag
    THETA=${1}
    shift # past argument
    ;;
    -n)
    ADD_NOISE=true
    shift # past option flag
    SNR=${1}
    shift # past argument
    ;;
    *)
    echo Error: Unknown option        # unknown option
    BAD_USAGE=true
    shift # past the (invalid) option flag
    ;;
esac
done

echo $THETA
echo $SNR

# There should be exactly three compulsory arguments remaining
if [[ $# != 3  || "${BAD_USAGE}" == "true" ]] ; then
   echo "Usage:  long_wmh_sim.sh [options] [rel. path]<images_file> [rel. path]<out_dir> <out_base_name>"
   echo ""
   echo "Options:"
   echo " -r <theta>		add a <theta> degree rotation about a randomly generated axis to each image"
   echo " -n <snr>		add Rician noise at the desired <snr> level"
   echo ""
   echo "<images_file> - Two line .txt file (space-separated fields) with the following format:"
   echo "     1st line - <abs. path>/<receiver flair with skull filename>.nii.gz <abs. path>/<receiver T1 with skull filename>.nii.gz <abs. path>/<binary receiver WMH mask>.nii.gz"
   echo "     2nd line - <abs. path>/<donor flair with skull filename>.nii.gz <abs. path>/donor T1 with skull filename>.nii.gz <abs. path>/<binary donor WMH mask>.nii.gz"
   echo ""
   echo "<out_dir> - directory that will contain the simulated (T1 and Flair) images"
   echo ""
   echo "<out_base_name> - base name of output images"
   echo ""
   echo "Note:  Script requires that FSL routines be installed and accessible via the default search path."
   exit
fi

# Get the arguments
IMAGES_FILE=${START_DIR}/${1}

RESULTS_DIR=${START_DIR}/${2}

OUT_BASE_NAME=${3}

if [ ! -d "$RESULTS_DIR" ]; then

  mkdir ${RESULTS_DIR}

fi

TMP_DIR=${RESULTS_DIR}/tmp

if [ ! -d "${TMP_DIR}" ]; then

  mkdir ${TMP_DIR}

fi

NUM_SIM_IMAGES=5

SIGNAL=100

# Extract receiver files (stripping .nii.gz)
RECEIVER_FLAIR=$(sed -n '1p' < ${IMAGES_FILE} | awk '{print $1}' | awk -F. '{print $1}')
RECEIVER_T1=$(sed -n '1p' < ${IMAGES_FILE} | awk '{print $2}' | awk -F. '{print $1}')
RECEIVER_MANUAL_MASK=$(sed -n '1p' < ${IMAGES_FILE} | awk '{print $3}' | awk -F. '{print $1}')

# Extract donor files (stripping .nii.gz)
DONOR_FLAIR=$(sed -n '2p' < ${IMAGES_FILE} | awk '{print $1}' | awk -F. '{print $1}')
DONOR_T1=$(sed -n '2p' < ${IMAGES_FILE} | awk '{print $2}' | awk -F. '{print $1}')
DONOR_MANUAL_MASK=$(sed -n '2p' < ${IMAGES_FILE} | awk '{print $3}' | awk -F. '{print $1}')

# Extract basenames
RECEIVER_FLAIR_BASENAME=$(echo ${RECEIVER_FLAIR} | awk -F/ '{print $NF}')
RECEIVER_T1_BASENAME=$(echo ${RECEIVER_T1} | awk -F/ '{print $NF}')
RECEIVER_MANUAL_MASK_BASENAME=$(echo ${RECEIVER_MANUAL_MASK} | awk -F/ '{print $NF}')
DONOR_FLAIR_BASENAME=$(echo ${DONOR_FLAIR} | awk -F/ '{print $NF}')
DONOR_T1_BASENAME=$(echo ${DONOR_T1} | awk -F/ '{print $NF}')
DONOR_MANUAL_MASK_BASENAME=$(echo ${DONOR_MANUAL_MASK} | awk -F/ '{print $NF}')

# Do brain extraction on T1 images (flirt works better w/ skull stripped)
bet ${RECEIVER_T1} ${TMP_DIR}/${RECEIVER_T1_BASENAME}_brain -f 0.4 -S -B
bet ${DONOR_T1} ${TMP_DIR}/${DONOR_T1_BASENAME}_brain -f 0.4 -S -B

# Use brain masks (from bet above) to get flair_brain images
fslmaths ${RECEIVER_FLAIR} -mas ${TMP_DIR}/${RECEIVER_T1_BASENAME}_brain_mask ${TMP_DIR}/${RECEIVER_FLAIR_BASENAME}_brain
fslmaths ${DONOR_FLAIR} -mas ${TMP_DIR}/${DONOR_T1_BASENAME}_brain_mask ${TMP_DIR}/${DONOR_FLAIR_BASENAME}_brain

# Get linear transform from (high load) donor space (D) to (low load) receiver space (R)
flirt -in ${TMP_DIR}/${DONOR_T1_BASENAME}_brain -ref ${TMP_DIR}/${RECEIVER_T1_BASENAME}_brain -omat ${TMP_DIR}/D_to_R_lin.mat -out ${TMP_DIR}/D_to_R_lin

# Create a WMH exclusion mask for the donor image to pass to fnirt (WMH voxels are zeroed, with 1's elsewhere) and for NAWM extraction below
fslmaths ${DONOR_MANUAL_MASK} -sub 1 -mul -1 ${TMP_DIR}/donor_WMH_exclusion_mask

# fnirt works better with 'unbetted' images
# Though it's also helpful to constrain the fit by supplying a brain mask in the reference space
# Finally, passing donor_WMH_exclusion_mask as the --inmask input keeps fnirt from shrinking the overbright WMH voxels in an attempt to fit data to receiver image
fnirt --in=${DONOR_T1} --inmask=${TMP_DIR}/donor_WMH_exclusion_mask --ref=${RECEIVER_T1} --refmask=${TMP_DIR}/${RECEIVER_T1_BASENAME}_brain_mask --aff=${TMP_DIR}/D_to_R_lin.mat --fout=${TMP_DIR}/D_to_R_nonlin_field --cout=${TMP_DIR}/D_to_R_nonlin_coef --iout=${TMP_DIR}/D_to_R_nonlin

# Run fast to get WM mask (pve_2 treated as a mask below) in receiver space for each structural image
fast -p ${TMP_DIR}/${RECEIVER_T1_BASENAME}_brain
fast -p ${TMP_DIR}/${DONOR_T1_BASENAME}_brain

# Create WMH exclusion mask for NAWM extraction from receiver image
fslmaths ${RECEIVER_MANUAL_MASK} -sub 1 -mul -1 ${TMP_DIR}/receiver_WMH_exclusion_mask

# Extract NAWM from receiver and donor flair_brain images (first mask to exclude WMHs, then mask to extract remaining WM)
fslmaths ${TMP_DIR}/${RECEIVER_FLAIR_BASENAME}_brain -mas ${TMP_DIR}/receiver_WMH_exclusion_mask -mas ${TMP_DIR}/${RECEIVER_FLAIR_BASENAME}_brain_pve_2 ${TMP_DIR}/receiver_NAWM
fslmaths ${TMP_DIR}/${DONOR_FLAIR_BASENAME}_brain -mas ${TMP_DIR}/donor_WMH_exclusion_mask -mas ${TMP_DIR}/${DONOR_FLAIR_BASENAME}_brain_pve_2 ${TMP_DIR}/donor_NAWM

# Find medians of NAWM
MEDIAN_R=$(fslstats ${TMP_DIR}/receiver_NAWM -P 50)
MEDIAN_D=$(fslstats ${TMP_DIR}/donor_NAWM -P 50)

# Use medians to normalize full Flair images to ${SIGNAL}
fslmaths ${TMP_DIR}/${RECEIVER_FLAIR_BASENAME}_brain -div ${MEDIAN_R} -mul ${SIGNAL} ${TMP_DIR}/${RECEIVER_FLAIR_BASENAME}_brain
fslmaths ${TMP_DIR}/${DONOR_FLAIR_BASENAME}_brain -div ${MEDIAN_D} -mul ${SIGNAL} ${TMP_DIR}/${DONOR_FLAIR_BASENAME}_brain

# Map donor mask and images to receiver space
applywarp -i ${DONOR_MANUAL_MASK} -r ${RECEIVER_T1} -w ${TMP_DIR}/D_to_R_nonlin_coef -o ${TMP_DIR}/donor_WMH_mask_in_receiver_space
applywarp -i ${TMP_DIR}/${DONOR_FLAIR_BASENAME}_brain -r ${RECEIVER_T1} -w ${TMP_DIR}/D_to_R_nonlin_coef -o ${TMP_DIR}/${DONOR_FLAIR_BASENAME}_brain_in_receiver_space
applywarp -i ${TMP_DIR}/${DONOR_T1_BASENAME}_brain -r ${RECEIVER_T1} -w ${TMP_DIR}/D_to_R_nonlin_coef -o ${TMP_DIR}/${DONOR_T1_BASENAME}_brain_in_receiver_space

# Threshold to adjust for spreading due to warp
fslmaths ${TMP_DIR}/donor_WMH_mask_in_receiver_space -thr 0.5 -bin ${TMP_DIR}/donor_WMH_mask_in_receiver_space

# Create mask of donor WMHs constrained to fall within WM of receiver image
fslmaths ${TMP_DIR}/donor_WMH_mask_in_receiver_space -mas ${TMP_DIR}/${RECEIVER_FLAIR_BASENAME}_brain_pve_2 -bin ${TMP_DIR}/donor_WMH_mask_in_receiver_space_WM

# Create the simulated images (Flair_brain and T1_brain)
for ((i=${NUM_SIM_IMAGES};i>=1;i--));
do

  # Erosion factor used to reduce size of WMH mask
  ERODE_FAC=$(bc <<<"scale=1;0.75+0.25*$i")

  # WMH size reduction (treating reduced WMH images as earlier visits allows simulation of growth)
  fslmaths ${TMP_DIR}/donor_WMH_mask_in_receiver_space_WM -kernel gauss ${ERODE_FAC} -ero ${TMP_DIR}/donor_WMH_mask_in_receiver_space_WM_${ERODE_FAC}

  # Extract WMH voxels from donor images
  fslmaths ${TMP_DIR}/${DONOR_FLAIR_BASENAME}_brain_in_receiver_space -mas ${TMP_DIR}/donor_WMH_mask_in_receiver_space_WM_${ERODE_FAC} ${TMP_DIR}/${DONOR_FLAIR_BASENAME}_extracted_WMH_in_WM_${ERODE_FAC}
  fslmaths ${TMP_DIR}/${DONOR_T1_BASENAME}_brain_in_receiver_space -mas ${TMP_DIR}/donor_WMH_mask_in_receiver_space_WM_${ERODE_FAC} ${TMP_DIR}/${DONOR_T1_BASENAME}_extracted_WMH_in_WM_${ERODE_FAC}

  # Create donor WMH_exclusion_mask constrained to fall in WM of receiver image
  fslmaths ${TMP_DIR}/donor_WMH_mask_in_receiver_space_WM_${ERODE_FAC} -sub 1 -mul -1 ${TMP_DIR}/WMH_exclusion_mask_in_receiver_space_WM_${ERODE_FAC}.nii.gz

  # Zero voxels in receiver images tagged as WMH in donor flair_brain
  fslmaths ${TMP_DIR}/${RECEIVER_FLAIR_BASENAME}_brain -mas ${TMP_DIR}/WMH_exclusion_mask_in_receiver_space_WM_${ERODE_FAC} ${TMP_DIR}/${RECEIVER_FLAIR_BASENAME}_brain_blanked_${ERODE_FAC}
  fslmaths ${TMP_DIR}/${RECEIVER_T1_BASENAME}_brain -mas ${TMP_DIR}/WMH_exclusion_mask_in_receiver_space_WM_${ERODE_FAC} ${TMP_DIR}/${RECEIVER_T1_BASENAME}_brain_blanked_${ERODE_FAC}

  # Add extracted to voxels zeroed receiver images to import WMH voxels
  fslmaths ${TMP_DIR}/${RECEIVER_FLAIR_BASENAME}_brain_blanked_${ERODE_FAC} -add ${TMP_DIR}/${DONOR_FLAIR_BASENAME}_extracted_WMH_in_WM_${ERODE_FAC} ${TMP_DIR}/raw_sim_image_${ERODE_FAC}
  fslmaths ${TMP_DIR}/${RECEIVER_T1_BASENAME}_brain_blanked_${ERODE_FAC} -add ${TMP_DIR}/${DONOR_T1_BASENAME}_extracted_WMH_in_WM_${ERODE_FAC} ${TMP_DIR}/raw_sim_image_T1_${ERODE_FAC}

  # Create WMH mask for simulated images
  fslmaths ${TMP_DIR}/donor_WMH_mask_in_receiver_space_WM_${ERODE_FAC} -add ${RECEIVER_MANUAL_MASK} -bin ${TMP_DIR}/sim_image_mask_${ERODE_FAC}

  # Dilate donor WMH mask by one voxel in all planar directions
  fslmaths ${TMP_DIR}/donor_WMH_mask_in_receiver_space_WM_${ERODE_FAC} -kernel 2D -dilM -bin ${TMP_DIR}/donor_WMH_mask_in_receiver_space_WM_dilated_${ERODE_FAC}

  # Sutract original WMH mask to create WMH outline mask - identifies lesion boundaries
  fslmaths ${TMP_DIR}/donor_WMH_mask_in_receiver_space_WM_dilated_${ERODE_FAC} -sub ${TMP_DIR}/donor_WMH_mask_in_receiver_space_WM_${ERODE_FAC} ${TMP_DIR}/WMH_outline_mask_${ERODE_FAC} 

  # Dilate WMH_outline_mask by one voxel in all planar directions
  fslmaths ${TMP_DIR}/WMH_outline_mask_${ERODE_FAC} -kernel 2D -dilM -bin ${TMP_DIR}/WMH_outline_mask_dilated_${ERODE_FAC}

  # Use dilated WMH outline mask to extract corresponding voxels in raw_sim_images
  fslmaths ${TMP_DIR}/raw_sim_image_${ERODE_FAC} -mas ${TMP_DIR}/WMH_outline_mask_dilated_${ERODE_FAC} ${TMP_DIR}/raw_WMH_edge_voxels_dilated_${ERODE_FAC}
  fslmaths ${TMP_DIR}/raw_sim_image_T1_${ERODE_FAC} -mas ${TMP_DIR}/WMH_outline_mask_dilated_${ERODE_FAC} ${TMP_DIR}/raw_WMH_edge_voxels_dilated_T1_${ERODE_FAC}

  # Smooth voxels in proximity to inserted WMH lesion edges
  fslmaths ${TMP_DIR}/raw_WMH_edge_voxels_dilated_${ERODE_FAC} -kernel 2D -fmean ${TMP_DIR}/smoothed_WMH_edge_voxels_dilated_${ERODE_FAC}
  fslmaths ${TMP_DIR}/raw_WMH_edge_voxels_dilated_T1_${ERODE_FAC} -kernel 2D -fmean ${TMP_DIR}/smoothed_WMH_edge_voxels_dilated_T1_${ERODE_FAC}

  # Use undilated WMH outline mask to extract corresponding voxels in raw_sim_images
  fslmaths ${TMP_DIR}/raw_sim_image_${ERODE_FAC} -mas ${TMP_DIR}/WMH_outline_mask_${ERODE_FAC} ${TMP_DIR}/raw_WMH_edge_voxels_${ERODE_FAC}
  fslmaths ${TMP_DIR}/raw_sim_image_T1_${ERODE_FAC} -mas ${TMP_DIR}/WMH_outline_mask_${ERODE_FAC} ${TMP_DIR}/raw_WMH_edge_voxels_T1_${ERODE_FAC}

  # Zero the region corresponding to the edge voxels in raw_sim_images
  fslmaths ${TMP_DIR}/raw_sim_image_${ERODE_FAC} -sub ${TMP_DIR}/raw_WMH_edge_voxels_${ERODE_FAC} ${TMP_DIR}/raw_sim_image_blanked_${ERODE_FAC}
  fslmaths ${TMP_DIR}/raw_sim_image_T1_${ERODE_FAC} -sub ${TMP_DIR}/raw_WMH_edge_voxels_T1_${ERODE_FAC} ${TMP_DIR}/raw_sim_image_blanked_T1_${ERODE_FAC}

  # Extract the smoothed edge voxels (this is done because edges of 'smoothed_WMH_edge_voxels_dilated' are averaged with a zero background)
  fslmaths ${TMP_DIR}/smoothed_WMH_edge_voxels_dilated_${ERODE_FAC} -mas ${TMP_DIR}/WMH_outline_mask_${ERODE_FAC} ${TMP_DIR}/smoothed_WMH_edge_voxels_${ERODE_FAC}
  fslmaths ${TMP_DIR}/smoothed_WMH_edge_voxels_dilated_T1_${ERODE_FAC} -mas ${TMP_DIR}/WMH_outline_mask_${ERODE_FAC} ${TMP_DIR}/smoothed_WMH_edge_voxels_T1_${ERODE_FAC}

  # Replace with smoothed edge voxels
  fslmaths ${TMP_DIR}/raw_sim_image_blanked_${ERODE_FAC} -add ${TMP_DIR}/smoothed_WMH_edge_voxels_${ERODE_FAC} ${TMP_DIR}/smoothed_sim_image_${ERODE_FAC}
  fslmaths ${TMP_DIR}/raw_sim_image_blanked_T1_${ERODE_FAC} -add ${TMP_DIR}/smoothed_WMH_edge_voxels_T1_${ERODE_FAC} ${TMP_DIR}/smoothed_sim_image_T1_${ERODE_FAC}

  let "VISIT_NUM=${NUM_SIM_IMAGES}-${i}+1"

  if [[ "${ROTATE}" == "true" ]] ; then
  
    add_random_rotation ${THETA} 

  # Save the final images
  cp ${TMP_DIR}/smoothed_sim_image_${ERODE_FAC}.nii.gz ${RESULTS_DIR}/${OUT_BASE_NAME}_flair_v${VISIT_NUM}.nii.gz
  cp ${TMP_DIR}/smoothed_sim_image_T1_${ERODE_FAC}.nii.gz ${RESULTS_DIR}/${OUT_BASE_NAME}_T1_v${VISIT_NUM}.nii.gz

  # Also save the corresponding WMH mask
  cp ${TMP_DIR}/sim_image_mask_${ERODE_FAC}.nii.gz ${RESULTS_DIR}/${OUT_BASE_NAME}_mask_v${VISIT_NUM}.nii.gz

  TOTAL_VOL=$(fslstats ${RESULTS_DIR}/${OUT_BASE_NAME}_mask_v${VISIT_NUM}.nii.gz -V | awk '{print $(NF - 1)}')

  # Construct list of simulated WMH volumes
  echo ${OUT_BASE_NAME}_v${VISIT_NUM}.nii.gz" WMH volume = "${TOTAL_VOL} >> ${RESULTS_DIR}/sim_image_WMH_volumes.txt

done

rm -r ${TMP_DIR}




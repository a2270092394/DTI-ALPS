#!/bin/bash
# =============================================================================
# DTI-ALPS Index Calculation Pipeline
# =============================================================================
# Description: Calculates DTI-ALPS index as a proxy for subcortical fluid dynamics
# Reference: [Your Article Citation]
# Requirements: FSL (https://fsl.fmrib.ox.ac.uk)
# =============================================================================

set -e  # Stop execution on error

# -----------------------------------------------------------------------------
# User Configuration (modify as needed)
# -----------------------------------------------------------------------------

FSLDIR=${FSLDIR:-/usr/local/fsl}  # FSL installation directory
THRESHOLD=0.5                       # Probability threshold for ROI binarization
SCALE=6                             # Decimal places for calculations

# -----------------------------------------------------------------------------
# Check prerequisites
# -----------------------------------------------------------------------------

echo "=========================================="
echo "DTI-ALPS Calculation Pipeline"
echo "=========================================="

# Check if FSL is available
if [ ! -f ${FSLDIR}/etc/fslconf/fsl.sh ]; then
    echo "ERROR: FSL not found at ${FSLDIR}"
    echo "Please set FSLDIR environment variable correctly"
    exit 1
fi
source ${FSLDIR}/etc/fslconf/fsl.sh

# Check input files
required_files=("DTI.nii.gz" "DTI.bvec" "DTI.bval")
for file in "${required_files[@]}"; do
    if [ ! -f "$file" ]; then
        echo "ERROR: Required file not found: $file"
        exit 1
    fi
done

# Check ROI files
roi_files=("LeftProjROI.nii.gz" "LeftAssoROI.nii.gz" 
           "RightProjROI.nii.gz" "RightAssoROI.nii.gz")
missing_rois=()
for roi in "${roi_files[@]}"; do
    if [ ! -f "$roi" ]; then
        missing_rois+=("$roi")
    fi
done
if [ ${#missing_rois[@]} -gt 0 ]; then
    echo "WARNING: The following ROI files are missing:"
    printf '  - %s\n' "${missing_rois[@]}"
    echo "Please ensure ROI files are in the current directory"
    read -p "Continue? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "All prerequisites satisfied"
echo

# -----------------------------------------------------------------------------
# Step 1: Extract b0 and brain extraction
# -----------------------------------------------------------------------------
echo "Step 1: Extracting b0 and performing brain extraction..."
fslroi DTI.nii.gz b0 0 1
bet b0.nii.gz b0_brain.nii.gz -f 0.2 -g 0 -m
echo "  ✓ Complete"
echo

# -----------------------------------------------------------------------------
# Step 2: Eddy current and motion correction
# -----------------------------------------------------------------------------
echo "Step 2: Applying eddy current and motion correction..."
eddy_correct DTI.nii.gz DTI_eddy.nii.gz 0
fdt_rotate_bvecs DTI.bvec DTI_eddy.bvec DTI_eddy.ecclog
echo "  ✓ Complete"
echo

# -----------------------------------------------------------------------------
# Step 3: Diffusion tensor fitting
# -----------------------------------------------------------------------------
echo "Step 3: Fitting diffusion tensors..."
dtifit \
    -k DTI_eddy.nii.gz \
    -o dti \
    -m b0_brain_mask.nii.gz \
    -r DTI_eddy.bvec \
    -b DTI.bval
echo "  ✓ Complete"
echo

# -----------------------------------------------------------------------------
# Step 4: Split tensor into directional diffusivity maps
# -----------------------------------------------------------------------------
echo "Step 4: Generating Dx, Dy, Dz diffusivity maps..."
fslsplit dti_tensor.nii.gz tensor_ -t
cp tensor_0000.nii.gz Dx.nii.gz
cp tensor_0003.nii.gz Dy.nii.gz
cp tensor_0005.nii.gz Dz.nii.gz
echo "  ✓ Complete (Dx, Dy, Dz created)"
echo

# -----------------------------------------------------------------------------
# Step 5: Register FA to MNI space
# -----------------------------------------------------------------------------
echo "Step 5: Registering FA map to MNI space..."
flirt \
    -in dti_FA.nii.gz \
    -ref ${FSLDIR}/data/standard/FMRIB58_FA_1mm.nii.gz \
    -omat FA2MNI.mat
fnirt \
    --in=dti_FA.nii.gz \
    --aff=FA2MNI.mat \
    --cout=FA2MNI_warp \
    --config=FA_2_FMRIB58_1mm.cnf
echo "  ✓ Complete"
echo

# -----------------------------------------------------------------------------
# Step 6: Warp ROI maps to MNI space and binarize
# -----------------------------------------------------------------------------
echo "Step 6: Warping ROIs to MNI space and binarizing..."
for roi in LeftProjROI LeftAssoROI RightProjROI RightAssoROI; do
    if [ -f "${roi}.nii.gz" ]; then
        applywarp \
            -i ${roi}.nii.gz \
            -r ${FSLDIR}/data/standard/FMRIB58_FA_1mm.nii.gz \
            -w FA2MNI_warp \
            -o ${roi}_MNI_prob.nii.gz
        fslmaths ${roi}_MNI_prob.nii.gz \
            -thr ${THRESHOLD} \
            -bin ${roi}_MNI.nii.gz
        echo "  ✓ ${roi}"
    else
        echo "  ✗ ${roi} not found - skipping"
    fi
done
echo

# -----------------------------------------------------------------------------
# Step 7: Warp diffusivity maps to MNI space
# -----------------------------------------------------------------------------
echo "Step 7: Warping diffusivity maps to MNI space..."
for map in Dx Dy Dz dti_FA; do
    if [ -f "${map}.nii.gz" ]; then
        applywarp \
            -i ${map}.nii.gz \
            -r ${FSLDIR}/data/standard/FMRIB58_FA_1mm.nii.gz \
            -w FA2MNI_warp \
            -o ${map}_MNI.nii.gz
        echo "  ✓ ${map}"
    fi
done
echo

# -----------------------------------------------------------------------------
# Step 8: Extract diffusivity values from ROIs
# -----------------------------------------------------------------------------
echo "Step 8: Extracting diffusivity values..."

# Check if ROI files exist before extraction
extract_values() {
    local roi=$1
    local hemis=$2
    if [ -f "${roi}_MNI.nii.gz" ]; then
        fslmeants -i ${3} -m ${roi}_MNI.nii.gz 2>/dev/null
    else
        echo "ERROR"
    fi
}

# Left hemisphere
if [ -f "LeftProjROI_MNI.nii.gz" ] && [ -f "LeftAssoROI_MNI.nii.gz" ]; then
    Dxproj_L=$(fslmeants -i Dx_MNI.nii.gz -m LeftProjROI_MNI.nii.gz 2>/dev/null)
    Dyproj_L=$(fslmeants -i Dy_MNI.nii.gz -m LeftProjROI_MNI.nii.gz 2>/dev/null)
    Dzproj_L=$(fslmeants -i Dz_MNI.nii.gz -m LeftProjROI_MNI.nii.gz 2>/dev/null)
    Dxasso_L=$(fslmeants -i Dx_MNI.nii.gz -m LeftAssoROI_MNI.nii.gz 2>/dev/null)
    Dyasso_L=$(fslmeants -i Dy_MNI.nii.gz -m LeftAssoROI_MNI.nii.gz 2>/dev/null)
    Dzasso_L=$(fslmeants -i Dz_MNI.nii.gz -m LeftAssoROI_MNI.nii.gz 2>/dev/null)
    echo "  ✓ Left hemisphere values extracted"
else
    echo "  ✗ Left hemisphere ROIs missing"
    Dxproj_L=Dyproj_L=Dzproj_L=Dxasso_L=Dyasso_L=Dzasso_L="ERROR"
fi

# Right hemisphere
if [ -f "RightProjROI_MNI.nii.gz" ] && [ -f "RightAssoROI_MNI.nii.gz" ]; then
    Dxproj_R=$(fslmeants -i Dx_MNI.nii.gz -m RightProjROI_MNI.nii.gz 2>/dev/null)
    Dyproj_R=$(fslmeants -i Dy_MNI.nii.gz -m RightProjROI_MNI.nii.gz 2>/dev/null)
    Dzproj_R=$(fslmeants -i Dz_MNI.nii.gz -m RightProjROI_MNI.nii.gz 2>/dev/null)
    Dxasso_R=$(fslmeants -i Dx_MNI.nii.gz -m RightAssoROI_MNI.nii.gz 2>/dev/null)
    Dyasso_R=$(fslmeants -i Dy_MNI.nii.gz -m RightAssoROI_MNI.nii.gz 2>/dev/null)
    Dzasso_R=$(fslmeants -i Dz_MNI.nii.gz -m RightAssoROI_MNI.nii.gz 2>/dev/null)
    echo "  ✓ Right hemisphere values extracted"
else
    echo "  ✗ Right hemisphere ROIs missing"
    Dxproj_R=Dyproj_R=Dzproj_R=Dxasso_R=Dyasso_R=Dzasso_R="ERROR"
fi
echo

# -----------------------------------------------------------------------------
# Step 9: Calculate DTI-ALPS indices
# -----------------------------------------------------------------------------
echo "Step 9: Calculating DTI-ALPS indices..."

# ALPS calculation function
calc_alps() {
    local Dxproj=$1
    local Dxasso=$2
    local Dyproj=$3
    local Dzasso=$4
    echo "scale=${SCALE}; ($Dxproj + $Dxasso) / ($Dyproj + $Dzasso)" | bc 2>/dev/null
}

if [[ "$Dxproj_L" != "ERROR" ]] && [[ "$Dxasso_L" != "ERROR" ]] && \
   [[ "$Dyproj_L" != "ERROR" ]] && [[ "$Dzasso_L" != "ERROR" ]]; then
    ALPS_L=$(calc_alps "$Dxproj_L" "$Dxasso_L" "$Dyproj_L" "$Dzasso_L")
    echo "  ✓ Left ALPS = ${ALPS_L}"
else
    ALPS_L="ERROR"
    echo "  ✗ Left ALPS calculation failed"
fi

if [[ "$Dxproj_R" != "ERROR" ]] && [[ "$Dxasso_R" != "ERROR" ]] && \
   [[ "$Dyproj_R" != "ERROR" ]] && [[ "$Dzasso_R" != "ERROR" ]]; then
    ALPS_R=$(calc_alps "$Dxproj_R" "$Dxasso_R" "$Dyproj_R" "$Dzasso_R")
    echo "  ✓ Right ALPS = ${ALPS_R}"
else
    ALPS_R="ERROR"
    echo "  ✗ Right ALPS calculation failed"
fi

if [[ "$ALPS_L" != "ERROR" ]] && [[ "$ALPS_R" != "ERROR" ]]; then
    ALPS_Final=$(echo "scale=${SCALE}; ($ALPS_L + $ALPS_R) / 2" | bc)
    echo "  ✓ Final ALPS = ${ALPS_Final}"
else
    ALPS_Final="ERROR"
    echo "  ✗ Final ALPS calculation failed"
fi
echo

# -----------------------------------------------------------------------------
# Step 10: Save results to CSV
# -----------------------------------------------------------------------------
echo "Step 10: Saving results..."

# Create header
echo "Dxproj_L,Dyproj_L,Dzproj_L,Dxasso_L,Dyasso_L,Dzasso_L,ALPS_L,Dxproj_R,Dyproj_R,Dzproj_R,Dxasso_R,Dyasso_R,Dzasso_R,ALPS_R,ALPS_Final" > DTI_ALPS_results.csv

# Write data row
echo "${Dxproj_L},${Dyproj_L},${Dzproj_L},${Dxasso_L},${Dyasso_L},${Dzasso_L},${ALPS_L},${Dxproj_R},${Dyproj_R},${Dzproj_R},${Dxasso_R},${Dyasso_R},${Dzasso_R},${ALPS_R},${ALPS_Final}" >> DTI_ALPS_results.csv

echo "  ✓ Results saved to DTI_ALPS_results.csv"
echo

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo "=========================================="
echo "Pipeline Complete!"
echo "=========================================="
echo "Output file: DTI_ALPS_results.csv"
echo
echo "Results preview:"
head -n 2 DTI_ALPS_results.csv | column -t -s,
echo
echo "=========================================="

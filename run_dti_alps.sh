#!/bin/bash
# ============================================================
# DTI-ALPS calculation using template-based ROIs and ANTs SyN
# ============================================================

set -e

# -----------------------------
# User settings
# -----------------------------

SUBJECT_DIR=$1
TEMPLATE_FA="/mnt/d/DTI_ALPS/template/FSL_HCP1065_FA_1mm.nii.gz"
ROI_DIR="/mnt/d/DTI_ALPS/ROI"
OUT_DIR="${SUBJECT_DIR}/DTI_ALPS"

mkdir -p "${OUT_DIR}"

cd "${SUBJECT_DIR}"

# -----------------------------
# Input files
# -----------------------------

DWI="DWI.nii.gz"
BVAL="DWI.bval"
BVEC="DWI.bvec"

if [ ! -f "$DWI" ] || [ ! -f "$BVAL" ] || [ ! -f "$BVEC" ]; then
    echo "ERROR: Missing DWI.nii.gz / DWI.bval / DWI.bvec in ${SUBJECT_DIR}"
    exit 1
fi

# -----------------------------
# Step 1. Extract b0 and brain mask
# -----------------------------

echo "Step 1: Brain extraction"

fslroi ${DWI} ${OUT_DIR}/b0.nii.gz 0 1
bet ${OUT_DIR}/b0.nii.gz ${OUT_DIR}/b0_brain.nii.gz -f 0.2 -m

# -----------------------------
# Step 2. Eddy correction
# -----------------------------

echo "Step 2: Eddy-current correction"

eddy_correct ${DWI} ${OUT_DIR}/DWI_eddy.nii.gz 0
fdt_rotate_bvecs ${BVEC} ${OUT_DIR}/DWI_eddy.bvec ${OUT_DIR}/DWI_eddy.ecclog

# -----------------------------
# Step 3. Tensor fitting
# -----------------------------

echo "Step 3: Tensor fitting"

dtifit \
    -k ${OUT_DIR}/DWI_eddy.nii.gz \
    -o ${OUT_DIR}/dti \
    -m ${OUT_DIR}/b0_brain_mask.nii.gz \
    -r ${OUT_DIR}/DWI_eddy.bvec \
    -b ${BVAL}

# Output:
# dti_FA.nii.gz
# dti_MD.nii.gz
# dti_tensor.nii.gz

# -----------------------------
# Step 4. Extract Dx, Dy, Dz
# -----------------------------
# FSL tensor order is usually:
# 0 = Dxx, 1 = Dxy, 2 = Dxz, 3 = Dyy, 4 = Dyz, 5 = Dzz

echo "Step 4: Extract Dx, Dy, Dz"

fslsplit ${OUT_DIR}/dti_tensor.nii.gz ${OUT_DIR}/tensor_ -t

cp ${OUT_DIR}/tensor_0000.nii.gz ${OUT_DIR}/Dx.nii.gz
cp ${OUT_DIR}/tensor_0003.nii.gz ${OUT_DIR}/Dy.nii.gz
cp ${OUT_DIR}/tensor_0005.nii.gz ${OUT_DIR}/Dz.nii.gz

# -----------------------------
# Step 5. ANTs SyN registration
# -----------------------------

echo "Step 5: Register FA to HCP1065 FA template using ANTs SyN"

antsRegistrationSyN.sh \
    -d 3 \
    -f ${TEMPLATE_FA} \
    -m ${OUT_DIR}/dti_FA.nii.gz \
    -o ${OUT_DIR}/FA2HCP_ \
    -t s

# Main outputs:
# FA2HCP_0GenericAffine.mat
# FA2HCP_1Warp.nii.gz
# FA2HCP_Warped.nii.gz

# -----------------------------
# Step 6. Apply transform to Dx/Dy/Dz/FA
# -----------------------------

echo "Step 6: Warp diffusivity maps to HCP1065 template space"

for MAP in Dx Dy Dz dti_FA; do
    antsApplyTransforms \
        -d 3 \
        -i ${OUT_DIR}/${MAP}.nii.gz \
        -r ${TEMPLATE_FA} \
        -o ${OUT_DIR}/${MAP}_HCP.nii.gz \
        -t ${OUT_DIR}/FA2HCP_1Warp.nii.gz \
        -t ${OUT_DIR}/FA2HCP_0GenericAffine.mat \
        -n Linear
done

# -----------------------------
# Step 7. Extract ROI values
# -----------------------------

echo "Step 7: Extract diffusivity values from predefined ROIs"

# Required ROI names:
# Prj_L_r3mm.nii.gz
# Ass_L_r3mm.nii.gz
# Prj_R_r3mm.nii.gz
# Ass_R_r3mm.nii.gz

Dxproj_L=$(fslmeants -i ${OUT_DIR}/Dx_HCP.nii.gz -m ${ROI_DIR}/Prj_L_r3mm.nii.gz)
Dyproj_L=$(fslmeants -i ${OUT_DIR}/Dy_HCP.nii.gz -m ${ROI_DIR}/Prj_L_r3mm.nii.gz)
Dzproj_L=$(fslmeants -i ${OUT_DIR}/Dz_HCP.nii.gz -m ${ROI_DIR}/Prj_L_r3mm.nii.gz)

Dxasso_L=$(fslmeants -i ${OUT_DIR}/Dx_HCP.nii.gz -m ${ROI_DIR}/Ass_L_r3mm.nii.gz)
Dyasso_L=$(fslmeants -i ${OUT_DIR}/Dy_HCP.nii.gz -m ${ROI_DIR}/Ass_L_r3mm.nii.gz)
Dzasso_L=$(fslmeants -i ${OUT_DIR}/Dz_HCP.nii.gz -m ${ROI_DIR}/Ass_L_r3mm.nii.gz)

Dxproj_R=$(fslmeants -i ${OUT_DIR}/Dx_HCP.nii.gz -m ${ROI_DIR}/Prj_R_r3mm.nii.gz)
Dyproj_R=$(fslmeants -i ${OUT_DIR}/Dy_HCP.nii.gz -m ${ROI_DIR}/Prj_R_r3mm.nii.gz)
Dzproj_R=$(fslmeants -i ${OUT_DIR}/Dz_HCP.nii.gz -m ${ROI_DIR}/Prj_R_r3mm.nii.gz)

Dxasso_R=$(fslmeants -i ${OUT_DIR}/Dx_HCP.nii.gz -m ${ROI_DIR}/Ass_R_r3mm.nii.gz)
Dyasso_R=$(fslmeants -i ${OUT_DIR}/Dy_HCP.nii.gz -m ${ROI_DIR}/Ass_R_r3mm.nii.gz)
Dzasso_R=$(fslmeants -i ${OUT_DIR}/Dz_HCP.nii.gz -m ${ROI_DIR}/Ass_R_r3mm.nii.gz)

# -----------------------------
# Step 8. Calculate ALPS index
# -----------------------------

echo "Step 8: Calculate DTI-ALPS index"

ALPS_L=$(echo "scale=8; (${Dxproj_L} + ${Dxasso_L}) / (${Dyproj_L} + ${Dzasso_L})" | bc)
ALPS_R=$(echo "scale=8; (${Dxproj_R} + ${Dxasso_R}) / (${Dyproj_R} + ${Dzasso_R})" | bc)
ALPS_Final=$(echo "scale=8; (${ALPS_L} + ${ALPS_R}) / 2" | bc)

# -----------------------------
# Step 9. Save results
# -----------------------------

echo "Step 9: Save results"

SUB_ID=$(basename ${SUBJECT_DIR})

echo "Subject,Dxproj_L,Dyproj_L,Dzproj_L,Dxasso_L,Dyasso_L,Dzasso_L,ALPS_L,Dxproj_R,Dyproj_R,Dzproj_R,Dxasso_R,Dyasso_R,Dzasso_R,ALPS_R,ALPS_Final" > ${OUT_DIR}/DTI_ALPS_results.csv

echo "${SUB_ID},${Dxproj_L},${Dyproj_L},${Dzproj_L},${Dxasso_L},${Dyasso_L},${Dzasso_L},${ALPS_L},${Dxproj_R},${Dyproj_R},${Dzproj_R},${Dxasso_R},${Dyasso_R},${Dzasso_R},${ALPS_R},${ALPS_Final}" >> ${OUT_DIR}/DTI_ALPS_results.csv

echo "Finished: ${SUB_ID}"
echo "Left ALPS  = ${ALPS_L}"
echo "Right ALPS = ${ALPS_R}"
echo "Final ALPS = ${ALPS_Final}"

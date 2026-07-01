# DTI-ALPS Index Calculation Pipeline

[![FSL](https://img.shields.io/badge/FSL-6.0-blue.svg)](https://fsl.fmrib.ox.ac.uk)
[![ANTs](https://img.shields.io/badge/ANTs-SyN-red.svg)](https://github.com/ANTsX/ANTs)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## Overview

This repository provides a semi-automated pipeline for calculating the **DTI-ALPS (Diffusion Tensor Image Analysis Along the Perivascular Space) index**, a non-invasive MRI-derived surrogate marker of subcortical fluid dynamics.

The pipeline follows a template-based strategy in which four predefined spherical regions of interest (ROIs, 3-mm radius) are defined on the **HCP1065 FA template**. Individual FA maps and diffusivity maps along the x-, y-, and z-axes are nonlinearly registered to the template using the **ANTs Symmetric Normalization (SyN)** algorithm. Diffusivity values are then extracted from the predefined projection and association fiber ROIs to calculate the DTI-ALPS index for each hemisphere:

[
\mathrm{ALPS}=\frac{Dx_{proj}+Dx_{asso}}{Dy_{proj}+Dz_{asso}}
]

The final DTI-ALPS index is obtained by averaging the left and right hemisphere indices.

This template-based semi-automated workflow minimizes operator-dependent variability and improves reproducibility by applying identical anatomical ROIs across all participants.

---

## Requirements

### Software

* **FSL** (version 5.0 or later)

  * https://fsl.fmrib.ox.ac.uk

* **ANTs** (Advanced Normalization Tools)

  * Used for nonlinear image registration (SyN)
  * https://github.com/ANTsX/ANTs

* **dcm2niix** (optional)

  * Used for DICOM to NIfTI conversion
  * https://github.com/rordenlab/dcm2niix

---

## Hardware

* Linux operating system (Ubuntu recommended)
* ≥4 GB RAM
* Approximately 500 MB temporary storage per subject

---

## Pipeline

1. Brain extraction using FSL BET
2. Eddy-current and motion correction
3. Diffusion tensor fitting
4. Generation of diffusivity maps (Dx, Dy, Dz) and FA maps
5. Nonlinear registration of individual diffusion maps to the HCP1065 FA template using ANTs SyN
6. Extraction of diffusivity values from predefined template ROIs
7. Calculation of left and right hemisphere ALPS indices
8. Averaging of bilateral ALPS indices

---

## Input

For each participant:

```
DTI.nii.gz
DTI.bvec
DTI.bval
```

Predefined template files:

```
FSL_HCP1065_FA_1mm.nii.gz

Prj_L_r3mm.nii.gz
Prj_R_r3mm.nii.gz

Ass_L_r3mm.nii.gz
Ass_R_r3mm.nii.gz
```

---

## Output

```
DTI_ALPS_results.csv
```

including

* Dxproj
* Dyproj
* Dzproj
* Dxasso
* Dyasso
* Dzasso
* Left ALPS index
* Right ALPS index
* Final bilateral ALPS index

---

## Citation

If you use this pipeline, please cite:

Zhou S, Wang Z, Liu X, *et al.*

*Surrogates of Brain Fluid Dynamics Associated with Persistence of Post-COVID-19 Brain Fog and Cognitive Impairment.*

---

## Contact

**Xiaoduo Liu**

Department of Neurology

Xuanwu Hospital, Capital Medical University

Beijing, China

E-mail:

* [2270092394@qq.com](mailto:2270092394@qq.com)
* [a2270092394@gmail.com](mailto:a2270092394@gmail.com)

# DTI-ALPS Index Calculation Pipeline

[![FSL](https://img.shields.io/badge/FSL-6.0-blue.svg)](https://fsl.fmrib.ox.ac.uk)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## Overview

This pipeline calculates the **DTI-ALPS (Diffusion Tensor Image Analysis Along the Perivascular Space)** index, a non-invasive MRI proxy for subcortical fluid dynamics.

The method quantifies diffusivity along the x, y, and z axes within projection and association fiber regions to estimate perivascular clearance efficiency.

## Requirements

### Software
- **FSL** (FMRIB Software Library) version 5.0 or 6.0
  - Installation: https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FslInstallation
- **dcm2niix** (optional, for DICOM conversion)
  - Installation: https://github.com/rordenlab/dcm2niix

### Hardware
- Minimum 4GB RAM
- ~500MB disk space per subject (temporary files)

## Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/dti-alps-pipeline.git
cd dti-alps-pipeline

# Make the script executable
chmod +x run_dti_alps.sh

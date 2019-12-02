# Repository for O'Shea, Martin, & Barr

This repository contains data and code to reproduce all analyses and to generate a PDF version of the pre-print for

O'Shea, K. J., Martin, C. R., & Barr, D. J. (preprint). *Ordinary memory processes in the design of referring expressions.*

The software infrastructure required to reproduce the analyses is stored in a [singularity container](https://sylabs.io/singularity/) available at [library://dalejbarr/talklab/ordinary-memory:0.1.0](https://cloud.sylabs.io/library/_container/5de5149734cc93d1ac4a265d). The manuscript and analysis scripts were written using emacs 24.5.1 with org-mode 9.0.3, with data analysis performed in R version 3.3.3.

Scripts and code for each of the three experiments are stored in subfolders `exp1`, `exp2`, and `exp3`.  There is a GNU Makefile in each subfolder and a master Makefile for the entire project in the top-level folder.

## Reproducing results with the software container

1. Clone this repository using git.

```
git clone https://github.com/dalejbarr/ordinary-memory
```

2. Change to the repository directory.

```
cd ordinary-memory
```

3. To reproduce the full results from the raw data, execute the command `make from_raw` in the software container.

```
singularity exec library://dalejbarr/talklab/ordinary-memory:0.1.0 make from_raw
```

This command takes a long time to complete. Note that the first time you access the singularity container image, it will be downloaded from Sylabs Cloud (3.47 GB) to a local image cache.

In case you only want to reproduce the manuscript, leaving all analysis results intact, run `make manuscript` in the container.

```
singularity exec library://dalejbarr/talklab/ordinary-memory:0.1.0 make manuscript
```

## Verifying the results without the container or Makefiles

The raw data files are stored within the `data_raw` folder in each experiment's subdirectory, e.g., `exp1/data_raw`. The analysis scripts have been tangled from the org-mode files into separate files in the `scripts` folder, e.g., `exp1/scripts/01_preprocess.R`, `exp1/scripts/02_analyze_speech.R`, `exp1/scripts/03_analyze_eyedata.R`.  The results from each script are stored in the `data_images` subfolder. 

After cloning the repository, you can remake the data images using the following commands.

```
cd ordinary-memory
Rscript do_all.R
```

All of the `.rda` files in `exp1/data_images`, `exp2/data_images`, and `exp3/data_images` will be re-made.

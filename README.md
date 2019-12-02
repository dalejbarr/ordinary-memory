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

Alternatively, you can just use the bash script `runscript` in the repository, which provides information about elapsed time.

```
./runscript
```

This command takes a long time to complete. Note that the first time you access the singularity container image, it will be downloaded from Sylabs Cloud (3.47 GB) to a local image cache.

In case you only want to reproduce the manuscript, leaving all analysis results intact, run `make manuscript` in the container.

```
singularity exec library://dalejbarr/talklab/ordinary-memory:0.1.0 make manuscript
```

## Verifying the analyses without the container or Makefiles

Because of the need for specialized software, it would be difficult to fully reproduce the analyses without the singularity container. The analysis scripts perform pre-processing of the raw data using the R [**`eyeread`**](https://github.com/dalejbarr/eyeread) package to read in binary EDF files. Unfortunately, this package is only compatible with the Ubuntu Linux operating system, version 16.04 and higher. It is, however, possible to skip the pre-processing stage and reproduce the analyses from the pre-processed data. To exactly reproduce our results, you will need the following packages:

* R version 3.3.3
* tidyverse version 1.2.1
* lme4 version 1.1.21

The raw data files are stored within the `data_raw` folder in each experiment's subdirectory, e.g., `exp1/data_raw`. The analysis scripts have been tangled from the org-mode files into separate files in the `scripts` folder, e.g., `exp1/scripts/01_preprocess.R`, `exp1/scripts/02_analyze_speech.R`, `exp1/scripts/03_analyze_eyedata.R`.  The resulting data images from each script are stored in the `data_images` subfolder. 

To remake the data images without pre-processing, after cloning the repository, use the following commands.

```
cd ordinary-memory
Rscript do_all.R
```

All of the `.rda` files in `exp1/data_images`, `exp2/data_images`, and `exp3/data_images` will be re-made.

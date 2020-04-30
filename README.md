# Repository for O'Shea, Martin, & Barr

This repository contains data and code to reproduce all analyses and to generate a PDF version of the following research article.

O'Shea, K. J., Martin, C. R., & Barr, D. J. (2019, December 11). *Ordinary memory processes in the design of referring expressions.* https://doi.org/10.31234/osf.io/g9n82

The software infrastructure required to reproduce the analyses is stored in a [singularity container](https://sylabs.io/singularity/) available at [library://dalejbarr/talklab/ordinary-memory](https://cloud.sylabs.io/library/_container/5ea9ff0fd0ff9c878fea5839). Alternatively, you can [download the singularity image file `ordinary-memory.sif` directly from the OSF repository](https://osf.io/89g5b/).

The manuscript and analysis scripts were written using emacs 24.5.1 with org-mode 9.0.3, with data analysis performed in R version 3.3.3.

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

3. Execute one of following commands to re-create all of the results and re-compile the manuscript.

```
## access container image from cloud.sylabs.io
singularity exec library://dalejbarr/talklab/ordinary-memory:0.1.0 make from_raw

## OR, if you're using a local image file
singularity exec ordinary-memory_0.1.0.sif make from_raw
```

*NOTE: reproducing from raw data will take about 40 minutes processing time on a typical workstation.*

Alternatively, you can run the following bash script at the linux command line (from outside the container).

```
./runscript
```

In case you only want to reproduce the manuscript, leaving all analysis results intact, run `make manuscript` in the container.

```
singularity exec library://dalejbarr/talklab/ordinary-memory:0.1.0 make manuscript
```

## Verifying the analyses without the container or Makefiles

Because of the need for specialized software, it would be difficult to fully reproduce the analyses without the singularity container. The analysis scripts perform pre-processing of the raw data using the R [**`eyeread`**](https://github.com/dalejbarr/eyeread) package to read in binary EDF files. Unfortunately, this package is only compatible with the Ubuntu Linux operating system, version 16.04 and higher. It is, however, possible to skip the pre-processing stage and reproduce the analyses from the pre-processed data. To exactly reproduce our results, you will need the following software.

* R version 3.3.3
* R package tidyverse version 1.2.1
* R package lme4 version 1.1.21

The raw data files are stored within the `data_raw` folder in each experiment's subdirectory, e.g., `exp1/data_raw`. The analysis scripts have been tangled from the org-mode files into separate files in the `scripts` folder, e.g., `exp1/scripts/01_preprocess.R`, `exp1/scripts/02_analyze_speech.R`, `exp1/scripts/03_analyze_eyedata.R`.  The resulting data images from each script are stored in the `data_images` subfolder. 

To remake the data images without pre-processing, after cloning the repository, use the following commands.

```
cd ordinary-memory
Rscript do_all.R
```

All of the `.rda` files in `exp1/data_images`, `exp2/data_images`, and `exp3/data_images` will be re-made.

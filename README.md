# Repository for O'Shea, Martin, & Barr

This repository contains data and code to reproduce all analyses and to generate a PDF version of the pre-print for

O'Shea, K. J., Martin, C. R., & Barr, D. J. (preprint). *Ordinary memory processes in the design of referential expressions.*

The software infrastructure required to reproduce the analyses is stored in the [talklab Docker container version 1.0.0](https://hub.docker.com/repository/docker/dalejbarr/talklab). The analysis scripts were written using emacs 24.5.1 with org-mode 9.0.3, with data analysis performed in R version 3.3.3.

Scripts and code for each of the three experiments are stored in subfolders `exp1`, `exp2`, and `exp3`.  There is a GNU Makefile for each experiments in each subfolder. There is also a master Makefile for the entire project in the top-level folder.

To delete all intermediate results and reproduce the analyses and manuscript from scratch, run the Docker container with the folder `work` mapped to a folder on your file system containing this repository, and with /home/ruser/work as the working directory.  For instance, if you have this repository in the folder `/Users/poindexter/ordinary-memory`, the Docker command to launch the container would be:

```
docker run --rm \
  --volume /Users/poindexter/ordinary-memory:/home/ruser/work \
  --workdir /home/ruser/work \
  dalejbarr/talklab:1.0.0 \
  /bin/bash -c "make cleanall && make all"
```

To be able to write files from inside the container, you might need to set permissions on the files in your copy of the repository to be writable by members of the unix group gid 1024.

To leave the intermediate results intact and reproduce only the manuscript:

```
docker run --rm \
  --volume /Users/poindexter/ordinary-memory:/home/ruser/work \
  --workdir /home/ruser/work \
  dalejbarr/talklab:1.0.0 \
  /bin/bash -c "make clean && make manuscript"
```

The raw data files are stored within the `data_raw` folder in each experiment's subdirectory, e.g., `exp1/data_raw`. The analysis scripts have been tangled from the org-mode files into separate files in the `scripts` folder, e.g., `exp1/scripts/01_preprocess.R`, `exp1/scripts/02_analyze_speech.R`, `exp1/scripts/03_analyze_eyedata.R`.  The results from each script are stored in the `data_images` subfolder. 

# Experiment pre-registrations

* [Experiment 1](https://osf.io/4akir)
* [Experiment 2](https://osf.io/brxvc)
* [Experiment 3](https://osf.io/5yz3n)

# Supplementary Materials

[This document](supplementary_info.html) contains information about sequencing of blocks as well as all of the images used in Experiments 2 and 3.

## final data image created by makefile
EXP1_IMAGES = exp1/data_images/03_analyze_eyedata.rda
EXP2_IMAGES = exp2/data_images/03_analyze_eyedata.rda
EXP3_IMAGES = exp3/data_images/02_analyze_speech.rda
FIGS = figs/Exp1.png figs/Exp1_HvL.png figs/Exp2_overview.png \
       figs/Exp3_C-S.png figs/Exp3_overview.png figs/Exp3_unconv.png

all : global_fns.R refs_R.bib manuscript

from_raw : cleanall manuscript_nocleanimg

refs_R.bib : makebib.R refs.bib
	@echo "--- Adding R references to refs_R.bib."
	@Rscript makebib.R 2>/dev/null

# Make OShea_Martin_Barr.pdf, and then remove all intermediate files
manuscript : OShea_Martin_Barr_preprint.pdf cleanlatex cleanimg

# Make OShea_Martin_Barr.pdf, and then remove everything but the figures
manuscript_nocleanimg : OShea_Martin_Barr_preprint.pdf cleanlatex

# Make OShea_Martin_Barr.pdf, and then remove everything but the figures
manuscript_noclean : OShea_Martin_Barr_preprint.pdf

manuscript_els : OShea_Martin_Barr_els.pdf elspackage.zip cleanlatex cleanimg

%.R : %.org
	@echo "--- Tangling source blocks from $<..."
	@emacs -q --batch -l org $< -f org-babel-tangle 2>/dev/null
	@echo "--- Done.\n"

OShea_Martin_Barr_preprint.pdf : setup_apa6  refs_R.bib abstract.txt OShea_Martin_Barr.org \
	         $(FIGS) $(EXP1_IMAGES) $(EXP2_IMAGES) $(EXP3_IMAGES)
	@mkdir -p exp1/img
	@mkdir -p exp2/img
	@mkdir -p exp3/img
	@echo "--- Compiling OShea_Martin_Barr.org to PDF..."
	@emacs -q --batch -l dotemacs -l org \
		--eval '(org-babel-lob-ingest "global_fns.org")' \
		OShea_Martin_Barr.org \
	       -f org-latex-export-to-pdf 2>/dev/null
	@rm setup.org
	@mv OShea_Martin_Barr.pdf OShea_Martin_Barr_preprint.pdf
	@echo "--- Done.\n"

# Use elsarticle latex class
OShea_Martin_Barr_els.pdf : setup_els refs_R.bib abstract.txt OShea_Martin_Barr.org \
	        $(FIGS) $(EXP1_IMAGES) $(EXP2_IMAGES) $(EXP3_IMAGES)
	@mkdir -p exp1/img
	@mkdir -p exp2/img
	@mkdir -p exp3/img
	@echo "--- Compiling OShea_Martin_Barr.org to PDF..."
	@emacs -q --batch -l dotemacs -l org \
		--eval '(org-babel-lob-ingest "global_fns.org")' \
		OShea_Martin_Barr.org \
	       -f org-latex-export-to-pdf 2>/dev/null
	@rm setup.org
	@mv OShea_Martin_Barr.pdf OShea_Martin_Barr_els.pdf
	@echo "--- Done.\n"

elspackage.zip : OShea_Martin_Barr_els.pdf abstract.txt
	zip -r elspackage.zip figs/*.png exp1/img/* exp2/img/* exp3/img/* \
		OShea_Martin_Barr.tex OShea_Martin_Barr.bbl refs_R.bib abstract.txt

setup_apa6 : 
	@echo "--- Configuring setup.org to use apa6 class."
	@Rscript mk_setup.R apa6 > setup.org

setup_els : 
	@echo "--- Configuring setup.org to use elsarticle class."
	@Rscript mk_setup.R elsarticle > setup.org

exp1 : $(EXP1_IMAGES)

exp2 : $(EXP2_IMAGES)

exp3 : $(EXP3_IMAGES) 

$(EXP1_IMAGES) : 
	@make -C exp1 all

$(EXP2_IMAGES) : 
	@make -C exp2 all

$(EXP3_IMAGES) : 
	@make -C exp3 all

.PHONY: clean
clean : cleanlatex cleanimg
	@rm -f OShea_Martin_Barr.pdf
	@rm -f global_fns.R

.PHONY: cleanall
cleanall : clean
	@echo "--- Deleting intermediate data images files from exp1, exp2, exp3"
	@make -C exp1 clean
	@make -C exp2 clean
	@make -C exp3 clean

.PHONY: cleanlatex
cleanlatex :
	@echo "--- Deleting intermediate files from manuscript compilation..."
	@rm -f *.bbl OShea_Martin_Barr.tex *~
	@rm -f *.log *.fff *.aux *.out *.ttt *.spl *.blg *.pyg
	@rm -rf _minted-OShea_Martin_Barr
	@rm -f OShea_Martin_Barr.pyg
	@rm -f setup.org
	@rm -f refs_R.bib

.PHONY: cleanimg
cleanimg :
	@echo "--- Deleting plots generated during manuscript compilation..."
	@rm -rf exp1/img
	@rm -rf exp2/img
	@rm -rf exp3/img

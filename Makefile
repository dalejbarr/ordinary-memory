## final data image created by makefile
EXP1_IMAGES = exp1/data_images/03_analyze_eyedata.rda
EXP2_IMAGES = exp2/data_images/03_analyze_eyedata.rda
EXP3_IMAGES = exp3/data_images/02_analyze_speech.rda
FIGS = figs/Exp1.png figs/Exp1_HvL.png figs/Exp2_overview.png \
       figs/Exp3_C-S.png figs/Exp3_overview.png figs/Exp3_unconv.png

all : global_fns.R refs_R.bib manuscript

from_raw : OShea_Martin_Barr.pdf cleanall

refs_R.bib : makebib.R refs.bib
	@Rscript makebib.R

# Make OShea_Martin_Barr.pdf, and then remove all intermediate files
manuscript : OShea_Martin_Barr.pdf cleanlatex cleanimg

# Make OShea_Martin_Barr.pdf, and then remove everything but the figures
manuscript_nocleanimg : OShea_Martin_Barr.pdf cleanlatex

%.R : %.org
	@echo "--- Tangling source blocks from $<..."
	@emacs --batch -l org $< -f org-babel-tangle 2>/dev/null
	@echo "--- Done.\n"

OShea_Martin_Barr.pdf : OShea_Martin_Barr.org setup.org abstract.txt refs_R.bib \
	         $(FIGS) $(EXP1_IMAGES) $(EXP2_IMAGES) $(EXP3_IMAGES)
	@mkdir -p exp1/img
	@mkdir -p exp2/img
	@mkdir -p exp3/img
	@echo "--- Compiling OShea_Martin_Barr.org to PDF..."
	@emacs --batch -l dotemacs -l org \
		--eval '(org-babel-lob-ingest "global_fns.org")' \
		OShea_Martin_Barr.org \
	       -f org-latex-export-to-pdf 2>/dev/null
	@echo "--- Done.\n"

exp1 : $(EXP1_IMAGES)

exp2 : $(EXP2_IMAGES)

exp3 : $(EXP3_IMAGES) 

$(EXP1_IMAGES) : 
	@make -C exp1 all

$(EXP2_IMAGES) : 
	@make -C exp2 all

$(EXP3_IMAGES) : 
	@make -C exp3 all

clean : cleanlatex cleanimg
	@rm -f OShea_Martin_Barr.pdf
	@rm -f global_fns.R

cleanall : clean 
	@make -C exp1 clean
	@make -C exp2 clean
	@make -C exp3 clean

cleanlatex :
	@rm -f *.bbl OShea_Martin_Barr.tex *~
	@rm -rf _minted-OShea_Martin_Barr
	@rm -f OShea_Martin_Barr.pyg

cleanimg :
	@rm -rf exp1/img
	@rm -rf exp2/img
	@rm -rf exp3/img

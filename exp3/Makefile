RCMD = R --no-save --no-restore --slave 

DATA_RAW = $(shell find data_raw -type f)
CODING = $(shell find coding -type f)

E3_ANALYSIS_SCRIPTS =   scripts/01_preprocess.R \
			scripts/02_analyze_speech.R  

E3_PRODUCTS =           data_images/01_preprocess.rda \
			data_images/02_analyze_speech.rda 

all :  data

clean : 
	@rm -rf scripts data_images

scripts :
	@mkdir -p scripts

R_scripts :  scripts $(E3_ANALYSIS_SCRIPTS)

data_images :
	@mkdir -p data_images

data : R_scripts data_images $(DATA_RAW) $(CODING) $(E3_PRODUCTS)

scripts/%.R : %.org
	@echo "--- Tangling source blocks from $<..."
	@emacs --batch -l org $< -f org-babel-tangle 2>/dev/null
	@echo "--- Done.\n"

../%.R : ../%.org
	@echo "--- Tangling source blocks from $<..."
	@emacs --batch -l org $< -f org-babel-tangle 2>/dev/null
	@echo "--- Done.\n"

data_images/01_preprocess.rda : scripts/01_preprocess.R $(DATA_RAW) $(CODING)
	@echo "--- Running scripts/01_preprocess.R ..."
	@$(RCMD) < scripts/01_preprocess.R
	@echo "--- Done.\n"

data_images/02_analyze_speech.rda : ../global_fns.R scripts/02_analyze_speech.R data_images/01_preprocess.rda $(DATA_RAW) $(CODING)
	@echo "--- Running scripts/02_analyze_speech.R ..."
	@$(RCMD) < scripts/02_analyze_speech.R
	@echo "--- Done.\n"

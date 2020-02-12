options(warn = -1)

suppressWarnings(
  suppressPackageStartupMessages({
    library("tidyverse")
    library("eyeread")
  }))

## also need DBI, RSQLite packages for extracting data from sqlite db
## although we won't load these packages in
suppressMessages(
  if (!requireNamespace("DBI")) {
    stop("needs 'DBI' package")
  })

suppressMessages(
  if (!requireNamespace("RSQLite")) {
    stop("needs 'RSQLite' package")
  })

#######################################
## some functions for eyetracking data
#######################################

## tdat is trial data (SessionID, RespID, TSeq)
get_eyelink_data <- function(efile, sessID, tdat) {
  msg <- readEyelinkMessages(efile, "TRIALID", "TRIAL OK") %>%
    filter(Msg == "SYNCTIME")
  tdelim <- readTrialDelimiters(efile, "TRIALID", "TRIAL OK")    
  samps <- readEyelinkSamples(efile, "TRIALID", "TRIAL OK")
  message("    Processing session ", sessID, "...")

  samps %>%
    inner_join(tdelim, "TSeq") %>%
    filter(Msec >= msBegin, Msec <= msEnd) %>%    
    inner_join(msg, "TSeq") %>%
    mutate(ms = Msec.x - Msec.y) %>%
    filter(ms >= 0) %>%
    select(TSeq, Msec = Msec.x, ms, x, y) %>%
    inner_join(tdat %>% filter(SessionID == sessID), "TSeq") %>%
    group_by(RespID) %>%
    mutate(FrameID = row_number() - 1) %>%
    ungroup() %>%
    select(RespID, FrameID, Msec, ms, x, y)
}


## map x/y coords to area of interest
## AOI relates RespID to AOI locations
map_to_pog <- function(sessID, edat, aoi) {
  pog_in <- edat %>% 
    select(-Msec) %>%
    inner_join(aoi, "RespID") %>%
    filter(x >= x1, x <= x1 + 180,
	   y >= y1, y <= y1 + 180) %>%
    select(RespID, FrameID, Name, Role)
  edat %>%
    select(RespID, FrameID) %>%
    left_join(pog_in, c("RespID", "FrameID")) %>%
    mutate(Name = ifelse(is.na(Name), "X", Name),
	   Role = ifelse(is.na(Role), "X", Role))
}

n_distinct_regions_fixated <- function(x) {
  runs <- rle(x[["Name"]])
  valid_fix <- runs$lengths >= as.integer(.1 * 250) ## 100 milliseconds
  vf2 <- valid_fix & (!runs$values %in% c("X", "Target"))
  length(unique(runs$values[vf2]))
}

con <- DBI::dbConnect(RSQLite::SQLite(), "data_raw/EESP3.db")

#######################################
## figure out which condition each trial is in
#######################################

sess <- tbl(con, "Session") %>%
  select(SessionID, ListID) %>%
  filter(SessionID != 999L) %>% collect(n = +Inf)

cond <- tbl(con, "Condition") %>% collect(n = +Inf) %>%
  mutate(shift_dir = substr(Value, 1, 18) %>%
	   recode("Contrast_Singleton" = "Contrast-Singleton",
		  "Singleton_Contrast" = "Singleton-Contrast"),
	 congruency = substr(Value, 20, nchar(Value)) %>%
	   recode("Low" = "incongruent", "High" = "congruent")) %>%
  rename(Cell = CellID) %>%
  select(Cell, shift_dir, congruency)

aoi <- tbl(con, "AOI") %>%
  filter(Link == "itemcell", x1 < 1024) %>%
  collect(n = +Inf) %>%
  rename(ItemCellID = ID)

itm <- tbl(con, "Item") %>%
  filter(TemplateID == 1, Cell == 1) %>% collect(n = +Inf) %>%
  mutate(Series = as.integer(substr(Item, 1, 2))) %>%
  group_by(Series) %>%
  slice(1) %>% ungroup() %>%
  select(ItemCellID, Series)

iinfo <- inner_join(itm, aoi, "ItemCellID") %>%
  filter(Name %in% c("Target", "Competitor")) %>%
  mutate(Resource = sub("\\.bmp", "", Resource)) %>%
  select(Series, Name, Resource) %>%
  spread(Name, Resource) %>%
  mutate(Target_Competitor = paste(Target, Competitor, sep = " / ")) %>%
  select(-Competitor, -Target)

lord <- tbl(con, "ListOrder") %>%
  inner_join(tbl(con, "Item"), "ItemCellID") %>%
  filter(TemplateID == 1, ListID != 999) %>%
  inner_join(tbl(con, "Resource") %>% filter(Code == "SOUNDFILE"),
	     "ItemCellID") %>%
  select(ListID, ItemCellID, OrderConstraint, Item, Cell,
	 Soundfile = Data) %>%
  collect(n = +Inf) %>%
  mutate(Series = as.integer(substr(Item, 1, 2))) %>%
  arrange(ListID, Series, OrderConstraint) %>%
  group_by(ListID, Series) %>%
  mutate(SeriesOrd = row_number()) %>%
  ungroup()

tinf <- tbl(con, "Response") %>%
  inner_join(tbl(con, "Trial"), "TrialID") %>%
  inner_join(tbl(con, "Subject"), c("SubjID", "SessionID")) %>%
  inner_join(tbl(con, "Session"), "SessionID") %>%
  filter(SessionID != 999L) %>%
  select(SessionID, ListID, RespID, ItemCellID) %>%
  collect()

test_trials <- filter(lord, Cell > 0) %>%
  mutate(Role = "Test")

last_train <- filter(lord, Cell == 0) %>%
  group_by(ListID, Series) %>%
  filter(SeriesOrd == max(SeriesOrd)) %>%
  ungroup() %>%
  mutate(Role = "Training")

listcond <- test_trials %>%
  inner_join(cond, "Cell") %>%
  select(ListID, Series, shift_dir, congruency)

all_coding <- bind_rows(test_trials,
			last_train) %>%
  select(-OrderConstraint, -Item, Cell, -SeriesOrd) %>%
  inner_join(tbl(con, "Session") %>%
	     filter(SessionID != 999L) %>%
	     select(SessionID, ListID), "ListID", copy = TRUE) %>%
  inner_join(iinfo, "Series")

conditions <- all_coding %>%
  inner_join(listcond, c("ListID", "Series")) %>%
  filter(Role == "Test") %>%
  select(SessionID, Series, shift_dir, congruency) %>%
  arrange(SessionID, Series, shift_dir, congruency)

tmatchup <- inner_join(tinf, all_coding,
		       c("SessionID", "ListID", "ItemCellID")) %>%
  inner_join(listcond, c("ListID", "Series")) %>%
  filter(Role == "Test") %>%
  select(SessionID, RespID, ItemCellID, Series, ItemID = Target_Competitor,
         shift_dir, congruency)

#######################################
## process coding and identify exclusions
#######################################

message("    Processing coding and identifying exclusions...")

dat <- read_csv("coding/Expt2_data.csv",
                col_types = "iiiccciccccicccl") %>%
  select(-X1, -ShiftDir, -Fluency, -Misspec) %>%
  inner_join(conditions, c("SessionID", "Series"))

dfull <- read_csv("coding/coding.csv",
                  col_types = "iicccicccicccccccc") %>%
  select(-(X12:X18)) %>%
  inner_join(conditions, c("SessionID", "Series"))

train <- dfull %>%
  filter(Role == "Training") %>%
  mutate(Acc = ((shift_dir == "Contrast-Singleton") & Modifier) |
           ((shift_dir == "Singleton-Contrast") & !Modifier)) %>%
  replace_na(list(Acc = FALSE))

## any problematic participants?
bad_sessions <- train %>%
  group_by(SessionID, shift_dir) %>%
  summarize(mAcc = mean(Acc, na.rm = TRUE)) %>%
  filter(mAcc < .5)

bad_items <- train %>%
  group_by(Target_Competitor, shift_dir) %>%
  summarize(mAcc = mean(Acc, na.rm = TRUE)) %>%
  filter(mAcc < .5)

bad_trials <- dfull %>%
  filter(Role == "Test") %>%
  anti_join(bad_sessions, "SessionID") %>%
  anti_join(bad_items, "Target_Competitor") %>%
  semi_join(train %>% filter(!Acc), c("SessionID", "Series"))

main_data <- dat %>%
  filter(Role == "Test") %>%
  anti_join(bad_sessions, "SessionID") %>%
  anti_join(bad_items, "Target_Competitor") %>%
  anti_join(bad_trials, c("SessionID", "Series")) %>%
  mutate(Misspec = ((shift_dir == "Singleton-Contrast") &
                    (Adjective %in% c("NO", "AS", "AO", "DE"))) |
           ((shift_dir == "Contrast-Singleton") &
            (Adjective != "NO")),
         Adjective = if_else(Adjective %in% c("AO", "AS", "DE", "NO", "PO", "PR"),
                             Adjective, NA_character_)) %>%
  ##mutate(Misspec = ((shift_dir == "Singleton-Contrast") & (Modifier == 0)) |
  ##   ((shift_dir == "Contrast-Singleton") & (Modifier == 1))) %>%
  select(SessionID, Series, ItemID = Target_Competitor,
	 shift_dir, congruency,
	 Adjective, Fluency = SpeechFluency, Misspec,
         Onset)

#######################################
## prepare eyedata
#######################################

message("    Preparing eye data...")

sess_inf <- tibble(fname = list.files("data_raw", pattern = "\\.EDF$",
				      full.names = TRUE)) %>%
  mutate(SessionID = as.integer(sub(".+P([0-9]{3}).+", "\\1", fname)),
	 RunID = as.integer(sub(".+P[0-9]{3}-([0-9]{2}).+", "\\1", fname))) %>%
  group_by(SessionID) %>%
  filter(RunID == max(RunID), SessionID != 999) %>%
  inner_join(sess, "SessionID") %>%
  ungroup()

resp_inf <- tbl(con, "Response") %>%
  inner_join(tbl(con, "Subject"), "SubjID") %>%
  inner_join(tbl(con, "Trial"), c("SessionID", "TrialID")) %>%
  filter(SessionID != 999) %>%
  select(SessionID, RespID, TSeq = TrialOrder, ItemCellID) %>%
  collect(n = +Inf)

aoi_inf <- tbl(con, "AOI") %>%
  filter(Link == "itemcell", Name != "Highlight",
	 x1 <= 1024) %>%
  select(ItemCellID = ID, Name, x1, y1) %>%
  collect(n = Inf) %>%
  mutate(Role = sub("^([A-z]+[a-z]+)_[0-9]{1,2}$", "\\1", Name) %>%
	   recode("Target" = "target",
		  "Competitor" = "competitor",
		  "Filler" = "unrelated",
		  "Foil" = "foil")) %>%
  inner_join(resp_inf %>% select(RespID, ItemCellID), "ItemCellID")

edat <- sess_inf %>%
  mutate(edat = map2(fname, SessionID, get_eyelink_data, resp_inf))

message("    Mapping point-of-gaze to region...")  

lookup <- tibble(Role = c("X", "unrelated", "target", "competitor", "foil"),
		 Region = factor(c("blank", "unrelated", "target",
				   "critical", "critical"),
				 levels = c("target", "critical", "unrelated",
					    "blank")))

pog <- edat %>% 
  mutate(data = map2(SessionID, edat, map_to_pog, aoi_inf)) %>%
  select(SessionID, data) %>%
  unnest() %>%
  inner_join(lookup, "Role")

onset_fr <- main_data %>%
  inner_join(tmatchup %>% select(SessionID, Series, RespID),
             c("SessionID", "Series")) %>%
  filter(!is.na(Onset)) %>%
  mutate(onset_frame = as.integer((Onset / 1000) * 250L)) %>%
  select(RespID, Onset, onset_frame)

preonset_fix <- pog %>%
  inner_join(onset_fr, "RespID") %>%
  filter(FrameID < onset_frame) %>%
  select(-Onset, -onset_frame) %>%
  group_by(RespID) %>%
  nest() %>%
  mutate(nfix = map_int(data, n_distinct_regions_fixated)) %>%
  select(-data)

message("    Saving data_images/01_preprocess.rda")
save(list = c("bad_sessions", "bad_items", "bad_trials", "dfull",
	      "main_data", "tmatchup", "pog", "preonset_fix"),
     file = "data_images/01_preprocess.rda")

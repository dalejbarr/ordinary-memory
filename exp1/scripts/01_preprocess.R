#####################################################################
## NOTE: this script was automatically generated from the master file
##       01_preprocess.org.
##
##       Use GNU make + Makefile to generate.
##       It was not intended to be edited by hand.
#####################################################################

options(warn = -1)

#####################################################################
## Preprocess *all* trial information from sqlite db
#####################################################################
suppressWarnings(suppressPackageStartupMessages({
  library("tidyverse")
  library("eyeread")  ## devtools::install_github("dalejbarr/eyeread")
  ## can only be run on linux x64
}))

## also need DBI, RSQLite packages for extracting data from sqlite db
suppressMessages(if (!requireNamespace("DBI")) {
  stop("needs 'DBI' package")
})

suppressMessages(if (!requireNamespace("RSQLite")) {
  stop("needs 'RSQLite' package")
})

## figure out whether it series is
## singleton to contrast (S->C) or contrast to singleton (C->S)
get_shift_dir <- function(series_trials) {
  crit_letter <- series_trials %>%
    filter(Cond > 0L) %>%
    unnest() %>%
    filter(Role %in% c("F", "C")) %>%
    pull(Role)
  if (crit_letter == "C") "S->C" else "C->S"
}

## figure out which letter is the target
get_targ <- function(series_trials) {
  series_trials %>% 
    slice(1L) %>%
    unnest() %>%
    filter(Role == "T") %>%
    pull(Letter)
}

get_cond <- function(series_trials) {
  series_trials %>% 
    filter(Cond > 0L) %>%
    pull(Cond)
}

n_distinct_regions_fixated <- function(x) {
  runs <- rle(x[["Name"]])
  valid_fix <- runs$lengths >= as.integer(.1 * 250) ## 100 milliseconds
  vf2 <- valid_fix & (!runs$values %in% c("X", "T"))
  length(unique(runs$values[vf2]))
}

message("    Preprocessing trial information...")

con <- DBI::dbConnect(RSQLite::SQLite(), "data_raw/exp1.db")	

## trial information (without Areas of Interest (AOIs)
tinf <- tbl(con, "Trial") %>%
  inner_join(tbl(con, "Response"), c("TrialID")) %>%
  inner_join(tbl(con, "Item"), c("ItemCellID")) %>%
  inner_join(tbl(con, "Session") %>%
	     select(SessionID, ListID), "SessionID") %>%
  filter(TemplateID == 1, SessionID != 999L) %>%
  select(SessionID, ListID, RespID, TrialOrder, ItemCellID, Item, Cell) %>%
  collect() %>%
  separate(Item, c("Series", "Screen"), "-") %>%
  group_by(SessionID) %>%
  arrange(TrialOrder) %>%
  mutate(Series = as.integer(Series), Screen = as.integer(Screen)) %>%
  group_by(SessionID, Series) %>%
  arrange(TrialOrder) %>%
  mutate(SOrd = row_number()) %>%
  ungroup() %>%
  arrange(SessionID, TrialOrder)


## information about each grid (letters, locations 1-16, size, color)
gridinf <- tbl(con, "SessionGrids") %>%
  inner_join(tbl(con, "Grids"), c("GridID", "SessionID")) %>%
  filter(Who == "D") %>%
  collect() %>%
  rename(ListID = SessionID)

## targs and foils only
targs <- gridinf %>%
  filter(Pos == Target) %>%
  distinct(ListID, ProtoID, Letter, Pos) 

foils <- tbl(con, "Prototypes") %>%
  filter(Role == "F") %>%
  select(ListID = SessionID, ProtoID, Letter, Pos) %>%
  collect()

targs_and_foils <- bind_rows(targs %>% mutate(Role = "T"),
			     foils %>% mutate(Role = "FC")) %>%
  arrange(ListID, ProtoID, Role)

## the possible letter positions in the grid are numbered like so:
##
##  1 |  2 |  3 |  4 |  5
## -----------------------
##  6 |  7 |  8 |  9 | 10
## -----------------------
## 11 | 12 | 13 | 14 | 15
## -----------------------
## 16 | 17 | 18 | 19 | 20
##
## top left of grid is at (x = 50, y = 22) on 1024x768 px display
## with each square of the grid 180x180 px

## create table with AOI information in pixels
ginf_series <- gridinf %>%
  left_join(targs_and_foils %>% rename(Let = Letter),
	    c("ListID", "ProtoID", "Pos")) %>%
  inner_join(targs %>% select(-Pos) %>% rename(Targ = Letter),
	     c("ListID", "ProtoID")) %>%
  replace_na(list(Role = "D")) %>%
  mutate(Role = case_when(
  (Role == "FC") & (Targ == Letter) ~ "C",
  (Role == "FC") & (Targ != Letter) ~ "F",
  TRUE ~ Role))  %>%
  separate(Fname, c("junk", "Series", "Screen"), "-") %>%
  mutate(Series = as.integer(Series), Screen = as.integer(Screen),
	 ## compute top left corner of each square in grid (x1, y1)
	 x1 = 50L + ((Pos - 1L) %% 5L) * 180L,
	 y1 = 22L + (floor((Pos - 1L) / 5L)) * 180L) %>%
  select(ListID, Series, Screen, Letter, Role,
	 Size, Color, Pos, x1, y1) %>%
  nest(Letter:y1, .key = "aoi") %>%
  inner_join(tinf, c("ListID", "Series", "Screen")) %>%
  arrange(SessionID, TrialOrder) %>%
  select(SessionID, RespID, TrialOrder, Series, Screen, SOrd, aoi,
	 Cond = Cell) %>%
  group_by(SessionID, Series) %>%
  nest(.key = series_trials) %>%
  arrange(SessionID, Series) 

trial_info <- ginf_series %>%
  arrange(SessionID, Series) %>%
  mutate(cond = map_int(series_trials, get_cond),
	 targ_letter = map_chr(series_trials, get_targ),
	 shift_dir = map_chr(series_trials, get_shift_dir),
	 cons = ifelse(cond %% 2L, "low_var", "high_var"))

#####################################################################
## Process coding of training trials & identify sessions for removal
#####################################################################

message("    Determining excluded subjects...")

train_dat <- read_csv("coding/Training_Trials_Final.csv",
		      col_types = "icicdc") %>%
  rename(onset = `onset time`) %>%
  select(-X6) %>%
  separate(Wavfile, c("Junk", "Series", "Screen"), "-") %>%
  mutate(Series = as.integer(Series),
	 Screen = as.integer(substr(Screen, 1, 2))) %>%
  select(-Junk)

trial_valid <- trial_info %>%
  inner_join(train_dat, c("SessionID", "Series")) %>%
  mutate(NeedsAdj = as.integer(shift_dir == "C->S"),
	 Invalid = AdjUse != NeedsAdj)

bad_sessions <- trial_valid %>%
  group_by(SessionID, shift_dir) %>%
  summarize(nInvalid = sum(Invalid, na.rm = TRUE),
	    N = sum(!is.na(Invalid)),
	    p = round(nInvalid / N, 3)) %>%
  ungroup() %>%
  filter(nInvalid > 12) %>%
  mutate(Reason = "too many training errors") %>%
  bind_rows(tibble(SessionID = 43L,
		   Reason = "overdescribing"))

#####################################################################
## Pull in the coding
#####################################################################

message("    Merging with coding of utterances...")

train_file <- file.path("coding", "Training_Trials_Final.csv")
test_file <- file.path("coding", "Test_Trial_Final.csv")

## | Cell | ShiftDir | Distortion |
## |------+----------+------------|
## |    1 | SC       | L          |
## |    2 | SC       | H          |
## |    3 | CS       | L          |
## |    4 | CS       | H          |

cond_lookup <- tibble(Cell = 1:4,
		      `Direction of Shift` = rep(c("Singleton-Contrast",
						   "Contrast-Singleton"), c(2, 2)),
		      `Distortion Level` = rep(c("Low", "High"),
					       times = 2))

sess <- tbl(con, "Session") %>%
  filter(Completion == "COMPLETED", SessionID != 999) %>%
  select(SessionID, ListID) %>% collect()

resp_inf <- tbl(con, "Response") %>%
  inner_join(tbl(con, "Trial"), "TrialID") %>%
  inner_join(tbl(con, "Item"), "ItemCellID") %>%
  inner_join(tbl(con, "Resource") %>% filter(Code == "FNAME"), "ItemCellID") %>%
  select(RespID, SessionID, ItemCellID, Item, Cell, Wavfile = Data) %>%
  collect() %>%
  mutate(ItemID = as.integer(substr(Item, 1, 4))) %>%
  inner_join(sess, "SessionID") %>%
  inner_join(cond_lookup, "Cell")

train_dat <- read_csv(train_file, col_types = "icicdc") %>%
  mutate(ItemID = as.integer(substr(Wavfile, 3, 6)),
	 AdjUse = ifelse(!(AdjUse %in% c("0", "1")), NA, AdjUse) %>%
	   as.integer) %>%
  rename(TrainOnset = `onset time`)

## check for weird onset times
badones <- filter(train_dat, TrainOnset < 300 | TrainOnset > 6000)
stopifnot(nrow(badones) == 0)

trial_valid <- resp_inf %>%
  inner_join(train_dat %>% select(-Notes, -Wavfile), c("SessionID", "ItemID")) %>%
  mutate(NeedsAdj = as.integer(substr(`Direction of Shift`, 1, 1) == "C"),
	 Invalid = ifelse(is.na(AdjUse), TRUE, (AdjUse != NeedsAdj))) %>%
  select(SessionID, RespID, `Direction of Shift`, Invalid)

resp_inf2 <- resp_inf %>%
  anti_join(bad_sessions, "SessionID") %>%
  inner_join(trial_valid %>% select(RespID, Invalid), "RespID")

dat <- read_csv(test_file,
		col_types = "iccccdc") %>%
  mutate(Code = ifelse((AdjUse == "") | (AdjUse == "OTHER"), NA, AdjUse)) %>%
  select(-AdjUse, -Extra) %>%
  inner_join(resp_inf2, c("SessionID", "Wavfile")) %>%
  mutate(Misspecification = ((`Direction of Shift` == "Singleton-Contrast") &
                             (Code %in% c("NO", "AS", "AO", "DE"))) |
	   ((`Direction of Shift` == "Contrast-Singleton") &
	    (Code != "NO")))

## check for weird onset times
badones <- filter(dat, Onset < 300 | Onset > 10000)
stopifnot(nrow(badones) == 0)

main_data <- train_dat %>%
  inner_join(dat, c("SessionID", "ItemID")) %>%
  mutate(OnsetChg = Onset - TrainOnset) %>%
  select(SessionID, RespID, AdjTrain = AdjUse, Fluency, ItemID, Code,
	 TrainOnset, Onset, OnsetChg,
	 Invalid, Misspecification, `Direction of Shift`, `Distortion Level`)

DBI::dbDisconnect(con)

#####################################################################
## Scrape out the eye data from EDF files
#####################################################################

message("    Scraping eye data from EDF files and mapping to POG...")

## read/process eyedata from EDF for a single session
do_session <- function(SessionID, data) {
  pog2aoi <- function(edat2, aoi, Sync, bord = 0L, imgsize = 180L) {
    edat3 <- edat2 %>%
      arrange(Msec) %>%
      mutate(Msec = Msec - Sync) %>%
      filter(Msec > 0L) %>%
      mutate(FrameID = row_number())
    frin <- crossing(edat3, aoi) %>%
      filter(x >= (x1 - bord), x <= (x1 + imgsize + bord),
	     y >= (y1 - bord), y <= (y1 + imgsize + bord)) %>%
      select(FrameID, Msec, Name = Role, Pos = Pos)
    frout <- anti_join(select(edat3, FrameID, Msec),
		       frin, by=c("FrameID", "Msec")) %>%
      mutate(Name = "X", Pos = NA_integer_)
    rbind(frin, frout) %>% arrange(Msec) %>% as.data.frame()
  }    
  read_synctime <- function(fname) {
    msg <- readEyelinkMessages(fname, "TRIALID", "TRIAL OK") %>%
      as_tibble()
    msg %>% filter(Msg=="SYNCTIME") %>%
      select(TSeq, Sync=Msec)
  }

  ## check for multiple files
  message("    Processing EDF file for session ", SessionID, "...")
  lfiles <- list.files("data_raw", pattern="^P[0-9]{3}-[0-9]{2}\\.EDF$",
		       full.names = TRUE)
  inp <- grep(sprintf("P%03d", SessionID), lfiles, value=TRUE)
  if (length(inp) > 1) { ## more than one file for this session!
    stop("multiple EDF files found for SessionID", SessionID)
  } else {}
  trials_todo <- read_synctime(inp) %>%
    inner_join(data %>% unnest() %>% select(RespID, TrialOrder, aoi),
	       c("TSeq" = "TrialOrder"))
  samps <- readEyelinkSamples(inp, "TRIALID", "TRIAL OK") %>%
    group_by(TSeq) %>%
    nest(.key = "edat") %>%
    inner_join(trials_todo, "TSeq") %>%
    mutate(pog = pmap(list(edat, aoi, Sync), pog2aoi)) %>%
    as_tibble()
  samps %>%
    select(RespID, pog) %>% unnest()
}

downsample <- function(data) {
  data %>%
    arrange(RespID, FrameID) %>%
    group_by(RespID) %>%
    mutate(rn = row_number(),
           ff = rn %% 2L) %>%
    filter(ff == 1L) %>%
    mutate(FrameID = row_number()) %>%
    ungroup() %>%
    select(-rn, -ff)
}  

trial_incl <- trial_info %>%
  anti_join(bad_sessions, "SessionID")

pog <- trial_incl %>%
  group_by(SessionID) %>%
  nest() %>%
  mutate(pog = pmap(list(SessionID, data), do_session)) %>%
  select(pog) %>%
  unnest()

#####################################################################
## Downsample 500Hz sessions
#####################################################################

message("    Downsampling from 500 to 250Hz...")

tresp <- trial_incl %>%
  select(SessionID, series_trials) %>%
  unnest() %>%
  select(SessionID, RespID)

srates <- read_csv("data_raw/sampling_rates.csv",
		   col_types = "ii")

psess <- pog %>%
  inner_join(tresp, "RespID") %>%
  group_by(SessionID) %>%
  nest() %>%
  inner_join(srates, "SessionID")

newpog <- psess %>%
  filter(Threshold == 500L) %>%
  mutate(newdat = map(data, downsample)) %>%
  select(newdat) %>%
  unnest()

pog2 <- bind_rows(psess %>% filter(Threshold == 250L) %>%
		  select(data) %>% unnest(),
		  newpog) %>%
  arrange(RespID, FrameID)

onset_fr <- main_data %>%
  filter(!is.na(Onset)) %>%
  mutate(onset_frame = as.integer((Onset / 1000) * 250L)) %>%
  select(RespID, Onset, onset_frame)

preonset_fix <- pog2 %>%
  inner_join(onset_fr, "RespID") %>%
  filter(FrameID < onset_frame) %>%
  select(-Onset, -onset_frame) %>%
  group_by(RespID) %>%
  nest() %>%
  mutate(nfix = map_int(data, n_distinct_regions_fixated)) %>%
  select(-data) %>%
  ungroup()

rm(con, newpog, pog, dat, badones)
message("    Saving data_images/01_preprocess.rda...")
save(list = ls(), file = "data_images/01_preprocess.rda")

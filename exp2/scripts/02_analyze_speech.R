## load in the exp 1 data and compute things we need for tables and text
suppressWarnings(suppressPackageStartupMessages({
  library("tidyverse")
  library("lme4")
}))

message("    Calculating descriptives...")

source("../global_fns.R")

load("data_images/01_preprocess.rda")
.old_obj <- ls()
.dat <- main_data

## MISSPECIFICATION ANALYSIS

## how many observations
n_obs <- 48L * 36L
n_bad_itm <- nrow(bad_items) * 36L
n_bad_tri <- nrow(bad_trials)
n_additional <- n_obs - n_bad_itm - n_bad_tri -
  (.dat %>% filter(!is.na(Misspec)) %>% nrow())
n_rem <- nrow(.dat %>% filter(!is.na(Misspec)))

stopifnot((n_obs - n_bad_itm - n_bad_tri - n_additional) == n_rem)

## observations removed for speech onset analysis
n_mis <- .dat %>% filter(!is.na(Misspec)) %>%
  filter(Misspec) %>% nrow()
n_na <- .dat %>% filter(!is.na(Misspec)) %>%
  filter(Misspec) %>%
  filter(is.na(Onset)) %>% nrow()

dat_mis <- .dat %>%
  filter(!is.na(Misspec)) 

## calculate the cell means
cell_means0 <- dat_mis %>%
  group_by(shift_dir, 
           congruency) %>%
  summarise(mis_rate = mean(Misspec, na.rm = TRUE)) %>%
  ungroup()

cell_means <- cell_means0 %>%
  spread("congruency", "mis_rate")

## grand means by distortion
marg_dist <- dat_mis %>%
  group_by(congruency) %>%
  summarise(mis_rate = mean(Misspec, na.rm = TRUE))

## grand means by shift dir
marg_shift <- dat_mis %>%
  group_by(shift_dir) %>%
  summarise(mis_rate = mean(Misspec, na.rm = TRUE))

coding_tbl <- dat_mis %>%
  filter(!is.na(Adjective)) %>%
  mutate(shift_dir = factor(shift_dir),
         congruency = factor(congruency) %>% fct_relevel("congruent"),
         code = factor(Adjective,
		       levels = c("NO", "PR", "PO", "DE", "AS", "AO")) %>%
           fct_infreq()) %>%
  group_by(shift_dir, congruency, code, .drop = FALSE) %>%
  summarize(Y = n()) %>%
  ungroup() %>%
  group_by(shift_dir, congruency) %>%
  mutate(N = sum(Y), p = Y / N,
         p2 = sprintf("%0.1f%%", 100 * p)) %>%
  ungroup() %>%
  select(-Y, -N, -p) %>%
  spread("code", "p2")

keep <- setdiff(ls(), .old_obj)

message("    Creating plot of misspecification rate...")

mis_plot_d <- dat_mis %>%
  mutate(congruency = fct_relevel(congruency, "congruent")) %>%
  group_by(SessionID,
	   shift_dir,
	   congruency) %>%
  summarize(m = mean(Misspec, na.rm = TRUE)) %>%
  ungroup()

## from global.org
mis_plot <- stix_plot(mis_plot_d, congruency, m, shift_dir) +
  facet_wrap(~shift_dir) +
  scale_y_continuous(labels = scales::percent) +
  labs(y = "Misspecification Rate", x = "Congruency")

mdat <- dat_mis %>%
  mutate(C = (congruency == "congruent") -
           mean(congruency == "congruent"),
         S = (shift_dir == "Singleton-Contrast") -
           mean(shift_dir == "Singleton-Contrast")) %>%
  select(SessionID, ItemID, S, C, Misspec)

message("    Fitting mixed-effects model to misspecification data (model 1)...")

mod_mis <- glmer(
  Misspec ~ S * C + (S * C | SessionID) + (S * C | ItemID),
  mdat,
  family = binomial(link = logit),
  control = glmerControl(optimizer = "bobyqa"))

message("    Fitting mixed-effects model to misspecification data (model 2)...")

mod_mis2 <- glmer(
  Misspec ~ S * C + (S * C || SessionID) + (S + C || ItemID),
  mdat,
  family = binomial(link = logit),
  control = glmerControl(optimizer = "bobyqa"))

save(list = c(keep, "main_data", "mis_plot", "mod_mis", "mod_mis2"),
     file = "data_images/02_analyze_speech.rda")

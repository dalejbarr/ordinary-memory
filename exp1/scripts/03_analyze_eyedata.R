options(warn = -1)

#################
## LOAD/preprocess the data
#################
suppressWarnings(
  suppressPackageStartupMessages({
    library("tidyverse")
    source("../global_fns.R")
  }))

message("    Preparing eye data...")

.old_obj <- load("data_images/01_preprocess.rda")

region_lookup <- tibble(
  Name = c("X", "D", "T", "C", "F"),
  Region = factor(c("blank", "unrelated", "target",
                    "critical", "critical"),
                  levels = c("target", "critical", "unrelated", "blank")))

tresp <- main_data %>%
  filter(!Invalid) %>%
  select(SessionID,
         RespID,
         dist = `Distortion Level`,
         shift_dir = `Direction of Shift`,
         misspec = Misspecification,
         Onset)

## point of gaze (POG) data
pog <- pog2 %>%
  filter(FrameID <= 500L) %>%
  left_join(region_lookup, "Name") %>%
  mutate(Crit = Region == "critical") %>%
  select(RespID, FrameID, Name, Region, Crit)
rm(pog2)

#################
## count the number of observations for each combination of
## SessionID, dist, shift_dir, FrameID
#################

binned <- tresp %>%
  inner_join(pog, "RespID") %>%
  group_by(SessionID, dist, shift_dir, FrameID, Region, .drop = FALSE) %>%
  summarise(Y = n()) %>%
  group_by(SessionID, dist, shift_dir, FrameID) %>%
  mutate(N = sum(Y), p = Y / N) %>%
  ungroup()

bins_means <- agg_up(binned, p, dist, shift_dir, FrameID, Region)

nmc <- 1000L
message("    Running ", nmc, " bootstrap samples (takes a long time)...")

mx <- replicate(nmc, boot_once(binned, SessionID) %>%
  agg_up(p, dist, shift_dir, FrameID, Region) %>%
  pull(p))

conf <- apply(mx, 1, quantile, probs = c(.025, .975))

bins_means[["lower"]] = conf["2.5%", ]
bins_means[["upper"]] = conf["97.5%", ]

message("    Creating probability plot...")

exp1_probplot <- bins_means %>%
  filter(Region != "blank") %>%
  mutate(ms = round(1000 * ((FrameID - 1) / 250))) %>%
  ggplot(aes(ms, p, linetype = dist)) +
  geom_ribbon(aes(fill = Region, ymin = lower, ymax = upper),
	      alpha = .2) +
  geom_smooth(aes(color = Region), se = FALSE, span = .05, alpha = .6) +
  facet_wrap(~shift_dir, nrow = 2) +
  scale_fill_manual(values = cbPalette) +
  scale_color_manual(values = cbPalette) +
  labs(x = "Time from display onset (ms)",
       y = "Gaze probability",
       linetype = "Distortion")

library("lme4")

pre2 <- preonset_fix %>%
  inner_join(main_data, "RespID") %>%
  mutate(D = `Distortion Level` == "Low",
         D = D - mean(D)) %>%
  filter(!Misspecification)

numfix_marg <- pre2 %>%
  group_by(`Distortion Level`) %>%
  summarize(m = mean(nfix), sd = sd(nfix))

mod_pre1 <- glmer(nfix ~ D + (D | SessionID), pre2,
                  family = poisson)

## it's singular, so:

mod_pre2 <- glmer(nfix ~ D + (1 | SessionID), pre2,
                  family = poisson)

message("    Writing data_images/03_analyze_eyedata.rda...")
save(list = c("bins_means", "binned", "nmc", "exp1_probplot", 
	      "mod_pre2", "pre2", "numfix_marg"),
     file = "data_images/03_analyze_eyedata.rda")

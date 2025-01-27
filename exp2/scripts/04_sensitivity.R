
#####################################################################
## NOTE: this script was automatically generated from the master file
##       04_sensitivity.org.
##
##       Use GNU make + Makefile to generate.
##       It was not intended to be edited by hand.
#####################################################################

options(warn = -1)

# load in the exp 1 data and compute things we need for tables and text
suppressWarnings(suppressPackageStartupMessages({
  library("parallel")
  library("lme4")
  library("tidyverse")
}))

simulate_newdata <- function(mod, d, deff = lme4::fixef(mod)["C"]) {
  fx <- lme4::fixef(mod)

  ## get random effects
  rx_int_s <- sqrt(as.numeric(lme4::VarCorr(mod)[["SessionID.1"]]))
  rx_slp_s <- sqrt(as.numeric(lme4::VarCorr(mod)[["SessionID"]]))
  rx_int_i <- sqrt(as.numeric(lme4::VarCorr(mod)[["SessionID.1"]]))
  rx_slp_i <- sqrt(as.numeric(lme4::VarCorr(mod)[["SessionID"]]))

  ## build table of subjects with random effects
  t1 <- d %>%
    distinct(SessionID) %>%
    mutate(rint = rnorm(length(SessionID), sd = rx_int_s),
           rslp = rnorm(length(SessionID), sd = rx_slp_s))

  ## build table of items with random effects
  t2 <- d %>%
    distinct(ItemID) %>%
    mutate(rint = rnorm(length(ItemID), sd = rx_int_i),
           rslp = rnorm(length(ItemID), sd = rx_slp_i))

  d %>%
    select(-Misspec) %>%
    inner_join(t1, "SessionID") %>%
    inner_join(t2, "ItemID", suffix = c(".s", ".i")) %>%
    mutate(eta = fx["(Intercept)"] + rint.s + rint.i +
             fx["S"] * S +
             (deff + rslp.s + rslp.i) * C +
             fx["S:C"] * S * C,
           Misspec = map_int(
             eta, ~ sample(c(1L, 0L), 1L,
                           prob = c(1 / (1 + exp(-.x)),
                                    1 - (1 / (1 + exp(-.x))))))) %>%
    select(SessionID, ItemID, S, C, Misspec)
}

calc_propeff <- function(d) {
  ## calculate marginal effect of D (proportional scale)
  d %>%
    group_by(C) %>%
    summarize(m = mean(Misspec), .groups = "drop") %>%
    pull(m)
}

calc_p <- function(d) {
  ## fit the model and get the (one-tailed) p value
  suppressMessages({m <- lme4::glmer(
                      Misspec ~ S * C + (C || SessionID) + (C || ItemID),
                      d,
                      family = binomial(link = logit),
                      control = lme4::glmerControl(optimizer = "bobyqa"))})

  tstat <- lme4::fixef(m)["C"] / sqrt(lme4::vcov.merMod(m)["C", "C"])
  as.numeric(pnorm(tstat, lower.tail = FALSE))
}

old_obj <- load("data_images/02_analyze_speech.rda")

mdat <- dat_mis %>%
  mutate(C = (congruency == "congruent") -
           mean(congruency == "congruent"),
         S = (shift_dir == "Singleton-Contrast") -
           mean(shift_dir == "Singleton-Contrast")) %>%
  select(SessionID, ItemID, S, C, Misspec)

mod_est_d1 <- glmer(
  Misspec ~ S * C + (C || SessionID) + (C || ItemID),
  mdat,
  family = binomial(link = logit),
  control = glmerControl(optimizer = "bobyqa"))

mod_est_d2_s <- glmer(
  Misspec ~ S * C + (1 | SessionID) + (C || ItemID),
  mdat,
  family = binomial(link = logit),
  control = glmerControl(optimizer = "bobyqa"))

mod_est_d2_i <- glmer(
  Misspec ~ S * C + (C || SessionID) + (1 | ItemID),
  mdat,
  family = binomial(link = logit),
  control = glmerControl(optimizer = "bobyqa"))

## is there evidence for significant by-subject variance in the effect
## of congruency?
d_rslp_est_s <- sqrt(as.numeric(VarCorr(mod_est_d1)[["SessionID"]][1, 1]))
d_rslp_chi_s <- abs(2 * logLik(mod_est_d2_s) - 2 * logLik(mod_est_d1)) %>%
  as.numeric()
## pchisq(d_rslp_chi_s, 1L, lower.tail = FALSE)

## is there evidence for significant by-item variance in the effect
## of congruency?
d_rslp_est_i <- sqrt(as.numeric(VarCorr(mod_est_d1)[["ItemID"]][1, 1]))
d_rslp_chi_i <- abs(2 * logLik(mod_est_d2_i) - 2 * logLik(mod_est_d1)) %>%
  as.numeric()
## pchisq(d_rslp_chi_i, 1L, lower.tail = FALSE)

cl <- makeCluster(if (detectCores() > 3L) {
                    detectCores() - 2L
                  } else {
                    detectCores()})
invisible(clusterCall(cl, function(x) {library("tidyverse")}))
clusterExport(cl, c("simulate_newdata", "calc_propeff", "calc_p",
                    "mod_est_d1", "mdat"))

## test raw logit effect size .1, .2, .3, .4, .5, .6
## with 1000 runs for each
eff_sizes <- rep(seq(.1, .7, length.out = 6), each = 1000)

## run and store as a table
message("    Running sensitivity analysis (takes a long time)...")
sensitivity <- parSapply(cl, eff_sizes, function(deff) {
  d <- simulate_newdata(mod_est_d1, mdat, deff)
  meff <- calc_propeff(d)
  pt <- calc_p(d)
  c(deff = deff, highdist = meff[1], lowdist = meff[2], p = pt)}) %>%
  t() %>%
  as_tibble()

stopCluster(cl)

message("    Writing data_images/04_sensitivity.rda...")
save(list = c("d_rslp_est_s", "d_rslp_chi_s",
              "d_rslp_est_i", "d_rslp_chi_i",
              "sensitivity"),
     file = "data_images/04_sensitivity.rda")

## rm(list = ls())
suppressWarnings(
  suppressPackageStartupMessages({
    library("lme4")
    library("tidyverse")
  }))

source("../global_fns.R")
load("data_images/01_preprocess.rda")
.old_obj <- ls()

message("    Calculating descriptive statistics...")

.dat_mis <- main_data %>%
  mutate(Addressee = if_else(PragCon, "same", "different"),
         `Visible Partner` = if_else(PercCon, "same", "different")) %>%
  rename(`Shift Direction` = shift_dir) %>%
  select(-PragCon, -PercCon)

.wcount <- unco_data %>%
  mutate(Addressee = if_else(PragCon, "same", "different"),
         `Visible Partner` = if_else(PercCon, "same", "different"))

## MISSPECIFICATION ANALYSIS

## how many observations
n_obs <- 48L * 40L

## calculate the cell means
cell_means0 <- .dat_mis %>%
  group_by(`Shift Direction`,
           Addressee,
           `Visible Partner`) %>%
  summarise(mis_rate = mean(misspec, na.rm = TRUE)) %>%
  ungroup()

cell_means <- cell_means0 %>%
  spread(`Visible Partner`, "mis_rate")

## marginal means by visible partner
marg_vp <- .dat_mis %>%
  group_by(`Visible Partner`) %>%
  summarise(mis_rate = mean(misspec, na.rm = TRUE))

## marginal means by Addressee
marg_addr <- .dat_mis %>%
  group_by(Addressee) %>%
  summarise(mis_rate = mean(misspec, na.rm = TRUE))

## marginal means by shift dir
marg_shift <- .dat_mis %>%
  group_by(`Shift Direction`) %>%
  summarise(mis_rate = mean(misspec, na.rm = TRUE))

## word count
cmeans_wc0 <- .wcount %>%
  group_by(Addressee, `Visible Partner`) %>%
  summarize(m = mean(Words), sd = sd(Words)) %>%
  ungroup()

cmeans_wc <- cmeans_wc0 %>%
  select(-sd) %>%
  spread(`Visible Partner`, m)

marg_wc_addr <- .wcount %>%
  group_by(Addressee) %>%
  summarize(wc = mean(Words), sd = sd(Words))

marg_wc_vp <- .wcount %>%
  group_by(`Visible Partner`) %>%
  summarize(wc = mean(Words), sd = sd(Words))

coding_tbl <- .dat_mis %>%
  filter(!is.na(Adjective)) %>%
  mutate(`Shift Direction` = factor(`Shift Direction`),
         `Visible Partner` = factor(`Visible Partner`) %>% fct_relevel("same"),
         Addressee = factor(Addressee) %>% fct_relevel("same"),
         code = factor(Adjective,
		       levels = c("NO", "PR", "PO", "DE", "AS", "AO")) %>%
           fct_infreq()) %>%
  group_by(`Shift Direction`, `Visible Partner`, Addressee, code, .drop = FALSE) %>%
  summarize(Y = n()) %>%
  ungroup() %>%
  group_by(`Shift Direction`, `Visible Partner`, Addressee) %>%
  mutate(N = sum(Y), p = Y / N,
         p2 = sprintf("%0.1f%%", 100 * p)) %>%
  ungroup() %>%
  select(-Y, -N, -p) %>%
  spread("code", "p2")

keep <- setdiff(ls(), .old_obj)

message("    Creating plot of misspecification rate...")

mis_plot_d <- .dat_mis %>%
  mutate(Addressee = fct_relevel(Addressee, "same"),
         `Visible Partner` = fct_relevel(`Visible Partner`, "same"),
         Addressee = fct_recode(Addressee, "Same" = "same",
                                "Different" = "different"),
         `Visible Partner` =
           fct_recode(`Visible Partner`,
		      "Same" = "same",
		      "Different" = "different")) %>%
  group_by(SessionID,
	   `Shift Direction`, `Visible Partner`, `Addressee`) %>%
  summarize(m = mean(misspec, na.rm = TRUE)) %>%
  ungroup()

## from global.org
mis_plot <- stix_plot(mis_plot_d, `Visible Partner`, m, `Shift Direction`,
		      Addressee) +
  facet_grid(Addressee ~ `Shift Direction`, labeller = label_both) +
  scale_y_continuous(labels = scales::percent) +
  labs(y = "Misspecification Rate", x = "Visible Partner")

message("    Creating plot of word count...")

wc_plot_d <- .wcount %>%
  mutate(Addressee = fct_relevel(Addressee, "same"),
         `Visible Partner` = fct_relevel(`Visible Partner`, "same")) %>%
  group_by(SessionID, `Visible Partner`, Addressee) %>%
  summarize(m = mean(Words)) %>%
  ungroup()

wc_plot <- stix_plot(wc_plot_d, `Visible Partner`, m, Addressee) +
  labs(y = "Word Count", x = "Visible Partner") +
  facet_wrap(~Addressee, labeller = label_both)

## ggsave("wcplot.pdf", wc_plot, width = 6, height = 3.2)

cdat <- .dat_mis %>%
  mutate(VP = (`Visible Partner` == "same") -
           mean(`Visible Partner` == "same"),
         A = (Addressee == "same") -
           mean(Addressee == "same"),
         SD = (`Shift Direction` == "Singleton-Contrast") -
           mean(`Shift Direction` == "Singleton-Contrast"))


message("    NB: maximal mixed-effects model takes forever, does not converge...")

## does not converge: takes forever
## mod_mis <- glmer(misspec ~ SD * VP * A +
##                   (SD * VP * A | SessionID) +
##                   (SD * VP * A | Series),
##                 cdat,
##                 binomial(link = "logit"),
##                 control = glmerControl(optimizer = "bobyqa"))

message("    Estimating reduced mixed-effects model (model 1)...")

mod_mis_form <- misspec ~ SD * VP * A +
  (SD * VP * A || SessionID) +
  (SD * VP * A || Series)
mod_mis <- glmer(mod_mis_form,
                  cdat,
                  binomial(link = "logit"),
                  control = glmerControl(optimizer = "bobyqa"))

message("    Estimating reduced mixed-effects model (model 2)...")

mod_mis_form2 <- misspec ~ SD * VP * A +
  (VP + VP:A + SD:VP:A || SessionID) +
  (SD + SD:VP + SD:VP:A || Series)
mod_mis2 <- glmer(mod_mis_form2,
                  cdat,
                  binomial(link = "logit"),
                  control = glmerControl(optimizer = "bobyqa"))

mod_fx <- tibble(
  effect = c("Intercept",
             "Shift Direction (SD)", "Visible Partner (VP)", "Addressee (A)",
             "SD:VP", "SD:A", "VP:A", "SD:VP:A"),
  beta = fixef(mod_mis2),
  SE = sqrt(diag(vcov(mod_mis2)))) %>%
  mutate(`Wald z` = beta / SE,
         `p-value` = map2_dbl(`Wald z`, rep(c(FALSE, TRUE, FALSE), c(2, 1, 5)),
			      ~ if (.y)
                                  pnorm(.x, lower.tail = FALSE)
                                else
                                  2 * pnorm(abs(.x), lower.tail = FALSE)))

## WC analysis for unconventional objects
message("    Estimating maximal mixed-effects model for word count (model 1)...")
mod_wc_form <- Words ~ VP * A +
  (VP * A | SessionID) +
  (VP * A | Series)
mod_wc <- glmer(mod_wc_form,
                unco_data %>%
                filter(Phase == "tst") %>%
                mutate(A = PragCon - mean(PragCon),
		       VP = PercCon - mean(PercCon)),
                poisson(link = "log"))

message("    Estimating reduced model for word count (model 2)...")
mod_wc_form2 <- Words ~ VP * A +
  (VP * A || SessionID) +
  (A || Series)
mod_wc2 <- glmer(mod_wc_form2,
                 unco_data %>%
                 filter(Phase == "tst") %>%
                 mutate(A = PragCon - mean(PragCon),
                        VP = PercCon - mean(PercCon)),
                 poisson(link = "log"))

message("    Saving data_images/02_analyze_speech.rda")
save(list = c(keep, "mod_mis", "mod_mis2", "mod_mis_form", "mod_mis_form2",
	      "mis_plot", "wc_plot",
	      "mod_wc", "mod_wc_form",
	      "mod_wc2", "mod_wc_form2", "mod_fx"),
     file = "data_images/02_analyze_speech.rda")

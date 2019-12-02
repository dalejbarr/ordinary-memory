suppressWarnings(
  suppressPackageStartupMessages({
    library("rlang")
    library("tidyverse")
  }))

## bootstrap the dataset
boot_once <- function(data, unit) {
  unitv <- enquo(unit)
  group_by(data, !!unitv) %>%
    nest() %>%
    sample_n(nrow(.), TRUE) %>%
    group_by(!!unitv) %>%
    mutate(boot_id = row_number()) %>%
    select(!!unitv, boot_id, data) %>%
    ungroup() %>%
    unnest()
}

agg_up <- function(data, dv, ..., na.rm = FALSE) {
  dvv <- rlang::enquo(dv)
  dvn <- rlang::quo_name(dvv)
  gvars <- rlang::enquos(...)
  gd = group_by(data, !!!gvars)
  ungroup(summarize(gd, !!dvn := mean(!!dvv, na.rm = na.rm)))
}

agg_up2 <- function(data, yvar, nvar, ..., na.rm = FALSE) {
  dv_yvar <- rlang::enquo(yvar)
  dv_nvar <- rlang::enquo(nvar)
  gvars <- rlang::enquos(...)
  gd = group_by(data, !!!gvars)
  ungroup(
    summarize(gd,
	      p = sum(!!dv_yvar, na.rm = na.rm) /
                sum(!!dv_nvar, na.rm = na.rm)))
}

stix_plot <- function(dd, x, y, ...) {
  xv <- rlang::enquo(x)
  yv <- rlang::enquo(y)
  ## zv <- rlang::enquo(z)
  dotsv <- c(xv, rlang::enquos(...))
  yvn <- rlang::quo_name(yv)
  ## fmla <- as.formula(paste0("~", substitute(z)))

  gd <- group_by(dd, !!!dotsv)
  cmeans <- ungroup(summarize(gd, !!yvn := mean(!!yv)))

  ggplot(dd,
	 aes(!!xv, !!yv)) +
    geom_point(data = cmeans,
	       color = "red", size = 5, alpha = .35) +
    geom_line(data = cmeans,
	      group = 1, color = "red", alpha = .35) +
    geom_point(alpha = .2) +
    geom_line(aes(group = SessionID), alpha = .2) ## +
  ##  facet_wrap(fmla)    
}

# colorblind palette with grey:
cbPalette <- c("#999999", "#E69F00", "#56B4E9", "#009E73",
	       "#F0E442", "#0072B2", "#D55E00", "#CC79A7")

tfile <- tempfile()
ofile <- "refs_R.bib"

cit <- capture.output(print(citation(), style = "bibtex"))
cit[1] <- "@Manual{R,"

cit2 <- capture.output(print(citation("lme4"), style = "bibtex"))
cit2[1] <- "@article{lme4,"

cat(cit, cit2, file = tfile, sep = "\n", append = FALSE)
invisible(file.append(tfile, "refs.bib"))

lines <- readLines(tfile)
lines2 <- grep("^\\s+month\\s*=", lines, value = TRUE, invert = TRUE)
lines3 <- grep("^\\s+number\\s*=", lines2, value = TRUE, invert = TRUE)
lines4 <- grep("^\\s+doi\\s*=", lines3, value = TRUE, invert = TRUE)
lines5 <- grep("^\\s+url\\s*=", lines4, value = TRUE, invert = TRUE)

writeLines(lines5, ofile)

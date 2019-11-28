ofile <- "refs_R.bib"

cit <- capture.output(print(citation(), style = "bibtex"))
cit[1] <- "@Manual{R,"

cit2 <- capture.output(print(citation("lme4"), style = "bibtex"))
cit2[1] <- "@article{lme4,"

cat(cit, cit2, file = ofile, sep = "\n")
file.append(ofile, "refs.bib")

if (length(commandArgs(TRUE)) == 0L) {
  stop("need to supply latex class as command argument ('elsarticle' or 'apa6')")
}

if (!(commandArgs(TRUE)[1] %in% c("elsarticle", "apa6"))) {
  stop("latex class must be one of 'elsarticle', 'apa6'")
}

cat("#+AUTHOR: ",
    "#+LANGUAGE: en ", sep = "\n")

if (commandArgs(TRUE)[1] == "elsarticle") {
  cat("#+OPTIONS: toc:nil ^:nil ':t ",
      "#+LATEX_CLASS: elsarticle",
      "#+LATEX_CLASS_OPTIONS: [review,authoryear]",
      "#+LATEX_HEADER: \\author{Kieran J. O'Shea\\corref{cor1}}",
      "#+LATEX_HEADER: \\ead{kieran.o'shea@glasgow.ac.uk}",
      "#+LATEX_HEADER: \\author{Caitlyn R. Martin}",
      "#+LATEX_HEADER: \\author{Dale J. Barr}",
      "#+LATEX_HEADER: \\ead{dale.barr@glasgow.ac.uk}",
      "#+LATEX_HEADER: \\address{Institute of Neuroscience and Psychology, University of Glasgow, 62 Hillhead St., Glasgow G12 8QB, United Kingdom}",
      "#+LATEX_HEADER: \\cortext[cor1]{Corresponding author.}",
      "#+LATEX_HEADER: \\begin{abstract}\\input{abstract.txt}\\end{abstract}",
      sep = "\n")
} else {
  cat("#+OPTIONS: toc:nil num:nil ^:nil ':t ",
      "#+LATEX_CLASS: apa6",
      "#+LATEX_CLASS_OPTIONS: [natbib,doc,a4paper]",
      "#+LATEX_HEADER: \\abstract{\\input{abstract.txt}}",
      "#+LATEX_HEADER: \\threeauthors{Kieran J. O'Shea}{Caitlyn R. Martin}{Dale J. Barr}",
      "#+LATEX_HEADER: \\threeaffiliations{University of Glasgow}{University of Glasgow}{University of Glasgow}",
      "#+LATEX_HEADER: \\hypersetup{colorlinks,citecolor=black,linkcolor=black,urlcolor=blue}",
      "#+LATEX_HEADER: \\authornote{Corresponding author: Kieran J. O'Shea, Institute of Neuroscience and Psychology, University of Glasgow, 62 Hillhead St., Glasgow G12 8QB; Phone +44 (0)141 330 5089.  Thanks to David Ralston and Sophie MacAskill for assistance with pilot studies, and to Holly Branigan for comments on the PhD thesis on which this article is based. Code and data are available at https://osf.io/89g5b. This work was made possible by a Doctoral Training Fellowship to Kieran J. O'Shea from the UK Economic and Social Research Council.}",
      "#+LATEX_HEADER: \\shorttitle{Ordinary memory and referential description}",
      "#+LATEX_HEADER: \\hypersetup{colorlinks,citecolor=black,linkcolor=black,urlcolor=red}",
      sep = "\n")
}

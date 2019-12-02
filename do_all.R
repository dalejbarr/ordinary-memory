.oldwd <- getwd()

setwd("exp1")
.todo <- setdiff(dir(file.path("scripts"), "^[0-9]{2}.*\\.R$", full.names = TRUE),
                 "scripts/01_preprocess.R")
lapply(.todo, source)
setwd(.oldwd)

setwd("exp2")
.todo <- setdiff(dir(file.path("scripts"), "^[0-9]{2}.*\\.R$", full.names = TRUE),
                 "scripts/01_preprocess.R")
lapply(.todo, source)
setwd(.oldwd)

setwd("exp3")
.todo <- setdiff(dir(file.path("scripts"), "^[0-9]{2}.*\\.R$", full.names = TRUE),
                 "scripts/01_preprocess.R")
lapply(.todo, source)
setwd(.oldwd)

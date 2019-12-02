.oldwd <- getwd()

setwd("exp1")
.todo <- dir(file.path("scripts"), "^[0-9]{2}.*\\.R$", full.names = TRUE)
lapply(.todo, source)
setwd(.oldwd)

setwd("exp2")
.todo <- dir(file.path("scripts"), "^[0-9]{2}.*\\.R$", full.names = TRUE)
lapply(.todo, source)
setwd(.oldwd)

setwd("exp3")
.todo <- dir(file.path("scripts"), "^[0-9]{2}.*\\.R$", full.names = TRUE)
lapply(.todo, source)
setwd(.oldwd)

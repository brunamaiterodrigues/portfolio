# Instala pacotes R necessarios para o projeto Vitto.
# Executado uma unica vez, com autorizacao do usuario.

options(repos = c(CRAN = "https://cloud.r-project.org"))
options(timeout = 600)

# A biblioteca do sistema fica em "Program Files" e nao e gravavel sem admin.
# Por isso usamos uma biblioteca do usuario, de onde o R tambem carrega pacotes.
biblioteca_usuario <- file.path(Sys.getenv("LOCALAPPDATA"), "R", "win-library", "4.6")
dir.create(biblioteca_usuario, recursive = TRUE, showWarnings = FALSE)
.libPaths(c(biblioteca_usuario, .libPaths()))
cat("Biblioteca de instalacao:", biblioteca_usuario, "\n")

pacotes <- c(
  "readr", "dplyr", "tidyr", "lubridate", "hms", "janitor", "here",
  "ggplot2", "scales", "patchwork", "ragg", "kableExtra", "magick",
  "knitr", "rmarkdown", "renv", "tinytex", "quarto"
)

faltando <- setdiff(pacotes, rownames(installed.packages()))

if (length(faltando) > 0) {
  install.packages(faltando, dependencies = TRUE, Ncpus = 4)
}

ok <- rownames(installed.packages())
cat("\n--- VERIFICACAO ---\n")
for (p in pacotes) {
  cat(sprintf("%-12s %s\n", p, if (p %in% ok) "OK" else "FALTOU"))
}

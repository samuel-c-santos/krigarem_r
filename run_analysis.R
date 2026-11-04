# ==============================================================================
# PROJETO: Geoestatística e Análise Espacial de Fertilidade do Solo em R
# ARQUIVO: run_analysis.R
# DESCRIÇÃO: Script principal de execução amigável (ponto de entrada).
# USO NO RSTUDIO:
#   source("run_analysis.R")
# USO NO TERMINAL:
#   Rscript run_analysis.R
# ==============================================================================

# Garantir que o diretório de trabalho seja a raiz do projeto
if (!requireNamespace("here", quietly = TRUE)) {
  install.packages("here", repos = "https://cloud.r-project.org")
}

source(here::here("src", "pipeline.R"))

cat("\n====================================================================\n")
cat(" 🌱 PIPELINE GEOESTATÍSTICO DE FERTILIDADE DO SOLO EM R\n")
cat(" Fazenda São Pedro — Agricultura de Precisão (221,7 ha)\n")
cat("====================================================================\n\n")

# ------------------------------------------------------------------------------
# 1. Execução Prioritária: pH em Água (Case Principal)
# ------------------------------------------------------------------------------
res_ph <- run_soil_analysis(var_key = "pHÁgua", remove_outliers = TRUE)

# Exibição explícita na aba Plots do RStudio
cat("\n📊 Renderizando visualização na aba Plots do RStudio...\n")
print(res_ph$exports$prancha_plot)

# ------------------------------------------------------------------------------
# 2. Execução Multi-Variável (Lote Completo)
# ------------------------------------------------------------------------------
# Descomente a linha abaixo caso queira reprocessar todas as 5 variáveis de solo:
# consolidado <- run_all_soil_variables()

cat("\n✅ Processamento concluído com sucesso!")
cat("\n📁 Saídas em alta resolução disponíveis em: outputs/figures/\n")
cat("🗺️ Rasters GeoTIFF disponíveis em: outputs/rasters/\n")
cat("📊 Tabelas consolidadas disponíveis em: outputs/tables/\n\n")

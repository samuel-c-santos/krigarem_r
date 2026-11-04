# ==============================================================================
# PROJETO: Geoestatística e Análise Espacial de Fertilidade do Solo em R
# ARQUIVO: src/config.R
# DESCRIÇÃO: Centralização de parâmetros, projeções, metadados agronômicos e
#            paletas de cores para o pipeline geoestatístico multi-variável.
# ==============================================================================

# Isolar PROJ_LIB e GDAL_DATA para evitar contaminação de variáveis globais do sistema
terra_proj <- system.file("proj", package = "terra")
if (dir.exists(terra_proj)) Sys.setenv(PROJ_LIB = terra_proj)
terra_gdal <- system.file("gdal", package = "terra")
if (dir.exists(terra_gdal)) Sys.setenv(GDAL_DATA = terra_gdal)

suppressPackageStartupMessages({
  library(here)
})

# ------------------------------------------------------------------------------
# 1. Diretórios e Caminhos Base
# ------------------------------------------------------------------------------
CONFIG <- list(
  paths = list(
    data_raw    = here::here("data", "raw"),
    data_ctx    = here::here("data", "context"),
    shp_points  = here::here("data", "raw", "Analise_solo_completo.shp"),
    shp_imovel  = here::here("data", "raw", "area_imovel_utm.shp"),
    shp_estados = here::here("data", "context", "BRASIL_ESTADOS.shp"),
    out_figures = here::here("outputs", "figures"),
    out_rasters = here::here("outputs", "rasters"),
    out_tables  = here::here("outputs", "tables")
  ),
  
  # Sistema de Referência de Coordenadas Oficial: SIRGAS 2000 / UTM Zone 21S
  crs_epsg = 31981,
  crs_string = "EPSG:31981",
  
  # Parâmetros de Interpolação Geoestatística
  kriging = list(
    grid_resolution = 5,              # Resolução da malha regular (5 metros)
    models_to_test  = c("Sph", "Exp", "Gau"), # Modelos teóricos avaliados
    cutoff_factor   = 0.65            # Fração da diagonal máxima para variografia
  ),
  
  # Metadados agronômicos e classificação pedológica (SBCS / EMBRAPA)
  variables = list(
    "pHÁgua" = list(
      col_pattern  = "pH.*gua|pHAgua|phagua",
      clean_name   = "pH_Agua",
      display_name = "pH em Água",
      unit         = "pH (adimensional)",
      breaks       = c(-Inf, 5.0, 5.5, 6.0, 6.5, Inf),
      labels       = c("Muito Baixo (< 5.0)", "Baixo (5.0 - 5.5)", 
                       "Médio (5.5 - 6.0)", "Bom (6.0 - 6.5)", "Alto (> 6.5)"),
      palette      = c("#d73027", "#fc8d59", "#fee08b", "#91cf60", "#1a9850"),
      var_palette  = "YlOrRd" # Paleta para o mapa de incerteza (desvio padrão)
    ),
    "Argila%" = list(
      col_pattern  = "Argila.*|argila",
      clean_name   = "Argila_perc",
      display_name = "Teor de Argila",
      unit         = "%",
      breaks       = c(-Inf, 15, 35, 60, Inf),
      labels       = c("Arenosa (< 15%)", "Média (15 - 35%)", 
                       "Argilosa (35 - 60%)", "Muito Argilosa (> 60%)"),
      palette      = c("#ffffd4", "#fed98e", "#fe9929", "#cc4c02"),
      var_palette  = "YlOrRd"
    ),
    "V%" = list(
      col_pattern  = "^V(\\%|\\.|_)?$|^V_perc|sat_bases",
      clean_name   = "V_perc",
      display_name = "Saturação por Bases (V%)",
      unit         = "%",
      breaks       = c(-Inf, 25, 50, 70, Inf),
      labels       = c("Muito Baixo (< 25%)", "Baixo (25 - 50%)", 
                       "Médio (50 - 70%)", "Alto (> 70%)"),
      palette      = c("#e66101", "#fdb863", "#b2abd2", "#5e3c99"),
      var_palette  = "YlOrRd"
    ),
    "Pmg/dm³" = list(
      col_pattern  = "^Pmg|^P_mg|fosforo",
      clean_name   = "P_mg_dm3",
      display_name = "Fósforo Mehlich-1 (P)",
      unit         = "mg/dm³",
      breaks       = c(-Inf, 5.0, 10.0, 20.0, Inf),
      labels       = c("Muito Baixo (< 5.0)", "Baixo (5.0 - 10.0)", 
                       "Médio (10.0 - 20.0)", "Alto (> 20.0)"),
      palette      = c("#d7191c", "#fdae61", "#abd9e9", "#2c7bb6"),
      var_palette  = "YlOrRd"
    ),
    "MOg/dm³" = list(
      col_pattern  = "^MO|MOg|materia_organica",
      clean_name   = "MO_g_dm3",
      display_name = "Matéria Orgânica (MO)",
      unit         = "g/dm³",
      breaks       = c(-Inf, 15.0, 25.0, 40.0, Inf),
      labels       = c("Baixo (< 15)", "Médio (15 - 25)", 
                       "Bom (25 - 40)", "Alto (> 40)"),
      palette      = c("#edf8fb", "#b2e2e2", "#66c2a4", "#238b45"),
      var_palette  = "YlOrRd"
    )
  )
)

# Garantir existência das pastas de saída
for (p in CONFIG$paths[c("out_figures", "out_rasters", "out_tables")]) {
  if (!dir.exists(p)) dir.create(p, recursive = TRUE, showWarnings = FALSE)
}

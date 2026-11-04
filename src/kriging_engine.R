# ==============================================================================
# PROJETO: Geoestatística e Análise Espacial de Fertilidade do Solo em R
# ARQUIVO: src/kriging_engine.R
# DESCRIÇÃO: Motor de Interpolação por Krigagem Ordinária, estimativa espacial,
#            cálculo da variância/desvio-padrão de incerteza e exportação GeoTIFF.
# ==============================================================================

suppressPackageStartupMessages({
  library(sf)
  library(terra)
  library(gstat)
  library(dplyr)
})

source(here::here("src", "config.R"))

#' Executar Krigagem Ordinária e gerar rasters espaciais
#' @param pts_clean Objeto sf com dados amostrais limpos
#' @param imovel Objeto sf com o polígono limite da propriedade
#' @param best_fit Modelo de semivariograma ajustado pelo gstat
#' @param var_key Chave da variável
#' @return Lista contendo rasters (terra SpatRaster) e dataframes para plot
run_soil_kriging <- function(pts_clean, imovel, best_fit, var_key) {
  meta <- CONFIG$variables[[var_key]]
  clean_name <- if (!is.null(meta)) meta$clean_name else "variavel"
  
  # 1. Preparar malha de predição regular
  bbox_imovel <- sf::st_bbox(imovel)
  res_m <- CONFIG$kriging$grid_resolution
  
  # Coordenadas da grade
  x_coords <- seq(bbox_imovel["xmin"], bbox_imovel["xmax"], by = res_m)
  y_coords <- seq(bbox_imovel["ymin"], bbox_imovel["ymax"], by = res_m)
  grid_df  <- expand.grid(x = x_coords, y = y_coords)
  
  # Converter para sp para o gstat
  sp::coordinates(grid_df) <- ~x + y
  
  pts_sp <- as(pts_clean, "Spatial")
  sp::proj4string(grid_df) <- sp::proj4string(pts_sp)
  
  # 2. Executar Krigagem Ordinária
  message("Executando Krigagem Ordinária para: ", var_key, " (Resolução: ", res_m, " m)...")
  krig_out <- gstat::krige(
    formula = target_val ~ 1,
    locations = pts_sp,
    newdata = grid_df,
    model = best_fit,
    debug.level = 0
  )
  
  # 3. Converter para data.frame
  krig_df <- as.data.frame(krig_out)
  # Colunas: x, y, var1.pred (estimativa), var1.var (variancia)
  krig_df$var1.se <- sqrt(pmax(krig_df$var1.var, 0)) # Desvio-padrão de predição
  
  # 4. Criar SpatRasters usando o pacote moderno 'terra'
  rast_pred <- terra::rast(
    krig_df[, c("x", "y", "var1.pred")],
    type = "xyz",
    crs = CONFIG$crs_string
  )
  rast_var <- terra::rast(
    krig_df[, c("x", "y", "var1.var")],
    type = "xyz",
    crs = CONFIG$crs_string
  )
  rast_se <- terra::rast(
    krig_df[, c("x", "y", "var1.se")],
    type = "xyz",
    crs = CONFIG$crs_string
  )
  
  # 5. Mascarar pelo contorno vetorial do imóvel
  imovel_vect <- terra::vect(imovel)
  rast_pred_masked <- terra::mask(terra::crop(rast_pred, imovel_vect), imovel_vect)
  rast_se_masked   <- terra::mask(terra::crop(rast_se, imovel_vect), imovel_vect)
  
  # 6. Reclassificação Agronômica Temática (se breaks estiverem definidos)
  rast_class_masked <- NULL
  df_class <- NULL
  if (!is.null(meta) && !is.null(meta$breaks)) {
    brks <- meta$breaks
    n_classes <- length(brks) - 1
    reclass_matrix <- matrix(nrow = n_classes, ncol = 3)
    for (i in 1:n_classes) {
      reclass_matrix[i, ] <- c(brks[i], brks[i + 1], i)
    }
    rast_class_masked <- terra::classify(rast_pred_masked, reclass_matrix, right = TRUE)
    names(rast_class_masked) <- "classe"
    
    # Converter para data.frame para plotagem no ggplot
    df_class <- as.data.frame(rast_class_masked, xy = TRUE, na.rm = TRUE)
    df_class$classe_fator <- factor(
      df_class$classe,
      levels = 1:n_classes,
      labels = meta$labels
    )
  }
  
  # Data.frame contínuo para plot da estimativa e incerteza
  df_pred_cont <- as.data.frame(rast_pred_masked, xy = TRUE, na.rm = TRUE)
  colnames(df_pred_cont) <- c("x", "y", "estimativa")
  
  df_se_cont <- as.data.frame(rast_se_masked, xy = TRUE, na.rm = TRUE)
  colnames(df_se_cont) <- c("x", "y", "incerteza_se")
  
  # 7. Exportar GeoTIFFs oficiais
  path_pred_tif  <- file.path(CONFIG$paths$out_rasters, paste0("krigagem_estimativa_", clean_name, ".tif"))
  path_se_tif    <- file.path(CONFIG$paths$out_rasters, paste0("krigagem_incerteza_se_", clean_name, ".tif"))
  
  terra::writeRaster(rast_pred_masked, path_pred_tif, overwrite = TRUE)
  terra::writeRaster(rast_se_masked, path_se_tif, overwrite = TRUE)
  
  if (!is.null(rast_class_masked)) {
    path_class_tif <- file.path(CONFIG$paths$out_rasters, paste0("krigagem_classes_", clean_name, ".tif"))
    terra::writeRaster(rast_class_masked, path_class_tif, overwrite = TRUE)
  }
  
  list(
    rast_pred  = rast_pred_masked,
    rast_se    = rast_se_masked,
    rast_class = rast_class_masked,
    df_pred    = df_pred_cont,
    df_se      = df_se_cont,
    df_class   = df_class,
    paths = list(
      pred_tif  = path_pred_tif,
      se_tif    = path_se_tif
    )
  )
}

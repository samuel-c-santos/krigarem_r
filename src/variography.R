# ==============================================================================
# PROJETO: Geoestatística e Análise Espacial de Fertilidade do Solo em R
# ARQUIVO: src/variography.R
# DESCRIÇÃO: Análise variográfica, ajuste e seleção automática de modelos
#            teóricos (Esférico, Exponencial, Gaussiano) e cálculo do IDE.
# ==============================================================================

suppressPackageStartupMessages({
  library(sf)
  library(gstat)
  library(ggplot2)
  library(dplyr)
})

source(here::here("src", "config.R"))

#' Ajustar e selecionar o melhor modelo variográfico teórico
#' @param pts_clean Objeto sf com a coluna 'target_val'
#' @param display_title Nome legível da variável
#' @param unit_str Unidade de medida
#' @return Lista com 'exp_var', 'best_fit', 'model_comparison', 'ide_stats' e 'plot'
fit_soil_variogram <- function(pts_clean, display_title = "Variável", unit_str = "") {
  # Converter sf para Spatial (gstat opera de forma mais estável com sp/coordinates)
  pts_sp <- as(pts_clean, "Spatial")
  
  # Calcular extensão e cutoff seguro (65% da distância diagonal máxima)
  bbox_pts <- sf::st_bbox(pts_clean)
  diag_dist <- sqrt((bbox_pts["xmax"] - bbox_pts["xmin"])^2 + 
                    (bbox_pts["ymax"] - bbox_pts["ymin"])^2)
  cutoff_val <- as.numeric(diag_dist * CONFIG$kriging$cutoff_factor)
  
  # Semivariograma experimental (onidirecional)
  exp_var <- gstat::variogram(target_val ~ 1, data = pts_sp, cutoff = cutoff_val)
  
  # Estimativas iniciais empíricas
  sample_var <- var(pts_clean$target_val)
  init_nugget <- min(exp_var$gamma) * 0.5
  init_psill  <- max(sample_var - init_nugget, init_nugget * 0.5)
  init_range  <- cutoff_val * 0.35
  
  models_to_test <- CONFIG$kriging$models_to_test
  fitted_list <- list()
  comp_rows <- list()
  
  for (m in models_to_test) {
    tryCatch({
      v_init <- gstat::vgm(psill = init_psill, model = m, range = init_range, nugget = init_nugget)
      fit_m  <- gstat::fit.variogram(exp_var, v_init, fit.method = 7)
      
      # Obter erro quadrático (SSErr)
      sserr <- attr(fit_m, "SSErr")
      if (is.null(sserr) || is.na(sserr)) sserr <- Inf
      
      fitted_list[[m]] <- fit_m
      
      # Parâmetros
      c0 <- fit_m$psill[fit_m$model == "Nug"]
      if (length(c0) == 0) c0 <- 0
      c1 <- fit_m$psill[fit_m$model == m]
      sill <- c0 + c1
      rng  <- fit_m$range[fit_m$model == m]
      
      ide  <- (c0 / sill) * 100
      ide_classe <- if (ide <= 25) {
        "Forte (IDE <= 25%)"
      } else if (ide <= 75) {
        "Moderada (25% < IDE <= 75%)"
      } else {
        "Fraca (IDE > 75%)"
      }
      
      comp_rows[[m]] <- data.frame(
        Modelo        = m,
        Nome_Modelo   = switch(m, "Sph" = "Esférico", "Exp" = "Exponencial", "Gau" = "Gaussiano", m),
        SSErr         = sserr,
        Efeito_Pepita = round(c0, 4),
        Contribuicao  = round(c1, 4),
        Patamar       = round(sill, 4),
        Alcance_m     = round(rng, 2),
        IDE_perc      = round(ide, 2),
        Classe_IDE    = ide_classe,
        stringsAsFactors = FALSE
      )
    }, error = function(e) {
      # Ignorar falha de convergência
    })
  }
  
  if (length(comp_rows) == 0) {
    stop("Nenhum modelo variográfico convergiu satisfatoriamente.")
  }
  
  comp_df <- do.call(rbind, comp_rows)
  comp_df <- comp_df[order(comp_df$SSErr), ]
  
  best_model_name <- comp_df$Modelo[1]
  best_fit <- fitted_list[[best_model_name]]
  best_stats <- comp_df[1, ]
  
  # ----------------------------------------------------------------------------
  # Visualização Gráfica do Semivariograma com ggplot2
  # ----------------------------------------------------------------------------
  # Curva teórica
  max_dist <- max(exp_var$dist)
  dist_seq <- seq(0, max_dist * 1.05, length.out = 200)
  theo_gamma <- gstat::variogramLine(best_fit, maxdist = max(dist_seq), n = 200)
  
  p_vario <- ggplot() +
    # Pontos experimentais
    geom_point(data = exp_var, aes(x = dist, y = gamma, size = np), 
               color = "#2980b9", alpha = 0.8) +
    # Curva teórica ajustada
    geom_line(data = theo_gamma, aes(x = dist, y = gamma), 
              color = "#c0392b", linewidth = 1.1) +
    # Linhas de referência (Alcance e Patamar)
    geom_vline(xintercept = best_stats$Alcance_m, linetype = "dotted", 
               color = "#7f8c8d", linewidth = 0.7) +
    geom_hline(yintercept = best_stats$Patamar, linetype = "dashed", 
               color = "#7f8c8d", linewidth = 0.7) +
    scale_size_continuous(name = "Pares (N)", range = c(2, 5)) +
    labs(
      title = paste0("Semivariograma Experimental & Modelo Ajustado: ", display_title),
      subtitle = paste0("Modelo Teórico: ", best_stats$Nome_Modelo, 
                        " | C0: ", best_stats$Efeito_Pepita, 
                        " | C0+C1: ", best_stats$Patamar,
                        " | Alcance (a): ", best_stats$Alcance_m, " m",
                        " | IDE: ", best_stats$IDE_perc, "% (", best_stats$Classe_IDE, ")"),
      x = "Distancia de Separacao h (metros)",
      y = paste0("Semivariancia gamma(h) [", unit_str, "^2]")
    ) +
    theme_minimal(base_size = 11) +
    theme(
      plot.title = element_text(face = "bold", size = 12, color = "#1a252f"),
      plot.subtitle = element_text(size = 9, color = "#555555"),
      axis.title = element_text(face = "bold", size = 10, color = "#2c3e50"),
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(color = "#e8ecef", linewidth = 0.4),
      panel.border = element_rect(color = "#bdc3c7", fill = NA, linewidth = 0.6),
      legend.position = "right"
    )
  
  list(
    exp_var          = exp_var,
    best_fit         = best_fit,
    best_model_name  = best_model_name,
    model_comparison = comp_df,
    best_stats       = best_stats,
    plot             = p_vario
  )
}

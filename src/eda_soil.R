# ==============================================================================
# PROJETO: Geoestatística e Análise Espacial de Fertilidade do Solo em R
# ARQUIVO: src/eda_soil.R
# DESCRIÇÃO: Análise Exploratória de Dados (AED), detecção de outliers,
#            estatística descritiva e testes formais de normalidade.
# ==============================================================================

suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(ggplot2)
  library(patchwork)
  library(psych)
  library(scales)
})

source(here::here("src", "config.R"))

#' Carregar camadas espaciais e harmonizar coordenadas
#' @return Lista contendo 'pts' (pontos amostrais sf) e 'imovel' (poligono sf)
load_spatial_data <- function() {
  if (!file.exists(CONFIG$paths$shp_points)) {
    stop("Shapefile de pontos amostrais não encontrado em: ", CONFIG$paths$shp_points)
  }
  if (!file.exists(CONFIG$paths$shp_imovel)) {
    stop("Shapefile do imóvel não encontrado em: ", CONFIG$paths$shp_imovel)
  }
  
  pts <- sf::st_read(CONFIG$paths$shp_points, quiet = TRUE)
  imovel <- sf::st_read(CONFIG$paths$shp_imovel, quiet = TRUE)
  
  # Forçar CRS oficial SIRGAS 2000 UTM 21S (EPSG:31981)
  target_crs <- sf::st_crs(CONFIG$crs_epsg)
  if (sf::st_crs(pts) != target_crs) {
    pts <- sf::st_transform(pts, target_crs)
  }
  if (sf::st_crs(imovel) != target_crs) {
    imovel <- sf::st_transform(imovel, target_crs)
  }
  
  list(pts = pts, imovel = imovel)
}

#' Localizar coluna correspondente à variável no shapefile
#' @param pts Objeto sf com dados amostrais
#' @param var_key Chave da variável definida em CONFIG$variables
#' @return Nome exato da coluna encontrada no dataframe
find_variable_col <- function(pts, var_key) {
  meta <- CONFIG$variables[[var_key]]
  if (is.null(meta)) {
    # Procura direta se var_key já for o nome da coluna
    if (var_key %in% names(pts)) return(var_key)
    stop("Variável '", var_key, "' não está registrada em CONFIG$variables.")
  }
  
  col_matches <- grep(meta$col_pattern, names(pts), value = TRUE, ignore.case = TRUE)
  if (length(col_matches) == 0) {
    stop("Coluna correspondente ao padrão '", meta$col_pattern, "' não encontrada no shapefile.")
  }
  return(col_matches[1])
}

#' Executar Análise Exploratória de Dados completa para uma variável
#' @param pts Objeto sf com pontos
#' @param var_key Chave da variável
#' @param remove_outliers Booleano indicando se outliers devem ser filtrados
#' @return Lista com 'data_clean', 'stats', 'normality_test' e 'plots'
perform_eda <- function(pts, var_key, remove_outliers = TRUE) {
  col_name <- find_variable_col(pts, var_key)
  meta <- CONFIG$variables[[var_key]]
  display_title <- if (!is.null(meta)) meta$display_name else col_name
  unit_str <- if (!is.null(meta)) meta$unit else ""
  
  raw_vals <- as.numeric(pts[[col_name]])
  valid_idx <- !is.na(raw_vals)
  pts_valid <- pts[valid_idx, ]
  vals <- raw_vals[valid_idx]
  
  # Identificação de outliers via critério de Tukey (Boxplot IQR)
  bp_stats <- boxplot.stats(vals)
  outliers <- bp_stats$out
  has_outliers <- length(outliers) > 0
  
  if (remove_outliers && has_outliers) {
    keep_mask <- !(vals %in% outliers)
    vals_clean <- vals[keep_mask]
    pts_clean <- pts_valid[keep_mask, ]
  } else {
    vals_clean <- vals
    pts_clean <- pts_valid
  }
  
  # Adicionar coluna limpa padronizada
  pts_clean$target_val <- vals_clean
  
  # Estatísticas Descritivas
  n_total <- length(vals_clean)
  v_mean  <- mean(vals_clean)
  v_sd    <- sd(vals_clean)
  v_cv    <- (v_sd / v_mean) * 100
  v_med   <- median(vals_clean)
  v_min   <- min(vals_clean)
  v_max   <- max(vals_clean)
  v_skew  <- psych::skew(vals_clean)
  v_kurt  <- psych::kurtosi(vals_clean)
  
  # Classificação do CV segundo Warrick & Nielsen (1980)
  cv_class <- if (v_cv <= 12) {
    "Baixa (CV <= 12%)"
  } else if (v_cv <= 60) {
    "Média (12% < CV <= 60%)"
  } else {
    "Alta (CV > 60%)"
  }
  
  # Teste de Normalidade de Shapiro-Wilk
  shapiro_res <- shapiro.test(vals_clean)
  is_normal <- shapiro_res$p.value > 0.05
  
  stats_df <- data.frame(
    Variavel          = display_title,
    Unidade           = unit_str,
    N_Amostras        = n_total,
    Outliers_Removidos= length(outliers),
    Media             = round(v_mean, 3),
    Desvio_Padrao     = round(v_sd, 3),
    CV_perc           = round(v_cv, 2),
    Classe_CV         = cv_class,
    Mediana           = round(v_med, 3),
    Minimo            = round(v_min, 3),
    Maximo            = round(v_max, 3),
    Assimetria        = round(v_skew, 3),
    Curtose           = round(v_kurt, 3),
    Shapiro_W         = round(shapiro_res$statistic, 4),
    Shapiro_p_valor   = round(shapiro_res$p.value, 5),
    Distribuicao      = ifelse(is_normal, "Normal (p > 0.05)", "Não-Normal (p <= 0.05)"),
    stringsAsFactors  = FALSE
  )
  
  # ----------------------------------------------------------------------------
  # Visualização Gráfica de Alto Padrão (ggplot2 + patchwork)
  # ----------------------------------------------------------------------------
  theme_clean <- theme_minimal(base_size = 11) +
    theme(
      plot.title = element_text(face = "bold", size = 12, color = "#1a252f"),
      plot.subtitle = element_text(size = 9, color = "#555555"),
      axis.title = element_text(face = "bold", size = 10, color = "#2c3e50"),
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(color = "#e8ecef", linewidth = 0.4),
      panel.border = element_rect(color = "#bdc3c7", fill = NA, linewidth = 0.6)
    )
  
  df_plot <- data.frame(val = vals_clean)
  
  # A) Histograma com Curva de Densidade Normal
  p_hist <- ggplot(df_plot, aes(x = val)) +
    geom_histogram(aes(y = after_stat(density)), bins = 15,
                   fill = "#3498db", color = "#1f618d", alpha = 0.75, linewidth = 0.4) +
    geom_density(color = "#2c3e50", linewidth = 0.9, linetype = "solid") +
    stat_function(fun = dnorm, args = list(mean = v_mean, sd = v_sd),
                  color = "#e74c3c", linewidth = 0.9, linetype = "dashed") +
    labs(
      title = paste0("Distribuição de Frequência: ", display_title),
      subtitle = paste0("N = ", n_total, " | Média: ", round(v_mean, 2), " | DP: ", round(v_sd, 2),
                        " | Linha Vermelha: Densidade Normal Teórica"),
      x = paste0(display_title, " (", unit_str, ")"),
      y = "Densidade"
    ) +
    theme_clean
  
  # B) Boxplot com marcação de Média e Quartis
  p_box <- ggplot(df_plot, aes(y = val, x = "")) +
    geom_boxplot(fill = "#2ecc71", color = "#27ae60", alpha = 0.7, 
                 width = 0.35, outlier.color = "#c0392b", outlier.shape = 16) +
    stat_summary(fun = mean, geom = "point", shape = 18, size = 3.5, color = "#d35400") +
    labs(
      title = "Boxplot & Dispersão",
      subtitle = paste0("Mediana: ", round(v_med, 2), " | Losango Laranja: Média (", round(v_mean, 2), ")"),
      x = "",
      y = paste0(display_title, " (", unit_str, ")")
    ) +
    theme_clean
  
  # C) Q-Q Plot Normal
  p_qq <- ggplot(df_plot, aes(sample = val)) +
    stat_qq(color = "#2980b9", alpha = 0.85, size = 1.8) +
    stat_qq_line(color = "#c0392b", linewidth = 0.9) +
    labs(
      title = "Gráfico Q-Q Normal (Quantil-Quantil)",
      subtitle = paste0("Shapiro-Wilk W = ", round(shapiro_res$statistic, 3), 
                        " (p = ", format.pval(shapiro_res$p.value, digits = 3), ")"),
      x = "Quantis Teóricos Normais",
      y = "Quantis Amostrais Observados"
    ) +
    theme_clean
  
  # Painel Integrado
  panel_eda <- (p_hist | (p_box / p_qq)) +
    plot_layout(widths = c(1.3, 1)) +
    plot_annotation(
      title = paste0("Diagnóstico Exploratório de Solo: ", display_title),
      subtitle = "Fazenda São Pedro — SIRGAS 2000 UTM Zone 21S",
      theme = theme(
        plot.title = element_text(face = "bold", size = 14, hjust = 0.5, color = "#1a252f"),
        plot.subtitle = element_text(size = 11, hjust = 0.5, color = "#7f8c8d")
      )
    )
  
  list(
    pts_clean      = pts_clean,
    stats          = stats_df,
    shapiro_result = shapiro_res,
    plots          = list(hist = p_hist, box = p_box, qq = p_qq, panel = panel_eda),
    col_name       = col_name,
    display_title  = display_title,
    unit           = unit_str
  )
}

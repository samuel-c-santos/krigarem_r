# ==============================================================================
# PROJETO: Geoestatística e Análise Espacial de Fertilidade do Solo em R
# ARQUIVO: src/cartography.R
# DESCRIÇÃO: Motor de renderização cartográfica de alto nível, mapas temáticos,
#            mapas de incerteza da krigagem com quadro quadrado (aspect ratio 1:1),
#            exibição interativa no RStudio e pranchas analíticas completas (300 DPI).
# ==============================================================================

suppressPackageStartupMessages({
  library(sf)
  library(ggplot2)
  library(patchwork)
  library(ggspatial)
  library(viridis)
  library(scales)
})

source(here::here("src", "config.R"))

#' Calcular Bounding Box perfeitamente quadrado (aspect ratio 1:1) com margem
#' @param sf_geom Objeto sf (limite do imóvel)
#' @param pad_ratio Proporção de margem em relação à maior dimensão
#' @return Lista contendo vetores 'xlim' e 'ylim' com dimensões idênticas
get_square_bbox <- function(sf_geom, pad_ratio = 0.08) {
  bbox <- sf::st_bbox(sf_geom)
  dx <- as.numeric(bbox["xmax"] - bbox["xmin"])
  dy <- as.numeric(bbox["ymax"] - bbox["ymin"])
  cx <- as.numeric((bbox["xmin"] + bbox["xmax"]) / 2)
  cy <- as.numeric((bbox["ymin"] + bbox["ymax"]) / 2)
  
  max_dim <- max(dx, dy)
  half_dim <- (max_dim / 2) * (1 + pad_ratio)
  
  list(
    xlim = c(cx - half_dim, cx + half_dim),
    ylim = c(cy - half_dim, cy + half_dim)
  )
}

#' Gerar Mapa Temático Principal da Krigagem (Quadro Quadrado 1:1)
#' @param krig_res Resultado retornado por run_soil_kriging
#' @param pts_clean Pontos amostrais
#' @param imovel Limite do imóvel
#' @param var_key Chave da variável
#' @return Objeto ggplot2 pronto para exibição e salvamento
plot_kriging_map <- function(krig_res, pts_clean, imovel, var_key) {
  meta <- CONFIG$variables[[var_key]]
  display_title <- if (!is.null(meta)) meta$display_name else var_key
  unit_str      <- if (!is.null(meta)) meta$unit else ""
  
  # Bounding box quadrado harmônico
  sq_lims <- get_square_bbox(imovel, pad_ratio = 0.08)
  
  p <- ggplot()
  
  # Se houver classes agronômicas definidas, usar df_class
  if (!is.null(krig_res$df_class)) {
    p <- p +
      geom_tile(data = krig_res$df_class, aes(x = x, y = y, fill = classe_fator)) +
      scale_fill_manual(
        name = paste0("Classes Agronômicas\n(", unit_str, ")"),
        values = meta$palette,
        drop = FALSE
      )
  } else {
    # Gradiente contínuo viridis
    p <- p +
      geom_tile(data = krig_res$df_pred, aes(x = x, y = y, fill = estimativa)) +
      scale_fill_viridis_c(
        name = paste0(display_title, "\n(", unit_str, ")"),
        option = "viridis"
      )
  }
  
  p <- p +
    # Limite do Imóvel
    geom_sf(data = imovel, fill = NA, color = "#1a252f", linewidth = 1.0) +
    # Pontos de amostragem de solo
    geom_sf(data = pts_clean, shape = 21, fill = "#ffffff", color = "#2c3e50", 
            size = 1.6, stroke = 0.6, alpha = 0.9) +
    coord_sf(
      xlim = sq_lims$xlim,
      ylim = sq_lims$ylim,
      expand = FALSE,
      datum = sf::st_crs(CONFIG$crs_epsg)
    ) +
    # Elementos Cartográficos Oficiais
    ggspatial::annotation_scale(
      location = "bl", 
      width_hint = 0.35, 
      text_cex = 0.75,
      style = "ticks",
      line_col = "#2c3e50",
      text_col = "#2c3e50"
    ) +
    ggspatial::annotation_north_arrow(
      location = "tr", 
      which_north = "true",
      pad_x = unit(0.2, "in"), 
      pad_y = unit(0.2, "in"),
      style = ggspatial::north_arrow_fancy_orienteering(
        fill = c("#2c3e50", "#ffffff"),
        line_col = "#2c3e50"
      ),
      height = unit(1.1, "cm"),
      width = unit(1.1, "cm")
    ) +
    labs(
      title = paste0("Krigagem Ordinária: ", display_title),
      subtitle = "Fazenda São Pedro (221,7 ha) | SIRGAS 2000 UTM Zone 21S",
      caption = "Elaboração: Pipeline Geoestatístico em R | Grade: 5 m",
      x = "Coordenada Leste (UTM X - m)",
      y = "Coordenada Norte (UTM Y - m)"
    ) +
    theme_bw(base_size = 11) +
    theme(
      aspect.ratio = 1, # FORÇA QUADRO RIGOROSAMENTE QUADRADO (1:1)
      plot.title = element_text(face = "bold", size = 12.5, color = "#1a252f"),
      plot.subtitle = element_text(size = 9, color = "#555555"),
      plot.caption = element_text(size = 7.5, color = "#7f8c8d", face = "italic"),
      axis.title = element_text(face = "bold", size = 9, color = "#2c3e50"),
      axis.text = element_text(size = 7.5, color = "#333333"),
      panel.grid.major = element_line(color = "#dcdde1", linewidth = 0.3, linetype = "dashed"),
      legend.background = element_rect(fill = alpha("#ffffff", 0.9), color = "#bdc3c7", linewidth = 0.4),
      legend.title = element_text(face = "bold", size = 8.5),
      legend.text = element_text(size = 7.5)
    )
  
  return(p)
}

#' Gerar Mapa de Incerteza Geoestatística (Quadro Quadrado 1:1)
#' @param krig_res Resultado de run_soil_kriging
#' @param pts_clean Pontos amostrais
#' @param imovel Limite do imóvel
#' @param var_key Chave da variável
#' @return Objeto ggplot2
plot_uncertainty_map <- function(krig_res, pts_clean, imovel, var_key) {
  meta <- CONFIG$variables[[var_key]]
  display_title <- if (!is.null(meta)) meta$display_name else var_key
  unit_str      <- if (!is.null(meta)) meta$unit else ""
  
  sq_lims <- get_square_bbox(imovel, pad_ratio = 0.08)
  
  p_se <- ggplot() +
    geom_tile(data = krig_res$df_se, aes(x = x, y = y, fill = incerteza_se)) +
    scale_fill_viridis_c(
      name = paste0("Desvio Padrão (SE)\n(", unit_str, ")"),
      option = "magma",
      direction = -1
    ) +
    geom_sf(data = imovel, fill = NA, color = "#1a252f", linewidth = 1.0) +
    geom_sf(data = pts_clean, shape = 3, color = "#2c3e50", size = 1.3, alpha = 0.7) +
    coord_sf(
      xlim = sq_lims$xlim,
      ylim = sq_lims$ylim,
      expand = FALSE,
      datum = sf::st_crs(CONFIG$crs_epsg)
    ) +
    ggspatial::annotation_scale(
      location = "bl", 
      width_hint = 0.35, 
      text_cex = 0.7,
      style = "ticks",
      line_col = "#2c3e50"
    ) +
    ggspatial::annotation_north_arrow(
      location = "tr", 
      which_north = "true",
      style = ggspatial::north_arrow_minimal(),
      height = unit(0.9, "cm"),
      width = unit(0.9, "cm")
    ) +
    labs(
      title = paste0("Incerteza da Interpolação: ", display_title),
      subtitle = "Erro Padrão da Predição (Kriging Standard Error - SE)",
      caption = "Tons claros indicam maior precisão (proximidade amostral)",
      x = "Coordenada Leste (UTM X - m)",
      y = "Coordenada Norte (UTM Y - m)"
    ) +
    theme_bw(base_size = 11) +
    theme(
      aspect.ratio = 1, # FORÇA QUADRO RIGOROSAMENTE QUADRADO (1:1)
      plot.title = element_text(face = "bold", size = 12, color = "#1a252f"),
      plot.subtitle = element_text(size = 9, color = "#555555"),
      plot.caption = element_text(size = 7.5, color = "#7f8c8d", face = "italic"),
      axis.title = element_text(face = "bold", size = 9, color = "#2c3e50"),
      axis.text = element_text(size = 7.5),
      panel.grid.major = element_line(color = "#dcdde1", linewidth = 0.3, linetype = "dashed"),
      legend.background = element_rect(fill = alpha("#ffffff", 0.9), color = "#bdc3c7", linewidth = 0.4),
      legend.title = element_text(face = "bold", size = 8.5),
      legend.text = element_text(size = 7.5)
    )
  
  return(p_se)
}

#' Montar, Salvar e Exibir Prancha Executiva Multipainel (300 DPI + RStudio Plots)
#' @param p_krig Mapa temático principal
#' @param p_se Mapa de incerteza
#' @param p_vario Gráfico do semivariograma
#' @param p_eda Painel de EDA (histograma + boxplot)
#' @param var_key Chave da variável
#' @return Lista contendo os caminhos exportados e o objeto da prancha
export_executive_board <- function(p_krig, p_se, p_vario, p_eda, var_key) {
  meta <- CONFIG$variables[[var_key]]
  clean_name <- if (!is.null(meta)) meta$clean_name else "variavel"
  
  # Composição em painel 2x2 com proporção harmônica via patchwork
  prancha <- (p_krig | p_se) / (p_vario | p_eda) +
    plot_layout(heights = c(1.25, 1)) +
    plot_annotation(
      title = paste0("DIAGNÓSTICO GEOESTATÍSTICO E PEDOLÓGICO: ", toupper(if (!is.null(meta)) meta$display_name else var_key)),
      subtitle = "Fazenda São Pedro — Agricultura de Precisão | SIRGAS 2000 UTM Zone 21S (EPSG:31981)",
      theme = theme(
        plot.title = element_text(face = "bold", size = 15, hjust = 0.5, color = "#1a252f"),
        plot.subtitle = element_text(size = 11, hjust = 0.5, color = "#555555", margin = margin(b = 8))
      )
    )
  
  # ----------------------------------------------------------------------------
  # EXIBIÇÃO NO RSTUDIO (PAINEL PLOTS / VIEWER)
  # ----------------------------------------------------------------------------
  tryCatch({
    print(prancha)
  }, error = function(e) {
    # Em ambientes headless/CI, segue sem interromper
  })
  
  # Caminhos de exportação
  out_prancha <- file.path(CONFIG$paths$out_figures, paste0("prancha_completa_", clean_name, ".png"))
  out_mapa    <- file.path(CONFIG$paths$out_figures, paste0("mapa_krigagem_", clean_name, ".png"))
  out_se      <- file.path(CONFIG$paths$out_figures, paste0("mapa_incerteza_se_", clean_name, ".png"))
  out_vario   <- file.path(CONFIG$paths$out_figures, paste0("semivariograma_", clean_name, ".png"))
  
  message("Salvando prancha executiva em 300 DPI: ", out_prancha)
  # Dimensões calibradas para a composição 2x2 com mapas quadrados
  ggsave(out_prancha, plot = prancha, width = 16, height = 13.5, dpi = 300)
  
  # Mapas individuais com aspecto quadrado perfeito (9x9 polegadas)
  ggsave(out_mapa,  plot = p_krig,  width = 9, height = 9, dpi = 300)
  ggsave(out_se,    plot = p_se,    width = 9, height = 9, dpi = 300)
  ggsave(out_vario, plot = p_vario, width = 8, height = 6, dpi = 300)
  
  list(
    prancha      = out_prancha,
    mapa         = out_mapa,
    se           = out_se,
    vario        = out_vario,
    prancha_plot = prancha
  )
}

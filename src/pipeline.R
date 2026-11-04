# ==============================================================================
# PROJETO: Geoestatística e Análise Espacial de Fertilidade do Solo em R
# ARQUIVO: src/pipeline.R
# DESCRIÇÃO: Orquestrador ponta a ponta para análise univariada e em lote
#            de atributos físico-químicos de solo.
# ==============================================================================

suppressPackageStartupMessages({
  library(sf)
  library(terra)
  library(dplyr)
})

source(here::here("src", "config.R"))
source(here::here("src", "eda_soil.R"))
source(here::here("src", "variography.R"))
source(here::here("src", "kriging_engine.R"))
source(here::here("src", "cartography.R"))

#' Executar análise completa para um atributo de solo
#' @param var_key Nome ou chave da variável (ex: 'pHÁgua', 'Argila%', 'V%', 'Pmg/dm³', 'MOg/dm³')
#' @param remove_outliers Booleano para remoção de outliers na AED
#' @return Lista completa com resultados estatísticos, geoestatísticos e caminhos gerados
run_soil_analysis <- function(var_key = "pHÁgua", remove_outliers = TRUE) {
  cat("\n==============================================================================\n")
  cat(" INICIANDO PIPELINE GEOESTATÍSTICO: ", var_key, "\n")
  cat("==============================================================================\n")
  
  meta <- CONFIG$variables[[var_key]]
  clean_name <- if (!is.null(meta)) meta$clean_name else "variavel"
  
  # 1. Carregar Dados
  cat("[1/5] Carregando e validando camadas espaciais (SIRGAS 2000 UTM 21S)...\n")
  sp_data <- load_spatial_data()
  pts    <- sp_data$pts
  imovel <- sp_data$imovel
  
  # 2. Análise Exploratória de Dados
  cat("[2/5] Executando Análise Exploratória de Dados (AED)...\n")
  eda_res <- perform_eda(pts, var_key = var_key, remove_outliers = remove_outliers)
  
  # Salvar tabela de estatísticas descritivas
  path_stats_csv <- file.path(CONFIG$paths$out_tables, paste0("estatisticas_", clean_name, ".csv"))
  write.csv(eda_res$stats, path_stats_csv, row.names = FALSE, fileEncoding = "UTF-8")
  cat("      -> Tabela de estatísticas salva em: ", path_stats_csv, "\n")
  
  # 3. Modelagem Geoestatística e Variografia
  cat("[3/5] Modelando Semivariograma e selecionando melhor ajuste teórico...\n")
  vario_res <- fit_soil_variogram(
    pts_clean     = eda_res$pts_clean,
    display_title = eda_res$display_title,
    unit_str      = eda_res$unit
  )
  
  # Salvar comparação de modelos e IDE
  path_vario_csv <- file.path(CONFIG$paths$out_tables, paste0("modelagem_geoestatistica_", clean_name, ".csv"))
  write.csv(vario_res$model_comparison, path_vario_csv, row.names = FALSE, fileEncoding = "UTF-8")
  cat("      -> Melhor modelo selecionado: ", vario_res$best_stats$Nome_Modelo, 
      " (Alcance: ", vario_res$best_stats$Alcance_m, " m | IDE: ", vario_res$best_stats$IDE_perc, "%)\n")
  
  # 4. Interpolação Espacial por Krigagem Ordinária
  cat("[4/5] Interpolando malha de 5m por Krigagem Ordinária...\n")
  krig_res <- run_soil_kriging(
    pts_clean = eda_res$pts_clean,
    imovel    = imovel,
    best_fit  = vario_res$best_fit,
    var_key   = var_key
  )
  
  # 5. Renderização Cartográfica e Prancha Executiva
  cat("[5/5] Renderizando pranchas cartográficas em 300 DPI...\n")
  p_krig  <- plot_kriging_map(krig_res, eda_res$pts_clean, imovel, var_key)
  p_se    <- plot_uncertainty_map(krig_res, eda_res$pts_clean, imovel, var_key)
  p_vario <- vario_res$plot
  p_eda   <- eda_res$plots$hist / eda_res$plots$box
  
  export_paths <- export_executive_board(p_krig, p_se, p_vario, p_eda, var_key)
  
  cat("\n>>> PROCESSO CONCLUÍDO COM SUCESSO PARA: ", var_key, " <<<\n")
  cat("    Prancha Completa: ", export_paths$prancha, "\n")
  cat("    Mapa de Krigagem: ", export_paths$mapa, "\n")
  cat("    Mapa de Incerteza:", export_paths$se, "\n")
  cat("    GeoTIFF Predição: ", krig_res$paths$pred_tif, "\n\n")
  
  invisible(list(
    eda       = eda_res,
    vario     = vario_res,
    kriging   = krig_res,
    maps      = list(krig = p_krig, se = p_se),
    exports   = export_paths
  ))
}

#' Executar análise em lote para todas as variáveis configuradas
#' @return Dataframe consolidado com o resumo comparativo de todos os atributos
run_all_soil_variables <- function() {
  var_keys <- names(CONFIG$variables)
  cat("\n==============================================================================\n")
  cat(" EXECUTANDO ANÁLISE GEOESTATÍSTICA MULTI-VARIÁVEL (LOTE)\n")
  cat(" Variáveis:", paste(var_keys, collapse = ", "), "\n")
  cat("==============================================================================\n")
  
  summary_list <- list()
  
  for (vk in var_keys) {
    tryCatch({
      res <- run_soil_analysis(var_key = vk)
      
      row_summary <- data.frame(
        Variavel      = res$eda$display_title,
        Unidade       = res$eda$unit,
        Media         = res$eda$stats$Media,
        Desvio_Padrao = res$eda$stats$Desvio_Padrao,
        CV_perc       = res$eda$stats$CV_perc,
        Classe_CV     = res$eda$stats$Classe_CV,
        Normalidade   = res$eda$stats$Distribuicao,
        Melhor_Modelo = res$vario$best_stats$Nome_Modelo,
        Alcance_m     = res$vario$best_stats$Alcance_m,
        IDE_perc      = res$vario$best_stats$IDE_perc,
        Classe_IDE    = res$vario$best_stats$Classe_IDE,
        stringsAsFactors = FALSE
      )
      summary_list[[vk]] <- row_summary
    }, error = function(e) {
      cat("ERRO ao processar variável '", vk, "': ", e$message, "\n")
    })
  }
  
  consolidated_df <- do.call(rbind, summary_list)
  path_summary <- file.path(CONFIG$paths$out_tables, "consolidado_atributos_solo.csv")
  write.csv(consolidated_df, path_summary, row.names = FALSE, fileEncoding = "UTF-8")
  cat(">>> Resumo consolidado salvo em:", path_summary, "<<<\n\n")
  
  return(consolidated_df)
}

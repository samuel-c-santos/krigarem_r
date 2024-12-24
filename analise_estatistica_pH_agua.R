# ----------------------------------
# Configuração inicial
# ----------------------------------
# Definir caminho padrão
setwd("G:/Meu Drive/UFRA/SOL 24/")

# Carregar pacotes necessários
library(sf)
library(dplyr)
library(psych)
library(ggplot2)
library(raster)
library(gstat)
library(MASS)
library(ggspatial)
library(gt)

# ----------------------------------
# Importação e exploração inicial dos dados
# ----------------------------------
# Importar shapefiles
limite <- st_read("./imovel/area_imovel_utm.shp")
camada <- st_read("./imovel/Analise_solo_completo.shp")

# Verificar projeções e garantir consistência
if (!st_crs(camada) == st_crs(limite)) {
  limite <- st_transform(limite, st_crs(camada))
}

# Seleção da variável relevante a partir de camada
variaveis <- camada %>%
  st_drop_geometry() %>%
  as.data.frame()  # Garante que é um data.frame

# Seleção da variável de interesse
variaveis <- variaveis[, c("pHÁgua"), drop = FALSE]

# Renomear a coluna para facilitar
colnames(variaveis) <- c("pHÁgua")

# Preservar os dados originais para comparações futuras
variaveis$pHÁgua_original <- variaveis$pHÁgua

# Remover os outliers da variável "pHÁgua"
variaveis <- variaveis %>%
  filter(!pHÁgua %in% boxplot.stats(pHÁgua)$out)

# Estatísticas básicas e detalhadas
summary(variaveis)
describe(variaveis)

# ----------------------------------
# Estatísticas descritivas como tabela
# ----------------------------------

# Gerar estatísticas descritivas
estatisticas <- describe(variaveis$pHÁgua) %>%
  as.data.frame()

# Gerar tabela estilizada com pacote gt


tabela_estatisticas <- estatisticas %>%
  gt() %>%
  tab_header(
    title = "Estatísticas Descritivas",
    subtitle = "Variável pHÁgua"
  ) %>%
  fmt_number(
    columns = vars(mean, sd, median, min, max, skew, kurtosis),
    decimals = 2
  ) %>%
  cols_label(
    vars = "Estatísticas",
    n = "N",
    mean = "Média",
    sd = "Desvio Padrão",
    median = "Mediana",
    mad = "MAD",
    min = "Mínimo",
    max = "Máximo",
    skew = "Assimetria",
    kurtosis = "Curtose",
    se = "Erro Padrão"
  )
print(tabela_estatisticas)

# ----------------------------------
# Teste de normalidade como tabela
# ----------------------------------

# Realizar o teste de Shapiro-Wilk
teste_normalidade <- shapiro.test(variaveis$pHÁgua)

# Criar tabela para o resultado do teste de normalidade
tabela_normalidade <- data.frame(
  Estatística = teste_normalidade$statistic,
  p_valor = teste_normalidade$p.value
) %>%
  gt() %>%
  tab_header(
    title = "Teste de Normalidade (Shapiro-Wilk)",
    subtitle = "Variável pHÁgua"
  ) %>%
  fmt_number(
    columns = vars(Estatística, p_valor),
    decimals = 4
  )
print(tabela_normalidade)

# ----------------------------------
# Visualização Gráfica
# ----------------------------------

# Histogramas
histograma <- ggplot(variaveis, aes(x = pHÁgua)) +
  geom_histogram(binwidth = 0.1, fill = "skyblue", color = "black", alpha = 0.7) +
  theme_minimal() +
  labs(title = "Histograma de pHÁgua", x = "pHÁgua", y = "Frequência")

print(histograma)

# Boxplot
boxplot <- ggplot(variaveis, aes(y = pHÁgua, x = "")) +
  geom_boxplot(fill = "lightgreen", color = "black", alpha = 0.7) +
  theme_minimal() +
  labs(title = "Boxplot de pHÁgua", x = "", y = "pHÁgua")

print(boxplot)

# QQ-Plot
qqplot <- ggplot(data = variaveis, aes(sample = pHÁgua)) +
  stat_qq(color = "blue") +
  stat_qq_line(color = "red") +
  theme_minimal() +
  labs(title = "QQ-Plot de pHÁgua", x = "Teóricos", y = "Amostra")

print(qqplot)


# ----------------------------------
# Análise Variográfica
# ----------------------------------

# Converter camada para formato Spatial
camada_sp <- as(camada, "Spatial")

# Criar semivariograma experimental
variogram_model <- variogram(pHÁgua ~ 1, data = camada_sp)

# Ajustar modelo teórico ao semivariograma
fit_model <- fit.variogram(
  variogram_model,
  model = vgm(psill = 0.5, model = "Sph", nugget = 0.1, range = 500)
)

# Visualizar semivariograma ajustado
plot(variogram_model, fit_model, main = "Semivariograma de pHÁgua")

# ----------------------------------
# Interpolação por Krigagem
# ----------------------------------

# Ajustar a grade para a extensão do polígono limite
extent_limite <- extent(st_bbox(limite))  # Extensão do limite
res <- 5  # Resolução da grade (ajuste conforme necessário)
grid <- raster(extent_limite, res = res) %>%
  as("SpatialPixelsDataFrame")
proj4string(grid) <- st_crs(limite)$proj4string  # Garantir mesma projeção do limite

# Realizar a krigagem
krig_result <- krige(pHÁgua ~ 1, camada_sp, grid, model = fit_model)

# Converter resultado para raster
krig_raster <- rasterFromXYZ(as.data.frame(krig_result, xy = TRUE))
proj4string(krig_raster) <- st_crs(limite)$proj4string  # Ajustar projeção do raster

# Recortar o raster pelo polígono limite
grid_cortado <- mask(krig_raster, limite)

# Definir matriz de reclassificação
reclass_matrix <- matrix(c(
  -Inf, 5.5, 1,  # Classe 1: valores menores que 5.5
  5.5, 6.0, 2,   # Classe 2: valores entre 5.5 e 6.0
  6.0, 6.5, 3,   # Classe 3: valores entre 6.0 e 6.5
  6.5, Inf, 4    # Classe 4: valores maiores que 6.5
), ncol = 3, byrow = TRUE)

# Aplicar a reclassificação
krig_raster_reclass <- reclassify(grid_cortado, reclass_matrix)

# Converter raster reclassificado para data.frame
krig_df_reclass <- as.data.frame(krig_raster_reclass, xy = TRUE, na.rm = TRUE)
colnames(krig_df_reclass) <- c("x", "y", "class")

# ----------------------------------
# Visualização do Resultado da Krigagem
# ----------------------------------

# Criar rótulos e paleta de cores para as classes
class_labels <- c("Muito baixo", "Baixo", "Moderado", "Alto")
class_colors <- c("#ffffcc", "#a1dab4", "#41b6c4", "#225ea8")

# Ajustar limites do mapa para manter aspecto quadrado
bbox_limite <- st_bbox(limite)

# Calcular a diferença máxima entre longitude e latitude
range_x <- bbox_limite["xmax"] - bbox_limite["xmin"]
range_y <- bbox_limite["ymax"] - bbox_limite["ymin"]
range_max <- max(range_x, range_y)

# Ajustar limites para garantir quadro quadrado
bbox_limite["xmin"] <- bbox_limite["xmin"] - (range_max - range_x) / 2
bbox_limite["xmax"] <- bbox_limite["xmax"] + (range_max - range_x) / 2
bbox_limite["ymin"] <- bbox_limite["ymin"] - (range_max - range_y) / 2
bbox_limite["ymax"] <- bbox_limite["ymax"] + (range_max - range_y) / 2

# Gerar o mapa com grade de coordenadas uniforme e quadro quadrado
ggplot() +
  geom_tile(data = krig_df_reclass, aes(x = x, y = y, fill = factor(class))) +
  scale_fill_manual(
    values = class_colors,
    breaks = 1:4,
    labels = class_labels,
    name = "Classes de pHÁgua"
  ) +
  geom_sf(data = limite, fill = NA, color = "black", size = 0.8) +
  coord_sf(
    xlim = c(bbox_limite["xmin"], bbox_limite["xmax"]),
    ylim = c(bbox_limite["ymin"], bbox_limite["ymax"]),
    expand = FALSE  # Garante que o quadro seja ajustado exatamente ao bbox
  ) +
  theme_minimal() +
  theme(
    panel.grid.major = element_line(color = "gray", linetype = "dashed"),  # Grade de coordenadas
    aspect.ratio = 1  # Força aspecto quadrado
  ) +
  labs(
    title = "Mapa de Krigagem Classificado (pHÁgua)",
    x = "Longitude",
    y = "Latitude"
  ) +
  annotation_scale(location = "bl", width_hint = 0.5) +
  annotation_north_arrow(location = "tr", style = north_arrow_fancy_orienteering)

# ----------------------------------
# Exportar o Raster como GeoTIFF
# ----------------------------------

# Garantir que o raster está na projeção correta (EPSG:31981)
crs_sirgas_utm <- CRS("+init=epsg:31981")  # Define a projeção usando o EPSG

if (!compareCRS(crs(krig_raster), crs_sirgas_utm)) {
  krig_raster <- projectRaster(krig_raster, crs = crs_sirgas_utm)
}

# Caminho para exportação
output_path <- "./saida/raster_krigagem.tif"

# Exportar o raster como GeoTIFF
writeRaster(krig_raster, filename = output_path, format = "GTiff", overwrite = TRUE)

# Mensagem de sucesso
cat("Raster de krigagem exportado com sucesso para:", output_path, "\n")


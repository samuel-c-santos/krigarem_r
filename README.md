## 📂 Estrutura do Projeto

- **imovel/**: Contém os shapefiles de análise, como o limite da área e os pontos de coleta.
- **localizacao/**: Camadas geográficas adicionais para contexto, como limites municipais e estaduais.
- **saida/**: Arquivos de saída, incluindo gráficos, mapas e o raster interpolado.
- **analise_estatistica_pH_agua.R**: Script principal para análise estatística e geoestatística.

---

## 📊 Visualizações

### Histogramas e Boxplots
![Histogramas](saida/histograma.png)
![Boxplots](saida/boxplot.png)
![QQ-Plot](saida/qqplot.png)

### Resultado da Krigagem
![Krigagem do Parâmetro pHÁgua](saida/Krigagem%20do%20parâmetro%20phagua.png)

### Semivariograma Ajustado
![Semivariograma pHÁgua](saida/Semivariograma%20de%20phagua)

### Mapa de Localização
![Mapa de Localização](saida/mapa_final_layout.png)

---

## 🔄 Fluxo de Trabalho

1. **Importação de Dados**
   - Carregar os shapefiles da área de estudo.
   - Verificar e ajustar projeções espaciais.

2. **Análise Estatística**
   - Remoção de outliers utilizando estatísticas robustas.
   - Geração de estatísticas descritivas e teste de normalidade (Shapiro-Wilk).

3. **Análise Variográfica**
   - Criação de semivariograma experimental.
   - Ajuste de um modelo teórico esférico.

4. **Interpolação por Krigagem**
   - Interpolação espacial dos valores de pHÁgua utilizando o modelo ajustado.
   - Classificação do raster em quatro categorias:
     - Muito Baixo: < 5.5
     - Baixo: 5.5–6.0
     - Moderado: 6.0–6.5
     - Alto: > 6.5

5. **Exportação e Visualização**
   - Exportação do raster final como GeoTIFF.
   - Criação de mapas finais para apresentação.

---

## 📈 Estatísticas

- **Teste de Normalidade (Shapiro-Wilk)**: Estatísticas e valor p calculados.
- **Estatísticas Descritivas**:
  - Média, Desvio Padrão, Mediana, Mínimo e Máximo.
  - Assimetria e Curtose.

---

## 🗺️ Ferramentas Utilizadas

- **Linguagem R**: Para análise estatística e geoestatística.
- **Pacotes R**:
  - `sf`: Manipulação de dados espaciais.
  - `dplyr`: Transformação de dados.
  - `ggplot2`: Visualização gráfica.
  - `gstat`: Análise variográfica e krigagem.
  - `raster`: Manipulação de rasters.

---

## 📜 Licença
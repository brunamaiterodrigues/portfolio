# =============================================================
# 03-figuras.R
# Gera os gráficos usados no relatório em PDF e nos slides.
# Saída: figuras/*.png
# =============================================================

suppressPackageStartupMessages({
  library(readr); library(dplyr); library(lubridate)
  library(ggplot2); library(scales); library(patchwork)
  library(jsonlite); library(here); library(ragg)
})

dir.create(here("figuras"), showWarnings = FALSE, recursive = TRUE)

AZUL   <- "#0f172a"
AZUL2  <- "#1e293b"
ROXO   <- "#7c3aed"
ROXO2  <- "#6366f1"
CINZA  <- "#94a3b8"
CLARO  <- "#e2e8f0"
FUNDO  <- "#ffffff"
TEXTO  <- "#334155"

tema <- theme_minimal(base_size = 11, base_family = "sans") +
  theme(
    plot.background   = element_rect(fill = FUNDO, colour = NA),
    panel.background  = element_rect(fill = FUNDO, colour = NA),
    panel.grid.major  = element_line(colour = "#eef2f6", linewidth = 0.4),
    panel.grid.minor  = element_blank(),
    axis.text         = element_text(colour = TEXTO, size = 9),
    axis.title        = element_text(colour = TEXTO, size = 9.5),
    plot.title        = element_text(colour = AZUL, face = "bold", size = 13),
    plot.subtitle     = element_text(colour = "#64748b", size = 9.5, margin = margin(b = 10)),
    plot.caption      = element_text(colour = "#94a3b8", size = 8, hjust = 0),
    legend.position   = "top",
    legend.title      = element_blank(),
    legend.text       = element_text(colour = TEXTO, size = 9)
  )

# --- Dados -----------------------------------------------------
dias    <- read_csv(here("saidas", "dias.csv"), show_col_types = FALSE) |>
  mutate(data = as.Date(data), mes_ano = floor_date(data, "month"))
pedidos <- read_csv(here("saidas", "pedidos.csv"), show_col_types = FALSE) |>
  mutate(data = as.Date(data))
vendas  <- read_csv(here("saidas", "vendas_limpo.csv"), show_col_types = FALSE) |>
  mutate(data = as.Date(data))
json    <- fromJSON(here("saidas", "dashboard_dados.json"), simplifyVector = FALSE)

f_mil <- function(x) paste0("R$ ", format(round(x / 1000), big.mark = ".", decimal.mark = ","), " mil")

# --- 1. Faturamento mês a mês ----------------------------------
mensal <- dias |>
  group_by(mes_ano) |>
  summarise(dias = n(), faturamento = sum(faturamento), .groups = "drop") |>
  mutate(
    rotulo = paste0(c("jan","fev","mar","abr","mai","jun","jul","ago","set","out","nov","dez")[month(mes_ano)],
                    "/", substr(year(mes_ano), 3, 4)),
    parcial = dias < 10,
    rotulo2 = if_else(parcial, paste0(rotulo, "\n(", dias, " dias)"), rotulo)
  )

p1 <- ggplot(mensal, aes(x = reorder(rotulo2, mes_ano), y = faturamento, fill = parcial)) +
  geom_col(width = 0.68) +
  scale_fill_manual(values = c(`FALSE` = AZUL, `TRUE` = CLARO),
                    labels = c("Mês completo", "Menos de 10 dias registrados")) +
  scale_y_continuous(labels = f_mil, expand = expansion(mult = c(0, 0.08))) +
  labs(x = NULL, y = NULL,
       title = "Faturamento mês a mês",
       subtitle = "Soma das vendas registradas em cada mês. Receita, não lucro.",
       caption = "Base: 358 dias com registro, de jan/2025 a ago/2026.") +
  tema +
  theme(axis.text.x = element_text(size = 7.2, angle = 45, hjust = 1, vjust = 1))

ggsave(here("figuras", "mensal.png"), p1, width = 7.4, height = 3.1, dpi = 220, device = ragg::agg_png, bg = FUNDO)

# --- 2. Pedidos por hora ---------------------------------------
horas <- pedidos |>
  count(hora_cheia, name = "pedidos") |>
  filter(hora_cheia >= 10)

p2 <- ggplot(horas, aes(x = hora_cheia, y = pedidos)) +
  geom_col(fill = ROXO, width = 0.72) +
  geom_text(aes(label = pedidos), vjust = -0.45, size = 2.7, colour = TEXTO) +
  scale_x_continuous(breaks = 10:23, labels = paste0(10:23, "h")) +
  scale_y_continuous(labels = label_number(big.mark = "."), expand = expansion(mult = c(0, 0.14))) +
  labs(x = NULL, y = "Pedidos",
       title = "Pedidos por hora do dia",
       subtitle = "Hora em que o pedido foi registrado, não a hora da entrega.",
       caption = "Base: 21.350 pedidos.") +
  tema +
  theme(axis.text.x = element_text(size = 7.8))

ggsave(here("figuras", "horas.png"), p2, width = 7.4, height = 3.0, dpi = 220, device = ragg::agg_png, bg = FUNDO)

# --- 3. Tamanhos e categorias ----------------------------------
tamanhos <- vendas |>
  group_by(tamanho) |>
  summarise(pizzas = sum(quantidade), .groups = "drop") |>
  mutate(share = pizzas / sum(pizzas),
         rotulo = paste0(format(round(share * 100), decimal.mark = ","), "%"),
         tamanho = factor(tamanho, levels = c("P", "M", "G", "GG")))

p3a <- ggplot(tamanhos, aes(x = share, y = tamanho)) +
  geom_col(fill = AZUL, width = 0.62) +
  geom_text(aes(label = rotulo), hjust = -0.18, size = 3, colour = TEXTO) +
  scale_x_continuous(labels = percent_format(accuracy = 1), limits = c(0, 0.45),
                     expand = expansion(mult = c(0, 0))) +
  labs(x = NULL, y = NULL, title = "Participação por tamanho",
       subtitle = "De cada 100 pizzas vendidas.") +
  tema + theme(panel.grid.major.y = element_blank())

categorias <- vendas |>
  group_by(categoria) |>
  summarise(pizzas = sum(quantidade), .groups = "drop") |>
  mutate(share = pizzas / sum(pizzas),
         rotulo = paste0(format(round(share * 100), decimal.mark = ","), "%"))

p3b <- ggplot(categorias, aes(x = share, y = reorder(categoria, share))) +
  geom_col(fill = ROXO, width = 0.62) +
  geom_text(aes(label = rotulo), hjust = -0.18, size = 3, colour = TEXTO) +
  scale_x_continuous(labels = percent_format(accuracy = 1), limits = c(0, 0.40),
                     expand = expansion(mult = c(0, 0))) +
  labs(x = NULL, y = NULL, title = "Participação por categoria",
       subtitle = "As quatro categorias do cardápio.") +
  tema + theme(panel.grid.major.y = element_blank())

p3 <- p3a / p3b
ggsave(here("figuras", "mix.png"), p3, width = 7.4, height = 3.9, dpi = 220, device = ragg::agg_png, bg = FUNDO)

# --- 4. Preços por tamanho -------------------------------------
precos <- vendas |>
  group_by(tamanho) |>
  summarise(minimo = min(preco_unitario), mediana = median(preco_unitario),
            maximo = max(preco_unitario), .groups = "drop") |>
  mutate(tamanho = factor(tamanho, levels = c("GG", "G", "M", "P")))

p4 <- ggplot(precos) +
  geom_segment(aes(x = minimo, xend = maximo, y = tamanho, yend = tamanho),
               colour = CLARO, linewidth = 7, lineend = "butt") +
  geom_point(aes(x = mediana, y = tamanho), colour = ROXO, size = 3.2) +
  geom_text(aes(x = minimo, y = tamanho, label = paste0("R$ ", format(round(minimo, 2), nsmall = 2, big.mark = ".", decimal.mark = ","))),
            vjust = -1.2, size = 2.6, colour = TEXTO) +
  geom_text(aes(x = maximo, y = tamanho, label = paste0("R$ ", format(round(maximo, 2), nsmall = 2, big.mark = ".", decimal.mark = ","))),
            vjust = -1.2, size = 2.6, colour = TEXTO) +
  scale_x_continuous(labels = function(x) paste0("R$ ", x), expand = expansion(mult = c(0.06, 0.06))) +
  labs(x = NULL, y = NULL,
       title = "Preço unitário por tamanho",
       subtitle = "A barra vai do menor ao maior preço registrado. O ponto marca o valor típico.",
       caption = "Base: preço efetivamente cobrado, com promoções.") +
  tema + theme(panel.grid.major.y = element_blank())

ggsave(here("figuras", "precos.png"), p4, width = 7.4, height = 2.5, dpi = 220, device = ragg::agg_png, bg = FUNDO)

# --- 5. Previsão -----------------------------------------------
hist <- do.call(rbind, lapply(json$previsao$historico, function(x)
  data.frame(semana = as.Date(x$semana, "%d/%m/%Y"), valor = as.numeric(x$valor), tipo = "Observado")))
prev <- do.call(rbind, lapply(json$previsao$previsto, function(x)
  data.frame(semana = as.Date(x$semana, "%d/%m/%Y"), valor = as.numeric(x$valor),
             li = as.numeric(x$li95), ls = as.numeric(x$ls95), tipo = "Estimativa")))

# A série já vem do modelo com semanas de 3 dias ou mais (ver R/02). A queda
# final é real: os últimos dias registrados tiveram movimento abaixo da média.

p5 <- ggplot() +
  geom_ribbon(data = prev, aes(x = semana, ymin = li, ymax = ls), fill = ROXO, alpha = 0.14) +
  geom_line(data = hist, aes(x = semana, y = valor), colour = AZUL, linewidth = 0.8) +
  geom_line(data = prev, aes(x = semana, y = valor), colour = ROXO, linewidth = 0.8, linetype = "dashed") +
  geom_vline(xintercept = as.numeric(min(prev$semana)), colour = CINZA, linetype = "dotted") +
  annotate("text", x = min(prev$semana), y = max(hist$valor) * 1.04, label = "início da estimativa",
           hjust = -0.06, size = 2.7, colour = "#64748b") +
  scale_x_date(date_labels = "%b/%y", date_breaks = "3 months", expand = expansion(mult = c(0.02, 0.03))) +
  scale_y_continuous(labels = f_mil, expand = expansion(mult = c(0.06, 0.12))) +
  labs(x = NULL, y = NULL,
       title = "Receita média por dia registrado, semana a semana",
       subtitle = "Linha cheia: o que aconteceu. Linha tracejada: estimativa. Faixa: 95% de confiança.",
       caption = "Modelo de tendência amortecida, 12 semanas à frente.") +
  tema

ggsave(here("figuras", "previsao.png"), p5, width = 7.4, height = 3.1, dpi = 220, device = ragg::agg_png, bg = FUNDO)

# --- 6. Top 10 sabores -----------------------------------------
sabores <- vendas |>
  group_by(nome_pizza_simp) |>
  summarise(pizzas = sum(quantidade), .groups = "drop") |>
  arrange(desc(pizzas)) |>
  slice_head(n = 10) |>
  mutate(nome = reorder(nome_pizza_simp, pizzas),
         rotulo = format(pizzas, big.mark = ".", decimal.mark = ","))

p6 <- ggplot(sabores, aes(x = pizzas, y = nome)) +
  geom_col(fill = AZUL, width = 0.64) +
  geom_text(aes(label = rotulo), hjust = -0.12, size = 2.9, colour = TEXTO) +
  scale_x_continuous(labels = label_number(big.mark = "."),
                     expand = expansion(mult = c(0, 0.14))) +
  labs(x = NULL, y = NULL,
       title = "Dez sabores mais vendidos",
       subtitle = "Pizzas vendidas no período, somando todos os tamanhos.",
       caption = "Base: 49.574 pizzas, 32 sabores cadastrados.") +
  tema + theme(panel.grid.major.y = element_blank(),
               axis.text.y = element_text(size = 8.4))

ggsave(here("figuras", "sabores.png"), p6, width = 7.4, height = 3.4, dpi = 220, device = ragg::agg_png, bg = FUNDO)

cat("Figuras geradas em figuras/\n")
cat(paste(list.files(here("figuras")), collapse = ", "), "\n")

# --- Versões para slides (sem título, para não repetir o título do slide) ---
dir.create(here("figuras", "slides"), showWarnings = FALSE, recursive = TRUE)
sem_titulo <- function(p) p + theme(plot.title = element_blank(),
                                    plot.subtitle = element_blank())

ggsave(here("figuras","slides","mensal.png"),  sem_titulo(p1), width = 7.4, height = 2.9, dpi = 220, device = ragg::agg_png, bg = FUNDO)
ggsave(here("figuras","slides","horas.png"),   sem_titulo(p2), width = 7.4, height = 2.9, dpi = 220, device = ragg::agg_png, bg = FUNDO)
ggsave(here("figuras","slides","mix.png"),     p3,             width = 7.4, height = 3.8, dpi = 220, device = ragg::agg_png, bg = FUNDO)
ggsave(here("figuras","slides","precos.png"),  sem_titulo(p4), width = 7.4, height = 2.3, dpi = 220, device = ragg::agg_png, bg = FUNDO)
ggsave(here("figuras","slides","previsao.png"),sem_titulo(p5), width = 7.4, height = 2.9, dpi = 220, device = ragg::agg_png, bg = FUNDO)
ggsave(here("figuras","slides","sabores.png"), sem_titulo(p6), width = 7.4, height = 3.3, dpi = 220, device = ragg::agg_png, bg = FUNDO)

cat("Versoes para slides em figuras/slides/\n")

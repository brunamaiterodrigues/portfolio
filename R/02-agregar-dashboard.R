# =============================================================
# 02-agregar-dashboard.R
# Monta todas as tabelas que alimentam o dashboard, calcula as
# faixas prováveis (95%) e a previsão por série temporal.
# Saída: saidas/dashboard_dados.json e dashboard/index.html
# =============================================================

suppressPackageStartupMessages({
  library(readr); library(dplyr); library(tidyr); library(lubridate)
  library(jsonlite); library(forecast); library(here)
})

set.seed(20261119)  # usado apenas no cálculo de erro do modelo

# --- Leitura das tabelas tratadas -----------------------------
vendas  <- read_csv(here("saidas", "vendas_limpo.csv"), show_col_types = FALSE) |>
  mutate(data = as.Date(data), mes_ano = as.Date(mes_ano))
pedidos <- read_csv(here("saidas", "pedidos.csv"), show_col_types = FALSE) |>
  mutate(data = as.Date(data), mes_ano = as.Date(mes_ano))
dias    <- read_csv(here("saidas", "dias.csv"), show_col_types = FALSE) |>
  mutate(data = as.Date(data), mes_ano = as.Date(mes_ano))

Z <- 1.96  # nível de 95%

# --- Funções auxiliares ---------------------------------------
# Faixa provável para uma média (fórmula simples, conforme a spec).
faixa_media <- function(x) {
  x <- x[!is.na(x)]
  n <- length(x)
  if (n < 2) return(list(valor = mean(x), li = NA, ls = NA, n = n))
  m  <- mean(x)
  se <- sd(x) / sqrt(n)
  list(valor = m, li = m - Z * se, ls = m + Z * se, n = n)
}

# Faixa provável para uma proporção (intervalo de Wilson).
faixa_prop <- function(k, n) {
  if (n == 0) return(list(valor = NA, li = NA, ls = NA, n = 0))
  p <- k / n
  d <- 1 + Z^2 / n
  centro <- (p + Z^2 / (2 * n)) / d
  meio   <- Z * sqrt(p * (1 - p) / n + Z^2 / (4 * n^2)) / d
  list(valor = p, li = max(0, centro - meio), ls = min(1, centro + meio), n = n)
}

rotulo_mes <- function(d) {
  meses <- c("jan","fev","mar","abr","mai","jun","jul","ago","set","out","nov","dez")
  paste0(meses[month(d)], "/", substr(year(d), 3, 4))
}

# --- Meta ------------------------------------------------------
ini <- min(vendas$data); fim <- max(vendas$data)
dias_corridos <- as.integer(fim - ini) + 1

meta <- list(
  periodo_inicio = format(ini, "%d/%m/%Y"),
  periodo_fim    = format(fim, "%d/%m/%Y"),
  dias_corridos  = dias_corridos,
  dias_registro  = n_distinct(vendas$data),
  linhas         = nrow(vendas),
  pedidos        = n_distinct(vendas$id_pedido),
  gerado_em      = format(Sys.time(), "%d/%m/%Y %H:%M"),
  fonte          = "dados do vitto.csv (somente leitura)"
)

# --- KPIs ------------------------------------------------------
receita_total <- sum(vendas$preco_total)
pizzas_total  <- sum(vendas$quantidade)
pedidos_total <- n_distinct(vendas$id_pedido)

f_ticket <- faixa_media(pedidos$faturamento)
f_pizzas_ped <- faixa_media(pedidos$pizzas)
f_diaria <- faixa_media(dias$faturamento)
f_pedidos_dia <- faixa_media(dias$pedidos)

kpis <- list(
  faturamento_total = receita_total,
  pedidos_total     = pedidos_total,
  pizzas_total      = pizzas_total,
  dias_registro     = meta$dias_registro,
  preco_por_pizza   = receita_total / pizzas_total,
  ticket            = f_ticket,
  pizzas_por_pedido = f_pizzas_ped,
  media_diaria      = f_diaria,
  pedidos_por_dia   = f_pedidos_dia
)

# --- Série mensal ----------------------------------------------
mensal <- dias |>
  group_by(mes_ano) |>
  summarise(
    dias        = n(),
    faturamento = sum(faturamento),
    pedidos     = sum(pedidos),
    pizzas      = sum(pizzas),
    .groups = "drop"
  ) |>
  mutate(
    rotulo = rotulo_mes(mes_ano),
    mes    = format(mes_ano, "%Y-%m"),
    media_diaria = faturamento / dias
  ) |>
  arrange(mes_ano) |>
  select(mes, rotulo, dias, faturamento, pedidos, pizzas, media_diaria)

# --- Dia da semana (média por dia com registro) ----------------
dia_semana <- dias |>
  group_by(dia_semana_num, dia_semana_txt) |>
  summarise(
    n_dias = n(),
    fp = list(faixa_media(pedidos)),
    ff = list(faixa_media(faturamento)),
    .groups = "drop"
  ) |>
  mutate(
    pedidos_media = sapply(fp, `[[`, "valor"),
    pedidos_li    = sapply(fp, `[[`, "li"),
    pedidos_ls    = sapply(fp, `[[`, "ls"),
    faturamento_media = sapply(ff, `[[`, "valor"),
    fat_li        = sapply(ff, `[[`, "li"),
    fat_ls        = sapply(ff, `[[`, "ls")
  ) |>
  select(dia_semana_num, dia = dia_semana_txt, n_dias, pedidos_media,
         pedidos_li, pedidos_ls, faturamento_media, fat_li, fat_ls) |>
  arrange(dia_semana_num)

# --- Horários --------------------------------------------------
horas_base <- pedidos |> count(hora_cheia, name = "pedidos")
horas <- tibble(hora = 9:23) |>
  left_join(horas_base, by = c("hora" = "hora_cheia")) |>
  mutate(pedidos = coalesce(pedidos, 0L)) |>
  rowwise() |>
  mutate(fp = list(faixa_prop(pedidos, pedidos_total))) |>
  ungroup() |>
  mutate(
    share = sapply(fp, `[[`, "valor"),
    li    = sapply(fp, `[[`, "li"),
    ls    = sapply(fp, `[[`, "ls")
  ) |>
  select(hora, pedidos, share, li, ls)

faixas_horario <- pedidos |>
  count(faixa_horario, name = "pedidos") |>
  rowwise() |>
  mutate(fp = list(faixa_prop(pedidos, pedidos_total))) |>
  ungroup() |>
  mutate(share = sapply(fp, `[[`, "valor"),
         li    = sapply(fp, `[[`, "li"),
         ls    = sapply(fp, `[[`, "ls")) |>
  arrange(desc(pedidos)) |>
  select(faixa = faixa_horario, pedidos, share, li, ls)

# --- Tamanhos --------------------------------------------------
tamanhos <- vendas |>
  group_by(tamanho) |>
  summarise(
    pizzas      = sum(quantidade),
    faturamento = sum(preco_total),
    .groups = "drop"
  ) |>
  rowwise() |>
  mutate(fp = list(faixa_prop(pizzas, pizzas_total))) |>
  ungroup() |>
  mutate(share = sapply(fp, `[[`, "valor"),
         li    = sapply(fp, `[[`, "li"),
         ls    = sapply(fp, `[[`, "ls"),
         preco_medio = faturamento / pizzas) |>
  select(tamanho, pizzas, share, li, ls, faturamento, preco_medio) |>
  arrange(match(tamanho, c("P","M","G","GG")))

# --- Categorias ------------------------------------------------
categorias <- vendas |>
  group_by(categoria) |>
  summarise(
    pizzas      = sum(quantidade),
    faturamento = sum(preco_total),
    .groups = "drop"
  ) |>
  rowwise() |>
  mutate(fp = list(faixa_prop(pizzas, pizzas_total))) |>
  ungroup() |>
  mutate(share = sapply(fp, `[[`, "valor"),
         li    = sapply(fp, `[[`, "li"),
         ls    = sapply(fp, `[[`, "ls"),
         preco_medio = faturamento / pizzas) |>
  arrange(desc(pizzas)) |>
  select(categoria, pizzas, share, li, ls, faturamento, preco_medio)

# --- Sabores ---------------------------------------------------
sabores <- vendas |>
  group_by(nome = nome_pizza_simp, categoria) |>
  summarise(
    pizzas      = sum(quantidade),
    faturamento = sum(preco_total),
    .groups = "drop"
  ) |>
  mutate(share = pizzas / pizzas_total,
         preco_medio = faturamento / pizzas) |>
  arrange(desc(pizzas)) |>
  select(nome, categoria, pizzas, share, faturamento, preco_medio)

# --- Preços por tamanho ----------------------------------------
precos <- vendas |>
  group_by(tamanho) |>
  summarise(
    n        = n(),
    minimo   = min(preco_unitario),
    p25      = quantile(preco_unitario, 0.25),
    mediana  = median(preco_unitario),
    p75      = quantile(preco_unitario, 0.75),
    maximo   = max(preco_unitario),
    media    = mean(preco_unitario),
    .groups = "drop"
  ) |>
  arrange(match(tamanho, c("P","M","G","GG")))

# --- Comparação 2025 x 2026 ------------------------------------
# Mesmo intervalo de calendário nos dois anos: 1 de janeiro a 3 de agosto.
limite <- as.Date("2026-08-03")
comp_periodo <- dias |> filter(data >= as.Date("2025-01-01"), data <= limite)

resumo_ano <- function(ano_alvo) {
  d <- comp_periodo |> filter(year(data) == ano_alvo)
  p <- pedidos |> filter(year(data) == ano_alvo, data <= limite)
  list(
    ano            = ano_alvo,
    dias_registro  = nrow(d),
    faturamento    = sum(d$faturamento),
    pedidos        = sum(d$pedidos),
    pizzas         = sum(d$pizzas),
    media_diaria   = faixa_media(d$faturamento),
    ticket         = faixa_media(p$faturamento),
    pedidos_dia    = faixa_media(d$pedidos)
  )
}

a2025 <- resumo_ano(2025)
a2026 <- resumo_ano(2026)

# Diferença entre os dois anos, com faixa provável da diferença.
dif_medias <- function(x1, x2) {
  m1 <- mean(x1); m2 <- mean(x2)
  se <- sqrt(var(x1)/length(x1) + var(x2)/length(x2))
  d  <- m2 - m1
  list(indicador = NULL, valor_2025 = m1, valor_2026 = m2,
       dif = d, li = d - Z*se, ls = d + Z*se,
       variacao_pct = (m2 - m1)/m1, inclui_zero = (d - Z*se) <= 0 && (d + Z*se) >= 0)
}

d_media  <- dif_medias(comp_periodo$faturamento[year(comp_periodo$data)==2025],
                       comp_periodo$faturamento[year(comp_periodo$data)==2026])
d_ped    <- dif_medias(comp_periodo$pedidos[year(comp_periodo$data)==2025],
                       comp_periodo$pedidos[year(comp_periodo$data)==2026])
d_ticket <- dif_medias(pedidos$faturamento[year(pedidos$data)==2025 & pedidos$data <= limite],
                       pedidos$faturamento[year(pedidos$data)==2026 & pedidos$data <= limite])

d_media$indicador  <- "Faturamento por dia com registro"
d_ped$indicador    <- "Pedidos por dia com registro"
d_ticket$indicador <- "Valor médio por pedido"

comparacao <- list(
  periodo = "1º de janeiro a 3 de agosto nos dois anos",
  anos = list(a2025, a2026),
  diferencas = list(d_media, d_ped, d_ticket)
)

# --- Previsão --------------------------------------------------
# Decisão: a receita média por dia registrado é estável entre os dias
# da semana, então não há sazonalidade semanal a estimar. Modelamos a
# média diária de cada semana (normaliza semanas com 4 ou 5 dias) com
# tendência amortecida (Holt). 12 semanas à frente.
semanal <- dias |>
  mutate(semana = floor_date(data, "week", week_start = 1)) |>
  group_by(semana) |>
  summarise(dias = n(), receita = sum(faturamento), pedidos = sum(pedidos),
            media_dia = mean(faturamento), .groups = "drop") |>
  arrange(semana)

# Semanas com menos de 3 dias registrados distorcem a média e ficam fora do modelo.
semanal_modelo <- semanal |> filter(dias >= 3)

serie <- ts(semanal_modelo$media_dia, frequency = 1)

modelo <- ets(serie, model = "AAN", damped = TRUE)

# Erro do modelo nas 8 semanas finais, para dar noção de acerto.
n_treino <- length(serie) - 8
modelo_teste <- ets(ts(head(serie, n_treino), frequency = 1), model = "AAN", damped = TRUE)
previsao_teste <- forecast(modelo_teste, h = 8)
mae_holdout <- mean(abs(as.numeric(previsao_teste$mean) - tail(serie, 8)))

prev <- forecast(modelo, h = 12, level = c(80, 95))

ultima_semana <- max(semanal_modelo$semana)
semanas_futuras <- seq(ultima_semana + 7, by = "7 days", length.out = 12)

previsao <- list(
  metodo = "Tendência amortecida (Holt) sobre a receita média por dia registrado em cada semana",
  unidade = "R$ por dia com registro",
  horizonte_semanas = 12,
  erro_medio_ultimas_8_semanas = mae_holdout,
  media_periodo = mean(semanal_modelo$media_dia),
  ultimas_4_semanas = mean(tail(semanal_modelo$media_dia, 4)),
  dias_ultimas_4_semanas = sum(tail(semanal_modelo$dias, 4)),
  historico = lapply(seq_len(nrow(semanal_modelo)), function(i) list(
    semana = format(semanal_modelo$semana[i], "%d/%m/%Y"),
    valor  = semanal_modelo$media_dia[i],
    dias   = semanal_modelo$dias[i]
  )),
  previsto = lapply(seq_along(semanas_futuras), function(i) list(
    semana = format(semanas_futuras[i], "%d/%m/%Y"),
    valor  = as.numeric(prev$mean[i]),
    li80   = as.numeric(prev$lower[i, "80%"]),
    ls80   = as.numeric(prev$upper[i, "80%"]),
    li95   = as.numeric(prev$lower[i, "95%"]),
    ls95   = as.numeric(prev$upper[i, "95%"])
  )),
  semanas_excluidas = nrow(semanal) - nrow(semanal_modelo),
  aviso = "A previsão assume que o padrão das últimas semanas continua. Não há sazonalidade anual estimável: o período cobre menos de dois anos completos.",
  nota_recente = paste0(
    "As últimas 4 semanas registradas tiveram média de R$ ",
    format(round(mean(tail(semanal_modelo$media_dia, 4)), 0), big.mark = ".", decimal.mark = ","),
    " por dia, abaixo da média do período (R$ ",
    format(round(mean(semanal_modelo$media_dia), 0), big.mark = ".", decimal.mark = ","),
    "). O modelo projeta retorno ao padrão médio, e essa é a parte mais frágil da estimativa."
  )
)

# --- Qualidade dos dados ---------------------------------------
divergentes <- vendas |> group_by(id_pedido) |> summarise(k = n_distinct(hora)) |> filter(k > 1) |> nrow()

qualidade <- list(
  linhas_sem_quantidade = sum(vendas$quantidade_imputada),
  dias_sem_registro     = dias_corridos - meta$dias_registro,
  pedidos_horario_divergente = divergentes,
  semanas_excluidas_previsao = previsao$semanas_excluidas,
  observacoes = c(
    "Dias sem registro não são dias sem venda.",
    "Faturamento é receita, não lucro: a base não tem custos.",
    "Preço praticado não é preço de cardápio: há promoções.",
    "As faixas de participação por sabor e tamanho são aproximadas, porque várias pizzas pertencem ao mesmo pedido."
  )
)

# --- Perguntas sugeridas para o chat ---------------------------
sugestoes <- c(
  "Qual foi o faturamento total?",
  "Qual o valor médio por pedido?",
  "Qual o dia da semana com mais pedidos?",
  "Qual o horário de pico?",
  "Qual sabor vende mais?",
  "Qual tamanho representa a maior parte das pizzas?",
  "Quantas pizzas por pedido, em média?",
  "Como foi 2026 comparado a 2025?",
  "Qual a previsão para as próximas semanas?",
  "Quanto representa o tamanho GG?"
)

# --- Monta e grava o JSON --------------------------------------
dados <- list(
  meta = meta,
  kpis = kpis,
  mensal = mensal,
  dia_semana = dia_semana,
  horas = horas,
  faixas_horario = faixas_horario,
  tamanhos = tamanhos,
  categorias = categorias,
  sabores = sabores,
  precos = precos,
  comparacao = comparacao,
  previsao = previsao,
  qualidade = qualidade,
  sugestoes = sugestoes
)

json <- toJSON(dados, auto_unbox = TRUE, pretty = TRUE, digits = 6, na = "null", null = "null")
writeLines(json, here("saidas", "dashboard_dados.json"), useBytes = TRUE)

cat("JSON gerado:", nchar(json), "caracteres\n")

# --- Injeta o JSON no template e grava o dashboard -------------
# O dashboard fica em um único arquivo HTML, então funciona ao
# abrir com duplo clique, sem servidor e sem depender de internet.
template_path <- here("dashboard", "template.html")
if (file.exists(template_path)) {
  html <- paste(readLines(template_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  partes <- strsplit(html, "__DADOS_JSON__", fixed = TRUE)[[1]]
  if (length(partes) == 2) {
    html_final <- paste0(partes[1], json, partes[2])
    writeLines(html_final, here("dashboard", "index.html"), useBytes = TRUE)
    cat("Dashboard gerado: dashboard/index.html (",
        round(file.size(here("dashboard", "index.html")) / 1024), "KB )\n")
  } else {
    warning("Marcador __DADOS_JSON__ não encontrado no template.")
  }
} else {
  warning("Template do dashboard não encontrado.")
}

cat("Semanas no modelo:", length(serie), " | MAE ultimas 8 semanas: R$", round(mae_holdout, 2), "\n")
cat("Previsao 12 semanas: R$", round(min(prev$mean), 2), "a R$", round(max(prev$mean), 2), "por dia\n")
cat("Diferenca de faturamento/dia 2026 vs 2025: R$", round(d_media$dif, 2),
    "(faixa", round(d_media$li, 2), "a", round(d_media$ls, 2), ")\n")

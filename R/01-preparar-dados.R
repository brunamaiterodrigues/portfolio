# =============================================================
# 01-preparar-dados.R
# Lê a base bruta de vendas da Pizzaria do Vitto, trata os
# problemas conhecidos e grava tabelas de trabalho em saidas/.
#
# A base original NÃO é alterada: a leitura é somente leitura.
# =============================================================

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(tidyr)
  library(lubridate)
  library(hms)
  library(janitor)
  library(here)
})

# --- Caminhos -------------------------------------------------
origem <- "C:/Users/Bruna/OneDrive/Documentos/dados do vitto.csv"

dir.create(here("saidas"), showWarnings = FALSE, recursive = TRUE)

# --- Leitura --------------------------------------------------
# Separador ';', decimal com vírgula e arquivo com BOM.
# read_csv2 já assume decimal_mark = ",".
vendas_brutas <- read_csv2(
  origem,
  locale = locale(encoding = "UTF-8", decimal_mark = ",", grouping_mark = "."),
  col_types = cols(
    id_venda      = col_integer(),
    id_pedido     = col_integer(),
    sabor_pizza   = col_character(),
    quantidade    = col_integer(),
    data_pedido   = col_character(),
    dia_semana_num = col_integer(),
    dia_semana_txt = col_character(),
    hora_pedido   = col_character(),
    preco_unitario = col_double(),
    preco_total   = col_double(),
    tamanho       = col_character(),
    tamanho_num   = col_integer(),
    categoria     = col_character(),
    ingredientes  = col_character(),
    nome_pizza    = col_character(),
    nome_pizza_simp = col_character()
  ),
  show_col_types = FALSE
) |>
  clean_names()

cat("Linhas lidas:", nrow(vendas_brutas), "\n")
cat("Colunas:", ncol(vendas_brutas), "\n")

# Faixas de horário usadas no dashboard. Recebe a hora em horas decimais.
faixa_de_horario <- function(h) {
  case_when(
    h < 11 ~ "Antes das 11h",
    h < 14 ~ "Almoço (11h–14h)",
    h < 17 ~ "Tarde (14h–17h)",
    h < 21 ~ "Jantar (17h–21h)",
    TRUE   ~ "Noite (21h+)"
  )
}

# --- Tratamento -----------------------------------------------
# 1) Uma linha está sem 'quantidade'. O preço total dividido pelo
#    preço unitário resulta em 1, então imputamos 1 unidade e
#    marcamos a linha para auditoria.
vendas <- vendas_brutas |>
  mutate(
    quantidade_imputada = is.na(quantidade),
    quantidade = if_else(is.na(quantidade), 1L, quantidade),
    data = dmy(data_pedido),
    hora = hms::as_hms(hora_pedido),
    hora_num = as.numeric(hora) / 3600,          # hora decimal, para faixas
    hora_cheia = as.integer(floor(as.numeric(hora) / 3600)),
    ano = year(data),
    mes = month(data),
    mes_ano = floor_date(data, "month"),
    # dia_semana_num: 1 = domingo ... 7 = sábado (confirmado no dicionário).
    # week_start = 7 faz a semana começar no domingo, então domingo = 1.
    dia_semana_num = wday(data, week_start = 7),
    dia_semana_txt = c("Domingo","Segunda","Terça","Quarta",
                       "Quinta","Sexta","Sábado")[dia_semana_num],
    faixa_horario = faixa_de_horario(hora_num)
  )

# Conferência: o dia da semana recalculado deve bater com o da base.
divergencia_dia <- sum(vendas$dia_semana_num != vendas_brutas$dia_semana_num, na.rm = TRUE)
cat("Divergências de dia da semana:", divergencia_dia, "\n")

# --- Tabela de pedidos ----------------------------------------
# Linhas não são pedidos: agrupamos por id_pedido.
# Horário do pedido = primeiro horário registrado nas linhas do pedido.
pedidos <- vendas |>
  group_by(id_pedido) |>
  summarise(
    data          = first(data),
    ano           = first(ano),
    mes           = first(mes),
    mes_ano       = first(mes_ano),
    dia_semana_num = first(dia_semana_num),
    dia_semana_txt = first(dia_semana_txt),
    hora          = min(hora),
    hora_num      = as.numeric(min(hora)) / 3600,
    hora_cheia    = as.integer(floor(as.numeric(min(hora)) / 3600)),
    faixa_horario = faixa_de_horario(as.numeric(min(hora)) / 3600),
    faturamento   = sum(preco_total),
    pizzas        = sum(quantidade),
    n_linhas      = n(),
    n_sabores     = n_distinct(nome_pizza_simp),
    .groups = "drop"
  ) |>
  arrange(data, hora)

# --- Tabela de dias -------------------------------------------
dias <- vendas |>
  group_by(data) |>
  summarise(
    ano        = first(ano),
    mes        = first(mes),
    mes_ano    = first(mes_ano),
    dia_semana_num = first(dia_semana_num),
    dia_semana_txt = first(dia_semana_txt),
    pedidos    = n_distinct(id_pedido),
    faturamento = sum(preco_total),
    pizzas     = sum(quantidade),
    .groups = "drop"
  ) |>
  arrange(data)

# --- Totais de controle ---------------------------------------
total_linhas   <- nrow(vendas)
total_pedidos  <- n_distinct(vendas$id_pedido)
total_pizzas   <- sum(vendas$quantidade)
total_receita  <- sum(vendas$preco_total)
dias_registro  <- n_distinct(vendas$data)
ticket_medio   <- total_receita / total_pedidos
pizzas_pedido  <- total_pizzas / total_pedidos
preco_pizza    <- total_receita / total_pizzas
media_diaria   <- total_receita / dias_registro

cat("\n--- TOTAIS DE CONTROLE ---\n")
cat(sprintf("Linhas:                  %s\n", format(total_linhas, big.mark = ".", decimal.mark = ",")))
cat(sprintf("Pedidos:                 %s\n", format(total_pedidos, big.mark = ".", decimal.mark = ",")))
cat(sprintf("Pizzas:                  %s\n", format(total_pizzas, big.mark = ".", decimal.mark = ",")))
cat(sprintf("Faturamento:             R$ %s\n", format(round(total_receita, 2), big.mark = ".", decimal.mark = ",", nsmall = 2)))
cat(sprintf("Dias com registro:       %s\n", dias_registro))
cat(sprintf("Valor medio por pedido:  R$ %s\n", format(round(ticket_medio, 2), decimal.mark = ",")))
cat(sprintf("Pizzas por pedido:       %s\n", format(round(pizzas_pedido, 2), decimal.mark = ",")))
cat(sprintf("Preco medio por pizza:   R$ %s\n", format(round(preco_pizza, 2), decimal.mark = ",")))
cat(sprintf("Media diaria:            R$ %s\n", format(round(media_diaria, 2), big.mark = ".", decimal.mark = ",")))

# --- Gravação -------------------------------------------------
# Remove colunas auxiliares que não precisam ir para o CSV.
vendas_saida <- vendas |>
  select(
    id_venda, id_pedido, nome_pizza_simp, nome_pizza, categoria, tamanho, tamanho_num,
    quantidade, quantidade_imputada, data, ano, mes, mes_ano,
    dia_semana_num, dia_semana_txt, hora, hora_cheia, faixa_horario,
    preco_unitario, preco_total, sabor_pizza
  )

write_csv(vendas_saida, here("saidas", "vendas_limpo.csv"))
write_csv(pedidos,      here("saidas", "pedidos.csv"))
write_csv(dias,         here("saidas", "dias.csv"))

cat("\nArquivos gravados em saidas/\n")

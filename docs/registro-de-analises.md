# Registro de análises — Pizzaria do Vitto

Uma linha por análise. Data, pergunta, arquivos e decisões.

| Data | Análise | Pergunta | Arquivos | Decisões |
|---|---|---|---|---|
| 2026-11-19 | Preparação da base | Quais dados existem e como tratá-los? | `R/01-preparar-dados.R` → `saidas/vendas_limpo.csv`, `saidas/pedidos.csv`, `saidas/dias.csv` | 1 linha sem quantidade preenchida com 1; dia da semana recalculado e conferido (0 divergências); horário do pedido = menor horário entre as linhas |
| 2026-11-19 | Agregações e previsão | Quais são os indicadores, as faixas prováveis e a estimativa para frente? | `R/02-agregar-dashboard.R` → `saidas/dashboard_dados.json`, `dashboard/index.html` | Faixas de 95% com fórmulas simples (média ± 1,96·s/√n) e Wilson para proporções; comparação anual no mesmo recorte de calendário (1/jan a 3/ago); previsão por tendência amortecida com 12 semanas |
| 2026-11-19 | Dashboard | Como apresentar os dados ao dono da pizzaria? | `dashboard/template.html`, `dashboard/index.html` | Arquivo único; assistente local por regras; sete seções; faixas prováveis em todo indicador de média |

## Totais de controle

Conferidos em 19/11/2026 e reproduzidos pelos scripts:

| Indicador | Valor |
|---|---|
| Linhas | 48.620 |
| Pedidos distintos | 21.350 |
| Pizzas (com 1 imputada) | 49.574 |
| Faturamento | R$ 4.089.300,25 |
| Dias com registro | 358 de 580 |
| Valor médio por pedido | R$ 191,54 |
| Pizzas por pedido | 2,32 |
| Preço médio por pizza | R$ 82,49 |
| Faturamento por dia com registro | R$ 11.422,63 |

## Decisões estatísticas que precisam ser lembradas

1. **Semana de vendas, não semana de calendário cheio.** A pizzaria registra 4 ou 5 dias por semana. A receita média por dia da semana é praticamente igual (varia de R$ 11.093 a R$ 11.756). Não há sazonalidade semanal a estimar.
2. **Média por dia com registro.** Nunca dividir pelos 580 dias corridos.
3. **Comparação anual no mesmo recorte.** 1º de janeiro a 3 de agosto nos dois anos. Em 2025 há 230 dias registrados; em 2026, 128. Comparar totais brutos mediria a cobertura, não as vendas.
4. **Todas as diferenças entre anos incluem o zero na faixa provável.** Ou seja: a análise não afirma aumento nem queda.
5. **Previsão frágil.** As últimas 4 semanas registradas ficaram em R$ 9.837 por dia contra R$ 11.398 de média do período. O modelo projeta retorno à média. Se o movimento recente continuar, a estimativa estará alta.
6. **Sem custos, sem cliente, sem entrega, sem estoque.** Nenhuma conclusão sobre lucro, fidelidade, tempo de entrega ou desperdício.

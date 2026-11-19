# Painel de vendas — Pizzaria do Vitto

Dashboard em um único arquivo HTML, com os dados embutidos. Não precisa de servidor, internet ou instalação.

## Como abrir

Dê um duplo clique em `index.html` ou arraste o arquivo para o navegador. Funciona igual no computador e no celular.

## O que tem dentro

| Seção | Conteúdo |
|---|---|
| Visão geral | Faturamento, pedidos, pizzas, valor médio por pedido e faturamento mês a mês |
| Ritmo | Pedidos por dia da semana, por hora e por faixa de horário |
| O que vendemos | Participação de tamanhos, categorias e os 32 sabores |
| Preços | Amplitude de preço por tamanho e tabela detalhada |
| 2025 e 2026 | Comparação no mesmo recorte de calendário, com a faixa da diferença |
| Previsão | Estimativa para 12 semanas, com faixa provável e erro do modelo |
| Dados e limites | Problemas conhecidos, tratamento e perguntas que a base não responde |

## Assistente de dados

O botão "Perguntar sobre os dados" abre um chat que responde com os números deste painel.

- Não usa internet nem chave de API.
- Entende perguntas em português sobre faturamento, pedidos, pizzas, valor médio por pedido, dias, horários, tamanhos, categorias, sabores, preços, comparação entre anos e previsão.
- Quando a resposta depende de custo, cliente, entrega ou estoque, ele diz que a base não tem esse dado em vez de inventar.
- Toda resposta traz a base usada e o que não dá para concluir.

Dá para abrir o painel já com uma pergunta na barra de endereço:

```
index.html?q=qual o horario de pico
index.html?q=qual o valor medio por pedido
```

## Como regenerar

Os números não foram digitados à mão. Eles vêm dos scripts em `R/`.

```
Rscript R/01-preparar-dados.R
Rscript R/02-agregar-dashboard.R
```

O primeiro lê a base bruta (somente leitura) e grava as tabelas tratadas em `saidas/`. O segundo calcula as faixas prováveis e a previsão, grava `saidas/dashboard_dados.json` e gera este `index.html` a partir de `template.html`.

Para mudar o visual, edite `template.html` e rode o segundo script de novo. Não edite `index.html` diretamente: ele é sobrescrito.

## Limites

- Faturamento é receita, não lucro.
- 222 dias do período não têm registro e não são tratados como venda zero.
- As faixas de participação por sabor e tamanho são aproximadas.
- A previsão assume continuidade do padrão atual.

# Estrutura dos três entregáveis

Os 10 blocos pedidos para o relatório estatístico. Este arquivo serve de base para o PDF e para os slides.

## 1. Capa
Título, período, fonte, data de geração. Marca textual "Pizzaria do Vitto". Sem número de página.

## 2. Se você ler só esta página
Cinco achados em uma frase cada, com o número principal e a faixa provável. Números confirmados pelos dados:

- Faturamento de R$ 4,09 milhões em 358 dias com registro, com valor médio de R$ 192 por pedido (faixa provável de R$ 189 a R$ 194).
- A receita média por dia com registro é de R$ 11.423 (faixa de R$ 11.212 a R$ 11.633), e não muda de forma relevante entre os dias da semana.
- O jantar, de 17h às 21h, concentra 39% dos pedidos; o almoço, 29%.
- O tamanho G responde por 38 de cada 100 pizzas; M, 32; P, 29; GG, 1.
- Os 5 sabores mais vendidos somam 24 de cada 100 pizzas, em um cardápio de 32 sabores.

## 3. O negócio em números
Faturamento, pedidos, pizzas e valor médio por pedido. Só o valor médio recebe faixa provável. Bloco explicando como ler as faixas.

## 4. Faturamento e volume
Barras de faturamento mês a mês, com os meses de cobertura curta marcados. Média diária em chamada separada. Não usar dois eixos.

## 5. Quando vendemos
Pedidos por dia da semana e por hora, com faixa provável. Destaque para o pico de 12h e para a faixa de jantar.

## 6. O que vendemos
Participação por tamanho e por categoria, em pizzas. Destaque para o tamanho G e para o equilíbrio entre as quatro categorias.

## 7. Concentração
Dez sabores mais vendidos, com a chamada de que 5 sabores somam 24% das pizzas. Cauda longa de 32 sabores.

## 8. Preços
Amplitude por tamanho: P de R$ 49 a R$ 118, M de R$ 63 a R$ 84, G de R$ 76 a R$ 105, GG de R$ 128 a R$ 180. Tabela com mínimo, valor típico, máximo e média.

## 9. 2025 vs 2026
Mesmo recorte de calendário. Todas as diferenças incluem o zero na faixa provável. A cobertura de registro caiu de 230 para 128 dias.

## 10. Próximos passos, limitações e nota técnica
Sugestões rotuladas como opinião, limitações da base, perguntas em aberto e a nota técnica com o método das faixas.

---

## Decisões técnicas já fechadas

| Tema | Decisão |
|---|---|
| Relatório | PDF, no máximo 10 páginas, via Quarto + XeLaTeX |
| Slides | PDF, via beamer |
| Dashboard | HTML único, já produzido em `dashboard/index.html` |
| Faixas prováveis | 95%, fórmulas simples; Wilson para proporções |
| Assistente do dashboard | Regras locais, sem API e sem chave |
| Previsão | Tendência amortecida, 12 semanas, sobre a receita média por dia registrado |

## Pendências antes do PDF e dos slides

1. Instalar TinyTeX para gerar PDF (R e Quarto já estão instalados).
2. Definir se as fotos genéricas de pizza entram no relatório.
3. Confirmar as ações da página 10 com base nos números acima.

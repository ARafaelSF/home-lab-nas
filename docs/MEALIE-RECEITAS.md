# Padrão de cadastro de receitas no Mealie

Este documento é a referência operacional para agentes que cadastram receitas no Mealie. O objetivo é organizar e normalizar a apresentação sem alterar silenciosamente o conteúdo original.

## Regras de organização

- O idioma de cadastro é português. Preserve nomes próprios, marcas e termos culinários estrangeiros quando fizerem parte da receita.
- Toda receita deve ter uma categoria culinária principal. Reutilize uma categoria existente; crie outra somente quando necessário e evite categorias excessivamente específicas.
- Use as tags de fluxo exatamente assim:
  - `Editar`: informação digitada manualmente pelo usuário e ainda em edição.
  - `Revisar IA`: receita cadastrada pela IA e pendente de revisão do usuário.
  - `Finalizado`: receita revisada, organizada e pronta.
- Uma receita nova cadastrada pela IA começa sempre com `Revisar IA`. A IA nunca deve marcá-la automaticamente como `Finalizado` e nunca deve usar `Editar` para indicar que foi cadastrada por IA.
- O cookbook `Organizadas` permanece associado às receitas `Finalizado`.
- Além das tags de fluxo, use tags úteis de equipamento ou método, como `Forno`, `Fogão` e `Liquidificador`, quando aplicável. Crie uma tag nova somente se ela for útil e evite excesso de tags meramente descritivas.

## Título, descrição e metadados

- Use um título claro e fiel à receita.
- Acrescente ao final do título emojis relacionados à própria receita, normalmente 1 ou 2, para facilitar a identificação visual e tornar a biblioteca mais agradável.
- Escolha emojis diretamente relacionados ao ingrediente principal, tipo de prato, método ou característica marcante da receita.
- Mantenha o nome textual claro e completo; não substitua palavras importantes por emojis e evite excesso de emojis.
- Preserve emojis existentes quando forem adequados. A IA pode escolher emojis apropriados ao cadastrar uma receita nova.
- Exemplo: `Xarope de Gengibre 🫚🔥`.
- Escreva uma descrição curta e útil em português, preservando origem, contexto ou características relevantes. A descrição não substitui o modo de preparo.
- Preencha porções/rendimento, tempos de preparo, cozimento e total somente quando estiverem explícitos na fonte ou forem objetivamente conhecidos. Não estime nem invente; deixe em branco quando houver dúvida.
- Informe a URL original quando a receita vier de fonte externa. Para receitas próprias, de família ou sem fonte conhecida, a URL pode ficar vazia; nunca invente uma fonte.
- Sempre que possível, associe uma imagem: prefira primeiro a imagem original da fonte. Uma imagem gerada por IA pode ser usada quando não houver original, mas não deve ser apresentada como fotografia original.

## Ingredientes

- Preserve a ordem de uso dos ingredientes.
- Use os campos estruturados do Mealie: quantidade, unidade, ingrediente normalizado e observação/notas do ingrediente.
- Registre medidas precisas. Use gramas para sólidos quando a fonte fornecer peso, mililitros para líquidos quando fornecer volume e unidades para itens contáveis.
- Não faça conversões arbitrárias. Preserve pesos técnicos, como `100 g de ovos` ou `60 g de gemas`, sem convertê-los para contagens.
- Preserve expressões indefinidas legítimas, como `a gosto`, `um fio`, `o suficiente para cobrir` e `para servir`.
- Nunca invente uma quantidade ausente.
- Use grupos estruturados do Mealie para componentes distintos, por exemplo `Massa`, `Recheio`, `Cobertura`, `Creme` e `Montagem`. Não simule grupos criando linhas de ingrediente ou títulos falsos. Receitas simples podem ter uma única lista.

## Modo de preparo e notas

- Registre as instruções em etapas sequenciais e ordenadas.
- Preserve detalhes úteis da fonte, incluindo temperatura, tempo, textura, ponto, utensílios e alternativas quando existirem.
- Use títulos/resumos de etapa quando ajudarem a leitura; não crie títulos artificiais para sequências simples.
- Use notas/observações para informações complementares, como variações, justificativas de quantidades, resultados de testes, textura, ponto, alternativas, contexto familiar, história e observações de uso.

## Fidelidade e procedimento

Organize e normalize a apresentação, mas não “melhore” a receita. Não altere silenciosamente ingredientes, quantidades ou técnica; se houver possível erro na fonte, registre-o para revisão em vez de corrigi-lo por conta própria.

Para cadastrar uma nova receita:

1. Leia este documento.
2. Analise toda a fonte antes de cadastrar.
3. Preserve os dados originais e não invente informações ausentes.
4. Estruture ingredientes, quantidades, unidades, notas e grupos.
5. Divida o preparo em etapas sequenciais, mantendo os detalhes úteis.
6. Preencha somente porções, tempos, descrição e fonte que sejam conhecidos.
7. Escolha a categoria principal e reaproveite categorias existentes.
8. Aplique as tags úteis de método/equipamento e a tag `Revisar IA`.
9. Obtenha a imagem original ou gere uma imagem alternativa claramente não original.
10. Crie a receita no Mealie.
11. Verifique a receita depois do cadastro, incluindo grupos, tags, imagem e campos estruturados.
12. Relate o que foi criado e os pontos que ainda precisam de revisão do usuário.

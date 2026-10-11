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
- Toda receita deve possuir imagem sempre que tecnicamente possível.
- Siga esta ordem de preferência:
  1. Se existir imagem original da própria receita ou fonte e ela puder ser utilizada, prefira essa imagem.
  2. Se não existir imagem original utilizável, gere uma imagem apropriada por IA, coerente com o prato, seus ingredientes e o resultado esperado.
  3. Deixe a receita sem imagem somente quando houver limitação técnica que impeça tanto obter a imagem original quanto gerar ou associar uma imagem por IA.
- Uma imagem gerada por IA não deve ser apresentada como fotografia original. Se a imagem ficar pendente por limitação técnica, não reutilize imagem de outra receita, não use imagem aleatória da internet como se fosse original, não invente fonte e informe explicitamente a limitação no relatório final.

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

### Procedimento obrigatório para nova receita via API

Quando a operação for cadastrar uma receita nova pela API do Mealie, siga obrigatoriamente este protocolo:

1. Antes da criação, obtenha e registre um inventário das receitas existentes contendo pelo menos ID, slug e título, além da quantidade total.
2. Crie a receita exclusivamente com `POST /api/recipes` e exija resposta `201 Created`.
3. Capture exatamente o slug ou identificador retornado pelo `POST`. Se não houver sucesso conforme esperado, aborte; não tente compensar uma criação falha com `PUT`.
4. Consulte imediatamente exatamente o slug retornado e obtenha o ID criado.
5. Confirme que o ID não existia no inventário anterior, não pertence a outra receita e que a quantidade total aumentou exatamente em 1.
6. Se qualquer validação falhar, aborte antes de qualquer `PUT` e preserve o estado atual.

Resultados de busca por nome ou texto nunca provam a identidade de uma receita recém-criada. Uma busca pode auxiliar localização ou auditoria, mas nunca substitui a identidade retornada pelo fluxo de criação. Nunca use slug ou ID encontrado por busca textual como alvo de atualização de uma receita que deveria estar sendo criada.

### Proteção obrigatória antes de atualização

Antes de qualquer `PUT /api/recipes/{slug}`, consulte o alvo e confirme explicitamente, quando disponíveis, ID, slug e título. O ID é a principal proteção contra alteração da receita errada. Se houver divergência entre a receita pretendida e a identidade consultada, aborte a operação.

Alterar o slug de uma receita existente não cria uma nova entidade: o ID continua sendo determinante. Um `PUT` pode atualizar uma receita existente somente depois da confirmação de identidade e nunca substitui o processo de criação por `POST`.

### Validação pós-escrita e proteção das receitas existentes

Depois de cadastrar uma nova receita, releia-a pela API e valide ID, slug, título, categoria, tags, grupos, ingredientes, instruções, rendimento, porções, tempos, fonte, descrição, notas e imagem. Verifique também a quantidade total, que deve satisfazer `quantidade_final = quantidade_inicial + 1`.

Compare os IDs do inventário anterior com o posterior. Todos os IDs anteriores devem continuar existindo e a nova receita deve possuir um ID adicional.

Quando qualquer pré-condição, identidade, resposta da API ou validação pós-escrita divergir do esperado:

1. pare novas escritas;
2. não tente corrigir automaticamente usando outra receita encontrada por busca;
3. preserve o estado atual;
4. informe claramente a divergência;
5. aguarde orientação quando houver risco de alterar outra receita.

Alterações em lote, normalizações amplas, recuperações ou operações potencialmente destrutivas exigem backup verificável antes da primeira escrita. Para um cadastro isolado de receita nova, o protocolo de inventário, identidade e validação acima é obrigatório; não é necessário criar backup completo se isso não fizer parte da política operacional atual.

Para cadastrar uma receita nova:

1. Leia este documento.
2. Analise toda a fonte antes de cadastrar.
3. Preserve os dados originais e não invente informações ausentes.
4. Estruture ingredientes, quantidades, unidades, notas e grupos.
5. Divida o preparo em etapas sequenciais, mantendo os detalhes úteis.
6. Preencha somente porções, tempos, descrição e fonte que sejam conhecidos.
7. Escolha a categoria principal e reaproveite categorias existentes.
8. Aplique as tags úteis de método/equipamento e a tag `Revisar IA`.
9. Obtenha a imagem original ou, se ela não existir, gere uma imagem alternativa apropriada e claramente não original; deixe-a pendente somente diante de limitação técnica explícita.
10. Siga o procedimento obrigatório de criação via `POST`, validação do novo ID e só então eventuais `PUT`s de preenchimento.
11. Verifique a receita depois do cadastro, incluindo identidade, grupos, tags, imagem e todos os campos estruturados.
12. Confirme que nenhuma receita preexistente desapareceu ou teve sua identidade substituída.
13. No relatório, informe título final, ID, slug, categoria, tags, grupos, estrutura dos ingredientes, quantidade de instruções, rendimento, porções, tempos, fonte, descrição, notas, situação da imagem e as quantidades total inicial e final de receitas. Informe explicitamente qualquer pendência causada por limitação técnica.

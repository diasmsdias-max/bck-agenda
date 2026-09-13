# EP07 — Atendimento

## Objetivo

Transformar o agendamento validado no EP06 em um fluxo operacional completo de atendimento, preparando a transição para pagamento e caixa sem acoplar prematuramente o módulo financeiro.

## Fluxo alvo

Agendamento → Cliente chegou → Iniciar atendimento → Adicionar serviços/produtos → Finalizar atendimento → Preparar recebimento.

## Escopo inicial

- tela operacional de atendimento vinculada ao agendamento;
- cliente e profissional sempre identificados;
- horário previsto, chegada, início real, término real e duração efetiva;
- observações do atendimento;
- inclusão de serviços e produtos adicionais;
- quantidade, preço unitário e total por item;
- desconto condicionado à permissão do usuário;
- total consolidado do atendimento;
- finalização preservando os tempos reais introduzidos no EP06;
- saída preparada para o futuro fluxo de pagamento/caixa;
- arquitetura compatível com operação offline-first e sincronização posterior.

## Regras

1. Chegada e início do atendimento continuam sendo eventos distintos.
2. Um atendimento deve estar vinculado a um agendamento e a um profissional.
3. Finalizar o atendimento registra o término real e preserva a duração efetiva.
4. Inclusões e alterações de itens devem preservar histórico suficiente para futura auditoria.
5. Preços usados no atendimento devem ser registrados como snapshot, evitando alteração retroativa quando o catálogo mudar.
6. Descontos não autorizados devem ser bloqueados.
7. O EP07 prepara o valor a receber, mas não implementa todo o caixa/financeiro.
8. O desenho de persistência deve permitir fila local e sincronização futura sem criar uma segunda autoridade de dados central.

## Critério de conclusão

O usuário consegue partir de um agendamento, registrar chegada, iniciar o atendimento, acompanhar os tempos reais, incluir itens, finalizar e obter um total consolidado pronto para recebimento, com testes automatizados e gates do repositório verdes.

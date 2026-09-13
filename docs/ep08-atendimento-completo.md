# EP08 — Atendimento completo

## Marco
M3 — Atendimento.

## Objetivo
Consolidar o fluxo iniciado no EP07 em um atendimento operacional completo, preservando tempos reais e histórico para alimentar a futura Agenda Inteligente (SmartTime).

Fluxo-alvo:

`Agenda → Cliente chegou → Início real → Itens/observações → Finalização → Histórico → Preparação da venda`

## Escopo P0

- registrar chegada do cliente e estado operacional `WAITING`;
- persistir início e fim reais do atendimento;
- calcular e preservar duração efetiva;
- consolidar serviços/produtos e observações associados ao atendimento;
- finalizar atendimento sem edição destrutiva do histórico;
- preparar dados da venda/recebimento, sem implementar o Financeiro completo neste épico;
- produzir histórico confiável para futura estimativa SmartTime por Cliente + Profissional + Serviço, com fallbacks posteriores;
- manter isolamento por empresa/tenant;
- manter API BCK como autoridade das regras críticas;
- manter desenho compatível com banco local, fila offline e sincronização futura.

## Regra de continuidade do tempo real

O tempo efetivo do atendimento não depende de um cronômetro residente em memória nem de execução contínua do aplicativo em primeiro ou segundo plano. A fonte oficial é a diferença entre os timestamps reais persistidos de início e término.

Depois que o atendimento for iniciado, trocar para outro aplicativo, bloquear a tela, colocar o BCK em segundo plano ou o Android encerrar o processo não pode pausar, reiniciar ou perder o atendimento em andamento. Ao retornar, a interface deve reconstruir o tempo decorrido a partir do horário real de início persistido.

No modo offline, o início/término deve ser persistido localmente de forma durável e entrar na fila de sincronização. A posterior sincronização com a API não deve substituir a hora real do evento pela hora em que a conexão foi recuperada.

Um contador visual atualizado enquanto a tela estiver aberta é apenas uma representação do tempo decorrido; nunca é a autoridade para o cálculo histórico ou para o SmartTime.

## Contratos previstos

O desenho funcional prevê operações equivalentes a:

- criação/abertura do atendimento;
- inclusão de itens;
- inclusão de observações;
- finalização;
- consulta do histórico preservado.

A implementação deve aproveitar o `ServiceSession` consolidado no EP07 e evoluí-lo, evitando criar um segundo modelo concorrente de atendimento.

## Critérios de aceite iniciais

1. Chegada, início e fim reais são persistidos e auditáveis.
2. A duração efetiva é calculável a partir dos tempos persistidos.
3. Itens usam snapshot dos dados comerciais necessários ao histórico.
4. Finalização é idempotente e não destrói histórico anterior.
5. Operações respeitam empresa, usuário e permissões.
6. O atendimento concluído deixa dados suficientes para o SmartTime futuro.
7. A saída prepara a próxima etapa de venda/recebimento sem antecipar o módulo financeiro completo.
8. Migrations, API .NET, contratos de segurança, Flutter analyze/test e build Android permanecem verdes.
9. Sair do BCK, trocar de aplicativo, bloquear a tela ou o encerramento do processo pelo sistema operacional não pausa nem reinicia o tempo real já iniciado.
10. A sincronização posterior de uma operação offline preserva o timestamp real capturado no dispositivo, sujeito às regras de consistência/auditoria da API.

## Estratégia de implementação

1. Auditar o que o EP07 já entrega contra estes critérios.
2. Reutilizar estruturas existentes antes de adicionar schema novo.
3. Completar lacunas de chegada/tempos/histórico.
4. Completar experiência Flutter e transições operacionais.
5. Fortalecer testes de idempotência, tenant e histórico.
6. Rodar todos os gates e somente então retirar o PR de Draft.

## Regra de merge

O PR permanece Draft durante o desenvolvimento. Merge somente com gates verdes e autorização explícita do proprietário.

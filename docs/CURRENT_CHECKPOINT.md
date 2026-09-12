# BCK Agenda — Checkpoint Atual

> Documento operacional de retomada. Atualizar ao concluir etapas relevantes ou antes de trocar de chat/sessão de desenvolvimento.

## Checkpoint

Data: 2026-09-12

### Estado macro

- EP05 — Agenda + Alpha 0.1: concluído e mesclado.
- EP06 — consolidação e hardening da Agenda: concluído e mesclado.
- EP07 — Atendimento / integração Agenda → Atendimento: EM DESENVOLVIMENTO.

### Base consolidada

- `main`: commit `9da437211069893adb81f8ed7c991626561f9a29` no momento da inspeção inicial deste checkpoint.
- Esse commit corresponde ao merge do EP06 (`EP06: consolidação e hardening da Agenda (#6)`).

### Branch funcional do EP07

- Branch: `ep07-atendimento`
- HEAD verificado antes da criação da documentação de continuidade: `486d95dc9c9adad98bd3e093897cd1f9c3e8e3da`
- Commit: `fix(ep07): usa modelo canônico de agendamento no launcher`
- Arquivo alterado nesse commit: `apps/bck_app/lib/src/features/service_sessions/service_session_launcher.dart`
- Objetivo da correção: usar o modelo canônico de agendamento no launcher e remover dependência paralela do modelo da feature Agenda.

### Gates verificados para `486d95dc`

Todos concluídos com sucesso:

- BCK Agenda CI #255 — SUCCESS
- BCK Alpha Android #54 — SUCCESS
- BCK EP05 Agenda Security #82 — SUCCESS
- BCK Shared Device Security #161 — SUCCESS
- BCK EP04 Client HTTP #132 — SUCCESS
- BCK EP04 Client Database #117 — SUCCESS

Resultado: 6/6 gates verdes.

### Branch desta documentação

- `ep07-project-continuity`
- Criada a partir de `486d95dc` para introduzir a documentação de continuidade sem escrever diretamente na `main`.

### Próximo objetivo funcional

Continuar o EP07 pela integração segura **Agenda → Atendimento**.

Antes de alterar código:

1. verificar novamente HEAD de `ep07-atendimento` e possíveis mudanças posteriores a este checkpoint;
2. verificar PRs abertos relacionados ao EP07;
3. revisar implementação existente do launcher/API/tela de atendimento;
4. confirmar contratos do backend e testes existentes;
5. implementar incrementalmente;
6. executar/verificar todos os gates aplicáveis;
7. atualizar este checkpoint ao atingir o próximo estado estável.

### Regra de segurança de continuidade

Não assumir que este checkpoint continua atual após novos commits. Em toda retomada, comparar este registro com o estado real do GitHub. O GitHub é a fonte da verdade sobre o código efetivamente implementado.

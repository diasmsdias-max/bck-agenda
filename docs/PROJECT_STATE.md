# BCK Agenda — Estado Permanente do Projeto

> Documento canônico de continuidade do projeto. Deve permitir retomar o BCK Agenda em um novo chat ou ambiente sem depender do histórico de conversa.

## 1. Objetivo

O BCK Agenda é um sistema de agenda e gestão operacional para empresas de serviços, projetado para operação moderna em dispositivos móveis e com evolução controlada por etapas (EPs).

O projeto deve preservar como princípios: simplicidade operacional, segurança, rastreabilidade, funcionamento confiável, suporte a operação offline conforme perfil/permissão e evolução sem quebrar fluxos já validados.

## 2. Fonte da verdade

A ordem de confiança para retomada do projeto é:

1. código, commits, PRs e GitHub Actions do repositório;
2. este documento para objetivos, arquitetura e decisões permanentes;
3. `docs/CURRENT_CHECKPOINT.md` para a posição operacional atual;
4. documentos específicos de EP em `docs/`;
5. histórico de chats como contexto complementar, nunca como única fonte.

Se documentação e código divergirem, verificar o histórico Git antes de assumir qualquer estado.

## 3. Arquitetura e princípios técnicos

- Aplicativo cliente em Flutter/Dart.
- API como camada de acesso aos dados e regras de negócio.
- PostgreSQL no backend.
- Autenticação, sessão e RBAC devem ser validados também no servidor; a UI não é fronteira de segurança.
- Identificadores de grupo/empresa devem derivar da sessão/contexto autorizado quando aplicável, evitando confiar em valores arbitrários fornecidos pelo cliente.
- Operações críticas devem ser rastreáveis e, quando aplicável, idempotentes.
- O projeto possui gates automatizados de CI, Android, segurança, HTTP e banco; alterações relevantes devem manter esses gates verdes.

## 4. Operação offline e dispositivos

- O sistema foi projetado para suportar operação móvel com regras de sessão/offline por perfil.
- Administrador/Proprietário deve permanecer operacional offline conforme regras já consolidadas no projeto.
- Usuários dependentes continuam sujeitos às regras de validade offline definidas no EP correspondente.
- Regras de segurança para dispositivo compartilhado devem ser preservadas.

## 5. Agenda

A Agenda é um núcleo operacional do BCK Agenda. Já foram desenvolvidos e consolidados recursos como visualizações de agenda, estados do agendamento, criação/alteração, cliente, profissional, serviço, conflitos/encaixes, agenda de equipe e evolução do fluxo operacional.

O EP06 consolidou/hardenizou a Agenda, incluindo agenda diária de 24 horas, captura de tempos reais do atendimento, atraso derivado, duração efetiva, mapeamento de status, card operacional enriquecido e cobertura automatizada.

## 6. Atendimento

O EP07 introduz/evolui o fluxo de Atendimento integrado à Agenda.

Princípios que devem ser preservados:

- um atendimento iniciado a partir de um agendamento deve manter o vínculo com o agendamento de origem;
- o serviço originalmente agendado deve compor o atendimento conforme as regras implementadas;
- criação e alteração do atendimento devem respeitar RBAC e contexto da sessão;
- a integração Agenda → Atendimento não deve duplicar modelos canônicos nem criar fontes paralelas de verdade;
- mudanças de estado devem ser consistentes entre backend e aplicativo;
- evitar duplicidade de operações em retries/reconexões quando houver suporte de idempotência.

## 7. Identidade visual

Identidade inicial aprovada:

- tema principal escuro/grafite;
- aparência moderna e sofisticada;
- destaque dourado/âmbar;
- textos claros;
- alternativa visual Grafite/Rosé pode existir como preferência individual conforme implementação já aprovada.

Fluxos visuais de referência incluem Login, Home, Agenda, Novo Agendamento, Atendimento, Finalização, Pagamento, Pix QR Code e Configurações Pix.

## 8. Pix QR Code

Existe especificação aprovada para QR Code Pix opcional da empresa/grupo:

- Administrador autorizado pode cadastrar/importar, substituir, ativar/desativar ou remover a imagem;
- sem imagem válida cadastrada, Pix continua funcionando normalmente;
- com recurso ativo, a finalização/recebimento pode oferecer `Apresentar QR Code` em destaque para leitura pelo cliente;
- a imagem pertence à configuração do Grupo/Empresa e deve sincronizar para dispositivos autorizados;
- apresentar o QR Code nunca equivale a confirmar automaticamente o pagamento.

## 9. Política de desenvolvimento

- Desenvolvimento por EPs e branches dedicadas.
- Não fazer merge de trabalho em andamento sem validação e autorização correspondente.
- Gates automatizados devem ser verificados antes de considerar uma etapa tecnicamente aprovada.
- Mudanças arquiteturais ou de regra de negócio relevantes devem ser registradas neste documento ou em documentação específica.
- Antes de iniciar um novo chat/sessão de desenvolvimento, ler este arquivo e `CURRENT_CHECKPOINT.md`, verificar branch/HEAD/PRs/Actions no GitHub e só então continuar.

## 10. Histórico macro

- EP01: fundações/checklist inicial.
- EP03: usuários e dispositivos, com documentação específica no repositório.
- EP05: Agenda + Alpha 0.1, concluído e mesclado.
- EP06: consolidação e hardening da Agenda, concluído e mesclado.
- EP07: Atendimento e integração Agenda → Atendimento, em desenvolvimento na data do primeiro checkpoint deste documento.

## 11. Regra de continuidade

Ao finalizar uma etapa relevante:

1. confirmar estado real no GitHub;
2. registrar o commit/branch/PR e os gates em `CURRENT_CHECKPOINT.md`;
3. atualizar este arquivo somente quando houver nova decisão permanente, mudança de objetivo, arquitetura ou regra de negócio;
4. manter detalhes temporários fora deste documento para que ele permaneça estável e legível.

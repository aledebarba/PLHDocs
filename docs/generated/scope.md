# scope.md — Documento de Escopo (SIGEC)

> Documento de escopo do **SIGEC – Sistema de Gestão de Espaços Comuns**.
> Expande e complementa `README.md`, `doc/requirements.md` e `doc/domain_rules.md` sem substituí-los.
> Afirmações não inferíveis do código/configuração/README estão marcadas com `⚠️ Não determinado a partir do código`.

---

## 1. Visão geral

O SIGEC é uma aplicação **Flutter/Dart** multiplataforma que centraliza a consulta, solicitação, aprovação, acompanhamento e cancelamento de reservas dos **espaços comuns** de um condomínio residencial.

O sistema substitui o controle manual por planilhas eletrônicas e mensagens em aplicativos de mensagem, oferecendo:

- um **canal único** de solicitação para o morador;
- **verificação automatizada** de regras de utilização, disponibilidade e prazos;
- um **fluxo de aprovação** mediado pelo administrador;
- **notificações in-app** de aprovação, recusa e interdição de espaços.

### 1.1 Problema de negócio

| Situação anterior | Situação proposta |
| :--- | :--- |
| Reservas registradas em planilhas e mensagens | Registro único em banco de dados central |
| Conflito de datas/horários descoberto no uso | Bloqueio no momento da solicitação |
| Regras (prazos, limites por unidade) verificadas manualmente | Verificação automatizada no cliente |
| Administração sem visão consolidada | Relatório de utilização por período e por espaço |
| Comunicação de aprovação por canais informais | Notificação in-app direcionada ao morador |

### 1.2 Objetivos mensuráveis declarados

| ID | Objetivo | Fonte |
| :--- | :--- | :--- |
| OBJ-01 | Ser o canal único de reserva dos espaços comuns | `README.md` |
| OBJ-02 | Automatizar verificação de regras e disponibilidade | `README.md` |
| OBJ-03 | Dar à administração mecanismo de aprovação e acompanhamento | `README.md` |
| OBJ-04 | Manter histórico das reservas para consulta e relatório | `README.md`, RF-10 |

⚠️ Não determinado a partir do código: metas quantitativas (redução de tempo de reserva, número de moradores atendidos, SLA de resposta).

---

## 2. Escopo funcional

### 2.1 Perfis de usuário

| Perfil | `role` | Descrição | Capacidades |
| :--- | :--- | :--- | :--- |
| **Morador** | `user` | Residente de uma unidade do condomínio | Consultar espaços, verificar regras, solicitar reserva, acompanhar status, cancelar reservas próprias |
| **Administrador** | `admin` | Gestor do condomínio | Tudo do morador + gerenciar moradores, gerenciar espaços, aprovar/recusar reservas, editar reservas, emitir relatório |

O perfil é determinado pelo campo `role` no documento de `users`. A distinção na interface é feita por comparação de string — ver `_discovery.md` §9.

### 2.2 Espaços abrangidos

Conforme `README.md`, o sistema gerencia: salão de festas, churrasqueira, salão gourmet, quadra esportiva, espaço kids e academia.

Os espaços **não são fixos em código**: são documentos da coleção `espacos`, cadastrados pelo administrador. A lista acima é o escopo funcional declarado; a cardinalidade real depende do cadastro.

### 2.3 Funcionalidades no escopo

| Domínio | Funcionalidade | Cobertura |
| :--- | :--- | :--- |
| Autenticação | Login com `login` + `senha` contra a coleção `users` | ✅ |
| Autenticação | Persistência de sessão entre execuções | ✅ (`SharedPreferences`) |
| Autenticação | Bloqueio de usuário desabilitado (`ind_habilitado != 'S'`) | ✅ |
| Autenticação | Logout com limpeza de cache | ✅ |
| Morador | Listar espaços com filtro disponível/indisponível e ordenação | ✅ |
| Morador | Visualizar ficha do espaço (capacidade, horários, custo, regras, interdição) | ✅ |
| Morador | Solicitar reserva com validação de regras | ✅ |
| Morador | Listar reservas próprias com filtro por status e ordenação | ✅ |
| Morador | Ver detalhes de reserva (data, horário, convidados, status, motivo) | ✅ |
| Morador | Cancelar reserva própria | ✅ |
| Morador | Listar todas as reservas do condomínio (visão agregada) | ✅ |
| Morador | Receber e ler notificações | ✅ |
| Admin | Aprovar reserva (status `ACEITA`) | ✅ |
| Admin | Recusar reserva com motivo obrigatório (status `REJEITADA`) | ✅ |
| Admin | Editar dados de reserva (espaço, horários, observações, motivo) | ✅ |
| Admin | Cadastrar morador (com senha e campos cadastrais) | ✅ |
| Admin | Editar morador (login, papel, dados cadastrais, apartamento) | ✅ |
| Admin | Excluir morador | ✅ |
| Admin | Cadastrar espaço | ✅ |
| Admin | Editar espaço, incluindo interdição com motivo e prazo | ✅ |
| Admin | Interditar espaço e rejeitar em lote as reservas associadas | ✅ |
| Admin | Notificar globalmente sobre interdição | ✅ |
| Admin | Relatório de utilização por período e por espaço | ✅ |

### 2.4 Fora de escopo

| Item | Situação |
| :--- | :--- |
| Pagamento de taxa de reserva | `custo_reserva` é cadastrado e exibido, mas **não há fluxo de cobrança** |
| Exclusão de espaço pela UI | `SpaceService.deleteSpace` existe; botão removido |
| Agendamento recorrente | Não implementado |
| Consulta de disponibilidade por calendário, persistida | `calendar_page.dart` existe, é órfã e grava apenas em `SharedPreferences` |
| Recuperação de senha pelo próprio usuário | Login informa: "Para redefinição de senha contate o administrador" |
| Notificação push nativa | Apenas notificação in-app via Firestore |
| Auditoria de alterações (quem mudou o quê) | Não implementado |
| Backup / restauração de dados | ❌ Não implementado (RNF-06) |
| Múltiplos condomínios (multi-tenant) | Modelo não prevê `condominio_id` |
| Exportação de relatório (PDF/CSV) | Não implementado |

---

## 3. Regras de domínio e mecanismos de validação

Fonte normativa: `doc/domain_rules.md`. A coluna "Implementação" indica onde a regra é efetivamente verificada.

### 3.1 Regras documentadas

| ID | Regra | Mecanismo no código | Camada |
| :--- | :--- | :--- | :--- |
| **RD-01** | Cada unidade pode ter até **2 reservas futuras** simultâneas | `reservas_user_page._criarReserva` conta reservas da unidade com status ativo e `hora_fim > agora`; bloqueia quando `>= 2` | Cliente |
| **RD-02** | Salão de festas exige antecedência mínima de **48 h** | `reservas_user_page._criarReserva` detecta `'salão'`/`'salao'` no nome e compara `inicioReserva` com `now + 48h` | Cliente |
| **RD-03** | Uma unidade não pode ter duas reservas no **mesmo horário** | `reservas_user_page._criarReserva` verifica interseção de intervalos `[inicio, fim)` na mesma data | Cliente |
| **RD-04** | Salão de festas e churrasqueira exigem **aprovação do administrador** | `analise_page` lista `PENDENTE` e permite aceitar/recusar | Cliente |
| **RD-05** | Cancelamento exige antecedência mínima de **24 h** | `ReservasService.cancelarReserva` — verifica **apenas se `status == 'ACEITA'`**, dentro de `runTransaction` | Cliente (transacional) |
| **RD-06** | A reserva deve estar vinculada a uma **unidade residencial** | `reservas_user_page` valida `users.id_apartamento`; `firestore.rules` exige `id_unidade` string não vazia | Cliente + Regra de servidor |
| **RD-07** | Respeitar o **horário de funcionamento** do espaço | `reservas_user_page._criarReserva` compara com `horario_abertura`/`horario_fechamento` | Cliente |

### 3.2 Regras efetivas não documentadas

O código impõe restrições **adicionais** que não constam em `doc/domain_rules.md`:

| Regra efetiva | Local | Efeito |
| :--- | :--- | :--- |
| **Uma reserva por espaço por dia** | `reservas_user_page._criarReserva`, `ReservasService.criarReserva`, `ReservasService.reagendarReserva` | Impede segunda reserva do mesmo espaço na mesma data, mesmo em horário distinto — é **mais restritivo** que RD-03 |
| **Capacidade máxima = `espacos.qtd_pessoas`** | `reservas_user_page._criarReserva` | Bloqueia quando convidados + proprietário excede a capacidade |
| **`hora_inicio` < `hora_fim`** | `reservas_user_page`, `reservas_admin_page`, `space_page` | Rejeita intervalos vazios ou invertidos |
| **Interdição rejeita reservas em lote** | `space_page._atualizarReservasAssociadas` | Ao marcar espaço como indisponível, todas as reservas do espaço passam a `REJEITADA` via `batch` |
| **Unicidade de `id_apartamento`** | `user_service.addUserWithPassword`, `updateUser` | Impede dois usuários com o mesmo apartamento |

### 3.3 Lacunas de implementação das regras

| ID | Lacuna |
| :--- | :--- |
| RD-04 | A distinção por espaço **não existe**: toda reserva nasce `PENDENTE` e passa por aprovação, independentemente do espaço. A regra documentada prevê aprovação obrigatória apenas para salão e churrasqueira |
| RD-05 | O prazo de 24 h **não se aplica a reservas `PENDENTE`**, que podem ser canceladas a qualquer momento |
| RD-01/RD-03 | Executadas **apenas no cliente**; não há transação envolvendo criação de reserva, portanto duas solicitações concorrentes podem violar ambas |

---

## 4. Fluxos de negócio

### 4.1 Ciclo de vida da reserva

```
[Morador solicita]
       │  valida RD-01, RD-02, RD-03, RD-06, RD-07 + capacidade + intervalo
       ▼
   PENDENTE ──────────────► [Admin aceita] ──────► ACEITA
       │                                            │
       │ [Admin recusa + motivo]                    │ [Morador cancela
       ▼                                            │  com ≥ 24 h]
   REJEITADA ◄──────────────┐                       ▼
       ▲                    │                   CANCELADA
       │                    │
       └── [Interdição do espaço: batch]
                           
   REALIZADA  ◄── previsto na UI, sem transição implementada
```

Observações:

- `REALIZADA` **não é produzida** por nenhum caminho de código (ver `_discovery.md` §8). Seria necessária uma rotina de encerramento por data.
- `CANCELADA` só é produzido por `ReservasService.cancelarReserva`.
- `REJEITADA` acumula três origens distintas: recusa do admin em `analise_page`, recusa em `reservas_admin_page` e interdição em lote em `space_page`.

### 4.2 Fluxo de autenticação

```
App inicia
   │
   ├─ Firebase.initializeApp(DefaultFirebaseOptions.currentPlatform)
   │
   ├─ AuthService.loadUserFromPreferences()
   │     ├─ lê username/role/ind_habilitado de SharedPreferences
   │     ├─ se houver cache → reconsulta Firestore por `login`
   │     │      ├─ ind_habilitado != 'S' → limpa cache, força login
   │     │      └─ erro de rede → mantém sessão do cache (modo offline)
   │     └─ sem cache → _currentUser = null
   │
   └─ MyApp: AnimatedBuilder em authService
         ├─ isAuthenticated → MyHomePage
         └─ senão           → LoginPage
```

Credenciais: `login` + `senha` comparados **diretamente** contra o documento em `users`. Não há hash, salt ou Firebase Authentication (ver `_discovery.md` §9).

### 4.3 Fluxo de navegação por perfil

O drawer de `MyHomePage` (`lib/main.dart`) monta os itens condicionalmente:

| Item | Morador (`user`) | Administrador (`admin`) |
| :--- | :-: | :-: |
| Espaços | ✅ (somente leitura) | ✅ (criar/editar/interditar) |
| Gerenciar Usuários | — | ✅ |
| Reservas | ✅ → `MinhasReservasPage` | ✅ → `ReservasAdminPage` |
| Análise de Reservas | — | ✅ |
| Reservar Espaço | ✅ → `AllReservasUserPage` | — |
| Sobre | ✅ | ✅ |
| Relatório | — | ✅ |
| Sair | ✅ | ✅ |

Além do drawer, o corpo da home exibe cards de acesso rápido e, para `admin`, um `FloatingActionButton.extended` rotulado "Relatório".

### 4.4 Fluxo de criação de reserva (validações em ordem)

`reservas_user_page._criarReserva` executa, nesta sequência:

1. Validação do `Form` (`GlobalKey<FormState>`).
2. Presença de espaço, data, hora de início e hora de fim.
3. Formato `HH:MM` de ambos os horários.
4. Existência do espaço em `espacos` (por `nome`).
5. Existência do morador em `users` e presença de `id_apartamento`.
6. Capacidade: `qtd_convidados + 1 <= qtd_pessoas`.
7. Horários dentro de `horario_abertura`/`horario_fechamento`.
8. `hora_inicio < hora_fim`.
9. RD-02: se o nome contiver "salão"/"salao", exigir ≥ 48 h.
10. Unicidade espaço+data (uma reserva por espaço por dia).
11. Consulta das reservas futuras da unidade (`id_unidade` + `data_reserva >=` hoje) — usa o índice composto de `firestore.indexes.json`.
12. RD-03: conflito de intervalo na mesma data.
13. RD-01: contagem de reservas ativas < 2.
14. Gravação em `reservas` com `status: 'PENDENTE'`, `data_criacao: serverTimestamp()` e `id_reserva` (epoch ms).

---

## 5. Arquitetura técnica

### 5.1 Plataformas e frameworks

| Camada | Tecnologia | Versão |
| :--- | :--- | :--- |
| Linguagem | Dart | `^3.9.2` |
| Framework de UI | Flutter (Material Design) | `>=3.35.0` |
| Tema | `ThemeData(primarySwatch: Colors.blue)` + `AppBar` índigo em telas individuais | — |
| Plataformas | Android, iOS, macOS, Web, Windows | Linux sem suporte a Firebase |
| Gerenciamento de estado | `setState` local + `ChangeNotifier`/`AnimatedBuilder` para sessão | nativo |
| Persistência remota | Cloud Firestore | `6.1.0` |
| Persistência local | SharedPreferences | `2.5.3` |
| Inicialização Firebase | Firebase Core | `4.2.1` |
| Formatação | intl (`DateFormat`, `NumberFormat.currency` `pt_BR`) | `0.18.1` |

**Não utilizadas**: nenhum gerenciador de estado de terceiros (Provider, Riverpod, Bloc, GetX); nenhum injetor de dependências; nenhuma biblioteca de rotas declarativas (usa `Navigator.push` imperativo com `MaterialPageRoute`).

### 5.2 Organização em camadas

```
lib/
├── main.dart .............................. composição raiz + shell (drawer/home)
├── models/
│   └── user.dart .......................... modelo de usuário com mapeamento Firestore
├── services/ .............................. acesso a dados e regras de negócio
│   ├── auth_service.dart .................. autenticação e sessão (ChangeNotifier)
│   ├── user_service.dart .................. CRUD de usuários + cache local
│   ├── space_service.dart ................. CRUD de espaços
│   ├── reservas_service.dart .............. criação, cancelamento, reagendamento
│   ├── notification_service.dart .......... envio e marcação de notificações
│   ├── management_service.dart ............ listagem simples de reservas (órfão na prática)
│   └── dashboard_relatorio_service.dart ... agregação e métricas de relatório
├── pages/ ................................. telas (Widgets)
│   ├── login_page.dart
│   ├── all_reservas_user_page.dart
│   ├── reservas_user_page.dart ............ formulário de nova reserva
│   ├── minhas_reservas_page.dart
│   ├── reservas_admin_page.dart
│   ├── analise_page.dart
│   ├── space_page.dart
│   ├── user_crud.dart
│   ├── notifications_page.dart
│   ├── dashboard_relatorio.dart
│   ├── documentacao.dart
│   └── [5 arquivos órfãos]
├── areas_crud.dart ........................ CRUD de áreas em memória (órfão)
└── firebase_options.dart .................. gerado pelo FlutterFire CLI
```

### 5.3 Padrões observados

| Padrão | Ocorrência |
| :--- | :--- |
| Service Object | Uma classe de serviço por coleção Firestore |
| Repository-like | Services encapsulam queries e expõem `Future`/`CollectionReference` |
| Stream-based UI | `StreamBuilder` para listas reativas (`reservas`, `notificacoes`, contador) |
| Future-based UI | `FutureBuilder` para carregamentos pontuais e agregações |
| Observer | `ChangeNotifier` (`AuthService`, `UserService`) com `AnimatedBuilder`/`addListener` |
| Cache-aside | `UserService` tenta Firestore, com *fallback* para `SharedPreferences` |
| Bottom sheet de filtros | Padrão repetido em `space_page`, `user_crud`, `minhas_reservas_page`, `all_reservas_user_page`, `reservas_admin_page` |
| Formatter customizado | `HoraInputFormatter`, `CpfInputFormatter`, `TelefoneInputFormatter`, `CustoInputFormatter` |
| Transação | `ReservasService.cancelarReserva` (`runTransaction`) |
| Batch | `NotificationService.enviarNotificacaoGlobal`, `marcarTodasComoLidas`, `SpaceService`/`_atualizarReservasAssociadas` |

### 5.4 Banco de dados

**Cloud Firestore** (NoSQL orientado a documentos), projeto `projeto-ihc-5530a`.

Coleções: `users`, `espacos`, `reservas`, `notificacoes` (+ `limites_reservas_por_unidade` declarada em regras e não usada).

Dicionário completo de campos em `_discovery.md` §6.

Características do modelo:

- **Sem integridade referencial**: `reservas.id_morador` e `reservas.espaco` são strings soltas; nenhum vínculo por referência de documento é imposto.
- **Chave natural nos espaços**: o document ID de `espacos` é o nome sanitizado, o que torna o **rename** uma operação de criar+apagar (`SpaceService.updateSpace`).
- **Denormalização de nome**: `reservas.espaco` guarda o nome do espaço, não o ID; renomear um espaço **não** atualiza reservas existentes.
- **Índice único**: `reservas(id_unidade ASC, data_reserva ASC)`.

### 5.5 Camada Data Connect (não integrada)

O diretório `dataconnect/` contém um schema PostgreSQL (`User`, `CommonArea`, `Booking`, `Rule`, `Availability`) com queries e seed, mas **não há dependência nem configuração** ligando-o ao app Flutter. Ver `_discovery.md` §12.

⚠️ Não determinado a partir do código se é migração futura para SQL ou resíduo do template do FlutterFire CLI.

---

## 6. Requisitos

### 6.1 Requisitos funcionais

Reproduzidos de `doc/requirements.md` com o status de cobertura apurado.

| ID | Descrição | Cobertura |
| :--- | :--- | :--- |
| RF-01 | Permitir que o morador realize autenticação | ✅ Implementado |
| RF-02 | Permitir consultar os espaços comuns disponíveis | ✅ Implementado |
| RF-03 | Permitir visualizar a disponibilidade de um espaço por data e horário | ⚠️ Parcial — não há tela de consulta; a disponibilidade é verificada no ato da reserva |
| RF-04 | Permitir solicitar uma reserva | ✅ Implementado |
| RF-05 | Permitir ao morador consultar suas reservas | ✅ Implementado |
| RF-06 | Permitir cancelamento quando as regras forem atendidas | ✅ Implementado |
| RF-07 | Administrador pode aprovar ou recusar solicitações | ✅ Implementado |
| RF-08 | Administrador pode cadastrar, alterar e inativar moradores | ✅ Implementado (`ind_habilitado`) |
| RF-09 | Administrador pode cadastrar e alterar espaços | ✅ Implementado (exclusão sem botão na UI) |
| RF-10 | Manter histórico das reservas | ✅ Implementado (sem auditoria de alterações) |

### 6.2 Requisitos não funcionais

| ID | Descrição | Cobertura |
| :--- | :--- | :--- |
| RNF-01 | Acesso às funcionalidades administrativas protegido por autenticação | ⚠️ Apenas no cliente; servidor aberto |
| RNF-02 | Controle de acesso conforme o perfil do usuário | ⚠️ Apenas no cliente |
| RNF-03 | Interface de fácil utilização | ✅ Material Design, drawer, filtros, feedback por SnackBar |
| RNF-04 | Consultas de disponibilidade com resposta adequada ao uso cotidiano | ✅ `Future.wait` em agregações e `StreamBuilder` em listas |
| RNF-05 | Dados das reservas armazenados de forma consistente | ⚠️ Parcial — criação não transacional |
| RNF-06 | Mecanismo de backup dos dados | ❌ Não implementado |

### 6.3 Requisitos implícitos inferidos do código

| Requisito implícito | Evidência |
| :--- | :--- |
| Persistência de sessão entre execuções | `AuthService.loadUserFromPreferences` |
| Operação offline degradada | *Fallback* de `SharedPreferences` em `AuthService` e `UserService` |
| Feedback visual de carregamento | `CircularProgressIndicator` em todos os `FutureBuilder`/`StreamBuilder` |
| Confirmação antes de operações destrutivas | Diálogos em `minhas_reservas_page`, `user_crud`, `space_page`, `calendar_page` |
| Notificação ao morador em decisões | `NotificationService.enviarNotificacao` em aprovação/recusa |
| Tolerância a dados legados | `User.fromMap` aceita `login` ou `username`; `_isAvailable` aceita `String` ou `bool` |

---

## 7. Segurança e privacidade

### 7.1 Situação atual

| Aspecto | Situação | Risco |
| :--- | :--- | :--- |
| Armazenamento de senha | Campo `senha` em **texto plano** em `users` | Alto — vazamento expõe credenciais |
| Transporte de credencial | Comparação direta no cliente após leitura do documento | Alto — a senha trafega para o cliente |
| Regras Firestore | `allow read, write: if true` em `users`, `espacos`, `notificacoes` | Alto — qualquer portador da `apiKey` lê e escreve |
| `apiKey` | Publicada em `lib/firebase_options.dart` (é pública por design do Firebase, mas combinada com regras abertas torna-se vetor) | Alto |
| Autorização por perfil | Apenas verificações de `role` no cliente | Alto — contornável |
| Validação de regras de negócio | Somente no cliente (exceto RD-06) | Médio — contornável por cliente modificado |
| Sessão local | `SharedPreferences` sem criptografia | Médio |
| Dados pessoais | CPF, e-mail, telefone, apartamento em `users` | Alto — sem controle de acesso |

### 7.2 Recomendações (fora do escopo desta documentação)

Registradas apenas como achado; nenhuma alteração de código foi feita.

- Adotar Firebase Authentication e substituir o campo `senha`.
- Reescrever `firestore.rules` com autorização baseada em `request.auth` e no papel do usuário.
- Mover validação de RD-01/RD-02/RD-03 para transação server-side ou Cloud Functions.
- Implementar backup automático (RNF-06) — Firestore suporta exportação gerenciada.

⚠️ Não determinado a partir do código se essas medidas estão planejadas.

---

## 8. Riscos e limitações conhecidas

| # | Risco | Impacto | Evidência |
| :-: | :--- | :--- | :--- |
| 1 | Regra "uma reserva por espaço por dia" é mais restritiva que RD-03 e não documentada | Reservas legítimas em horários distintos são bloqueadas sem justificativa formal | `reservas_user_page`, `reservas_service` |
| 2 | Renomear espaço não atualiza `reservas.espaco` | Reservas órfãs em relação ao cadastro de espaços | `SpaceService.updateSpace` + `reservas.espaco` por nome |
| 3 | `REALIZADA` nunca é produzida | Histórico não distingue reservas passadas de futuras | `_discovery.md` §8 |
| 4 | `ReservasService` tem métodos incompatíveis e não usados | Divergência de vocabulário induz a erro de manutenção | `aprovarOuRecusarReserva` (`APROVADA`/`RECUSADA`) |
| 5 | Duas classes `User` incompatíveis | Risco de confusão em manutenção | `models/user.dart` vs `auth_service.dart` |
| 6 | Cinco arquivos órfãos | Confusão sobre fonte de verdade, especialmente `calendar_page` | `_discovery.md` §4 |
| 7 | Criação de reserva não transacional | Violação de RD-01/RD-03 sob concorrência | `reservas_user_page._criarReserva` |
| 8 | Teste automatizado incoerente | `flutter test` falha; ausência de rede de segurança | `test/widget_test.dart` |
| 9 | Interdição de espaço rejeita reservas sem notificação individual | Morador não é avisado diretamente da perda da reserva | `space_page._atualizarReservasAssociadas` (só notificação global) |
| 10 | Documentação histórica diverge do código | `SUMARIO_IND_HABILITADO.md` descreve UI inexistente | `_discovery.md` §15.1 |
| 11 | Ausência de backup | Perda de dados sem recuperação | RNF-06 |
| 12 | Linux sem Firebase | Build compila mas não inicializa | `firebase_options.dart` |

---

## 9. Premissas e dependências externas

| Item | Descrição |
| :--- | :--- |
| Projeto Firebase ativo | `projeto-ihc-5530a` com Firestore habilitado |
| Configuração por plataforma | `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`, `macos/Runner/GoogleService-Info.plist` |
| Cadastro inicial | É necessário ao menos um usuário `admin` em `users` para operar o sistema |
| Cadastro de espaços | Nenhum espaço é semeado pelo código; o admin deve cadastrá-los |
| Conectividade | Operação plena exige rede; autenticação tem *fallback* offline |
| Flutter SDK | `>=3.35.0` / Dart `^3.9.2` |

### 9.1 Como executar

Conforme `README.md`:

1. Clonar o repositório.
2. `flutter pub get`
3. `flutter run`

Pré-requisitos: Flutter SDK e Dart SDK.

⚠️ Não determinado a partir do código: versões mínimas de sistema operacional por plataforma, requisitos de assinatura para distribuição, processo de CI/CD.

---

## 10. Glossário

| Termo | Definição |
| :--- | :--- |
| **Espaço comum** | Área de lazer/convivência do condomínio sujeita a reserva |
| **Unidade** | Apartamento identificado por `id_apartamento`, ao qual reservas são vinculadas |
| **Morador** | Usuário com `role = 'user'` |
| **Administrador** | Usuário com `role = 'admin'` |
| **`ind_habilitado`** | Indicador binário `'S'`/`'N'` que autoriza ou bloqueia o login |
| **Reserva** | Documento em `reservas` que associa unidade, morador, espaço, data e intervalo |
| **Interdição** | Estado do espaço (`status_disponivel = 'N'`) com motivo e prazo estimado |
| **Aprovação mediada** | Fluxo em que a reserva depende de decisão do administrador |
| **Notificação** | Documento em `notificacoes` endereçado a um `destinatario_id` |
| **`role`** | Papel do usuário, base do controle de acesso na UI |

---

## 11. Ambiguidades registradas

1. ⚠️ Não determinado a partir do código se os cinco arquivos órfãos (`home_page`, `espacos_page`, `management_page`, `calendar_page`, `areas_crud`) são trabalho em andamento ou resíduo a remover.
2. ⚠️ Não determinado a partir do código se `dataconnect/` representa migração planejada para PostgreSQL.
3. ⚠️ Não determinado a partir do código se a regra "uma reserva por espaço por dia" é política intencional ou efeito colateral de uma checagem simplificada.
4. ⚠️ Não determinado a partir do código se RNF-06 (backup) é atendido por procedimento operacional externo ao repositório.
5. ⚠️ Não determinado a partir do código qual é a política de privacidade e retenção dos dados pessoais (CPF, telefone, e-mail).
6. ⚠️ Não determinado a partir do código se há ambientes separados (desenvolvimento/produção); apenas um projeto Firebase é referenciado.
7. ⚠️ Não determinado a partir do código se o produto será distribuído em lojas de aplicativos ou apenas internamente.

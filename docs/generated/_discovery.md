# _discovery.md — Inventário Técnico do Projeto SIGEC

> Artefato de inventário produzido por leitura estática do repositório.
> Nenhum código-fonte foi alterado nesta fase.
> Convenção: `⚠️ Não determinado a partir do código` marca afirmações que não puderam ser inferidas de código, configuração ou README.

---

## 1. Identificação do projeto

| Item | Valor | Origem |
| :--- | :--- | :--- |
| Nome do pacote Dart | `flutter_application_1` | `pubspec.yaml` |
| Nome de produto (documentação) | **SIGEC – Sistema de Gestão de Espaços Comuns** | `README.md` |
| Descrição no pubspec | `"A new Flutter project."` (placeholder de template) | `pubspec.yaml` |
| Versão | `1.0.0+1` | `pubspec.yaml` |
| Tipo de projeto | `app` (aplicação Flutter, não pacote publicável) | `.metadata`, `publish_to: 'none'` |
| SDK Dart | `^3.9.2` | `pubspec.yaml` |
| SDK Flutter (resolvido) | `>=3.35.0` | `pubspec.lock` |
| Flutter revision base | `a402d9a4376add5bc2d6b1e33e53edaae58c07f8` (canal `stable`) | `.metadata` |
| Projeto Firebase | `projeto-ihc-5530a` | `firebase.json`, `lib/firebase_options.dart` |
| Data Connect | `serviceId projetoihc`, `southamerica-east1` | `dataconnect/dataconnect.yaml` |

### 1.1 Divergência de nomenclatura

O pacote Dart mantém o nome de template (`flutter_application_1`) enquanto o produto se chama SIGEC. Todos os imports internos usam `package:flutter_application_1/...`. Não há alias de pacote.

⚠️ Não determinado a partir do código se a renomeação foi intencionalmente postergada.

---

## 2. Plataformas-alvo

| Plataforma | Diretório | Observação |
| :--- | :--- | :--- |
| Android | `android/` | `google-services.json` gerado via FlutterFire CLI; `min_sdk_android: 21` |
| iOS | `ios/` | `GoogleService-Info.plist`; bundle `com.example.flutterApplication1` |
| macOS | `macos/` | mesmo bundle id do iOS |
| Web | `web/` | configuração Firebase `web` presente |
| Windows | `windows/` | configuração Firebase `windows` presente |
| Linux | `linux/` | **sem** `FirebaseOptions` — `firebase_options.dart` lança `UnsupportedError` |

O app compila para Linux, mas falha na inicialização do Firebase nessa plataforma.

---

## 3. Dependências

### 3.1 Produção (`pubspec.yaml`)

| Pacote | Declarado | Resolvido | Uso verificado no código |
| :--- | :--- | :--- | :--- |
| `flutter` | SDK | `0.0.0` | UI Material |
| `intl` | `^0.18.0` | `0.18.1` | `DateFormat` em `analise_page`, `dashboard_relatorio`, `management_page`, `notifications_page`, `reservas_admin_page`, `space_page`; `NumberFormat.currency` em `space_page` |
| `cloud_firestore` | `^6.1.0` | `6.1.0` | persistência principal |
| `shared_preferences` | `^2.0.15` | `2.5.3` | cache de sessão (`auth_service`), cache de usuários (`user_service`), agenda local (`calendar_page`) |
| `firebase_core` | `^4.2.1` | `4.2.1` | `Firebase.initializeApp` em `main.dart` |
| `cupertino_icons` | `^1.0.8` | `1.0.8` | declarado; ⚠️ uso explícito não localizado em `lib/` |

### 3.2 Desenvolvimento

| Pacote | Declarado | Resolvido | Observação |
| :--- | :--- | :--- | :--- |
| `flutter_test` | SDK | `0.0.0` | usado em `test/widget_test.dart` |
| `flutter_launcher_icons` | `^0.13.1` | `0.13.1` | `assets/icon.png` → `launcher_icon` (Android) e iOS |
| `flutter_lints` | `^5.0.0` | — | **posicionamento atípico**: declarado dentro do bloco `flutter_launcher_icons`, não em `dev_dependencies` |

### 3.3 Transitivas relevantes

`cloud_firestore_platform_interface 7.0.4`, `cloud_firestore_web 5.1.0`, `firebase_core_platform_interface 6.0.2`, `firebase_core_web 3.3.0`, `shared_preferences_{android,foundation,linux,web,windows}`, `_flutterfire_internals 1.3.64`, `leak_tracker 11.0.1`.

---

## 4. Inventário de arquivos-fonte (`lib/`)

"Rota" indica se a classe é alcançável a partir de `main.dart`.

| # | Arquivo | Símbolos públicos | Rota | Consumo |
| :-: | :--- | :--- | :-: | :--- |
| 1 | `lib/main.dart` | `main()`, `MyApp`, `MyHomePage`, `_buildReportRow` | ✅ raiz | entrypoint |
| 2 | `lib/models/user.dart` | `User` | ✅ | `user_service`, `user_crud` |
| 3 | `lib/firebase_options.dart` | `DefaultFirebaseOptions` | ✅ | **gerado — não elegível para edição** |
| 4 | `lib/services/auth_service.dart` | `User` (duplicata), `AuthService` | ✅ | `main`, `login_page`, `calendar_page`, `management_page`, `reservas_admin_page` |
| 5 | `lib/services/user_service.dart` | `UserService` | ✅ | `main`, `user_crud` |
| 6 | `lib/services/space_service.dart` | `SpaceService` | ✅ | `main`, `space_page` |
| 7 | `lib/services/reservas_service.dart` | `ReservasService` | ✅ | `main`, `minhas_reservas_page` |
| 8 | `lib/services/management_service.dart` | `ManagementService` | ⚠️ | apenas `management_page` (órfã) |
| 9 | `lib/services/notification_service.dart` | `NotificationService` | ✅ | `main`, `analise_page`, `notifications_page`, `reservas_admin_page`, `space_page` |
| 10 | `lib/services/dashboard_relatorio_service.dart` | `DashboardRelatorioService` | ✅ | `dashboard_relatorio` |
| 11 | `lib/pages/login_page.dart` | `LoginPage` | ✅ | `MyApp` |
| 12 | `lib/pages/all_reservas_user_page.dart` | `ReservaSortOption`, `AllReservasUserPage` | ✅ | drawer (role `user`) |
| 13 | `lib/pages/analise_page.dart` | `AnalisePage` | ✅ | drawer e card admin |
| 14 | `lib/pages/minhas_reservas_page.dart` | `ReservaSortOption`, `MinhasReservasPage` | ✅ | drawer e card `user` |
| 15 | `lib/pages/reservas_admin_page.dart` | `CriterioOrdenacao`, `ReservasAdminPage` | ✅ | drawer (role `admin`) |
| 16 | `lib/pages/reservas_user_page.dart` | `HoraInputFormatter`, `ReservarEspacoPage` | ✅ | FAB de `AllReservasUserPage` |
| 17 | `lib/pages/notifications_page.dart` | `NotificationsPage` | ✅ | ícone de sino em `MyHomePage` |
| 18 | `lib/pages/space_page.dart` | `SpaceSortOption`, `SpaceFilterOption`, `CustoInputFormatter`, `SpacesPage` | ✅ | drawer e card admin |
| 19 | `lib/pages/user_crud.dart` | `UserSortOption`, `UserFilterOption`, `CpfInputFormatter`, `TelefoneInputFormatter`, `UserCrudPage` | ✅ | drawer (role `admin`) |
| 20 | `lib/pages/dashboard_relatorio.dart` | `DashboardRelatorioPage` | ✅ | drawer e FAB admin |
| 21 | `lib/pages/documentacao.dart` | `DocumentacaoPage` | ✅ | drawer → "Sobre" |
| 22 | `lib/pages/home_page.dart` | `HomePage` | ❌ | **órfã** |
| 23 | `lib/pages/espacos_page.dart` | `EspacosPage` | ❌ | **órfã** — marcada no arquivo com `!! VERIFICAR SE ESSA PAGINA É USADA !!` |
| 24 | `lib/pages/management_page.dart` | `ManagementPage` | ❌ | **órfã** — mesma marcação |
| 25 | `lib/pages/calendar_page.dart` | `Booking`, `CalendarPage` | ❌ | **órfã** — modelo local em `SharedPreferences`, paralelo ao Firestore |
| 26 | `lib/areas_crud.dart` | `AreasCrudPage` | ❌ | **órfã** — CRUD apenas em memória |

A tabela tem 26 entradas porque inclui `firebase_options.dart` (gerado) e `areas_crud.dart` (na raiz de `lib/`). Arquivos Dart escritos manualmente: **25**.

### 4.1 Verificação de código morto

Busca textual por `CalendarPage`, `ManagementPage`, `AreasCrudPage`, `EspacosPage`, `HomePage` retorna **apenas as próprias declarações**. Busca por padrões de import (`lib/areas_crud`, `lib/pages/espacos_page`, `lib/pages/calendar_page`, `lib/pages/management_page`, `lib/pages/home_page`) retorna **zero resultados**.

Conclusão: **5 arquivos inalcançáveis** a partir de `main.dart`.

---

## 5. Grafo de dependências

```
main.dart
 ├── firebase_options.dart .................... (gerado)
 ├── services/auth_service.dart
 ├── services/user_service.dart ──► models/user.dart
 ├── services/space_service.dart
 ├── services/reservas_service.dart
 ├── pages/login_page.dart ──► services/auth_service.dart
 ├── pages/all_reservas_user_page.dart ──► pages/reservas_user_page.dart
 ├── pages/analise_page.dart ──► services/notification_service.dart
 ├── pages/minhas_reservas_page.dart ──► services/reservas_service.dart
 ├── pages/reservas_admin_page.dart ──► services/{auth,notification}_service.dart
 │                                  └► pages/reservas_user_page.dart (HoraInputFormatter)
 ├── pages/space_page.dart ──► services/{space,notification}_service.dart
 │                        └► pages/reservas_user_page.dart (HoraInputFormatter)
 ├── pages/user_crud.dart ──► models/user.dart, services/user_service.dart
 ├── pages/notifications_page.dart ──► services/notification_service.dart
 ├── pages/dashboard_relatorio.dart ──► services/dashboard_relatorio_service.dart
 └── pages/documentacao.dart  (sem dependências internas)

ÓRFÃOS (sem aresta de entrada):
  pages/home_page.dart, pages/espacos_page.dart, pages/management_page.dart,
  pages/calendar_page.dart, areas_crud.dart
```

Acoplamento notável: `HoraInputFormatter` (definido em `reservas_user_page.dart`) é importado por `space_page.dart` e `reservas_admin_page.dart`. Há dependência de página para página, sem camada compartilhada de formatters.

---

## 6. Dicionário de dados — Cloud Firestore

| Coleção | Escrita por | Leitura por | Document ID |
| :--- | :--- | :--- | :--- |
| `users` | `user_service` | `auth_service`, `user_service`, `analise_page`, `dashboard_relatorio_service`, `reservas_admin_page`, `reservas_user_page`, `notification_service`, `main.dart` | `login` (username) |
| `espacos` | `space_service` | `space_service`, `dashboard_relatorio_service`, `reservas_user_page` | `_sanitizeId(nome)` — `\` e `/` trocados por `-` |
| `reservas` | `reservas_user_page` (auto-ID), `reservas_service`, `analise_page`, `reservas_admin_page`, `space_page` | várias | auto-ID na UI — **exceto** `ReservasService.criarReserva`, que usa `doc(nomeEspaco)` |
| `notificacoes` | `notification_service` (add e batch) | `main.dart` (contador de não lidas), `notifications_page` | auto-ID |

### 6.1 Esquema `users` (inferido)

| Campo | Tipo | Origem da escrita | Observações |
| :--- | :--- | :--- | :--- |
| `login` | `String` | `addUserWithPassword`, `User.toMap` | chave de busca do login |
| `username` | `String` | `User.fromMap` lê como *fallback* de `login` | legado |
| `role` | `String` | `addUserWithPassword`, `User.toMap` | observados: `'admin'`, `'user'` |
| `senha` | `String` | `addUserWithPassword`, `User.toMap(senha:)` | **texto plano**; comparação direta em `auth_service` |
| `ind_habilitado` | `String` | `addUserWithPassword` (`'S'`), `updateUser` | `'S'`/`'N'`; default `'S'` na leitura |
| `nome` | `String` | `addUserWithPassword` | exibido em saudações e relatórios |
| `cpf` | `String` (só dígitos) | `addUserWithPassword` | máscara `000.000.000-00` só na UI |
| `email` | `String` | `addUserWithPassword` | — |
| `telefone` | `String` | `addUserWithPassword` | máscara UI `(00)00000-0000` |
| `id_apartamento` | `String` numérica | `addUserWithPassword` | vira `id_unidade` na reserva; unicidade validada |
| `data_cadastro` | `Timestamp` | `addUserWithPassword`, `updateUser` (preservado em rename) | — |

### 6.2 Esquema `espacos` (inferido)

| Campo | Tipo | Origem | Observações |
| :--- | :--- | :--- | :--- |
| `nome` | `String` | `createSpace` / `updateSpace` | vira ID sanitizado |
| `qtd_pessoas` | `Int` | `_showCreateDialog` | validado na UI em `1..50` |
| `horario_abertura` | `String` `HH:MM` | idem | validado por `_isValidTime` |
| `horario_fechamento` | `String` `HH:MM` | idem | deve ser > abertura |
| `custo_reserva` | `Int` | idem | validado na UI em `0..500` |
| `regras_uso` | `String` | idem | texto livre |
| `status_disponivel` | `String` `'S'`/`'N'` | idem | `_isAvailable` aceita também `bool` |
| `motivo_interdicao` | `String?` | `_showEditDialog` | gravado `null` quando disponível |
| `prazo_inter` | `Int?` | `_showEditDialog` | dias estimados de interdição |
| `id` | `String` | **não persistido** — injetado em memória por `getSpaces()` | ecoa o document ID |

### 6.3 Esquema `reservas` (inferido)

| Campo | Tipo | Origem | Observações |
| :--- | :--- | :--- | :--- |
| `espaco` | `String` | `reservas_user_page` | nome do espaço (não o ID) |
| `data_reserva` | `Timestamp` | idem | normalizado à meia-noite na UI |
| `hora_inicio` | `String` `HH:MM` | idem | — |
| `hora_fim` | `String` `HH:MM` | idem | — |
| `id_morador` | `String` | idem | = document ID de `users` (username) |
| `id_unidade` | `String` | idem | = `users.id_apartamento`; **obrigatório** pelas regras |
| `qtd_convidados` | `Int` | idem | convidados **+ 1** (proprietário) |
| `observacoes` | `String?` | idem | — |
| `status` | `String` | idem (`PENDENTE`), `analise_page`, `reservas_admin_page`, `space_page`, `reservas_service` | ver §8 |
| `motivo_cancelamento` | `String?` | `analise_page`, `reservas_admin_page` | também usado como motivo de recusa |
| `data_criacao` | `Timestamp` (`serverTimestamp`) | UI e service | — |
| `data_cancelamento` | `Timestamp` (`serverTimestamp`) | `reservas_service.cancelarReserva` | — |
| `id_reserva` | `Int` (epoch ms) | `reservas_user_page` | redundante ao document ID |

### 6.4 Esquema `notificacoes` (inferido)

| Campo | Tipo | Observações |
| :--- | :--- | :--- |
| `destinatario_id` | `String` | filtro principal das queries e do contador |
| `titulo` | `String` | — |
| `mensagem` | `String` | — |
| `lida` | `Bool` | default `false` |
| `data_criacao` | `Timestamp` (`serverTimestamp`) | ordenação feita em memória |
| `tipo` | `String` | `'aviso'` (default), `'reserva_aceita'`, `'reserva_recusada'`, `'geral'` |

### 6.5 Coleção declarada e não utilizada

`limites_reservas_por_unidade/{unidadeId}` consta em `firestore.rules` com `allow read, write: if true`, mas **nenhum código em `lib/` a referencia**. O limite de 2 reservas futuras é calculado em memória em `reservas_user_page._criarReserva`.

⚠️ Provável resíduo de tentativa anterior de controle server-side.

---

## 7. Índices e regras do Firestore

### 7.1 `firestore.indexes.json`

Único índice composto:

```
collectionGroup: reservas
queryScope: COLLECTION
fields: [ id_unidade ASC, data_reserva ASC ]
```

Corresponde à query de `reservas_user_page._criarReserva` (`where id_unidade ==` + `where data_reserva >=`). Nenhum `fieldOverride`.

### 7.2 `firestore.rules`

- `reservas`: `create`/`update` exigem `unidadeValida(data)` → `keys().hasAll(['id_unidade']) && id_unidade is string && size() > 0`. `read` e `delete` liberados (`if true`).
- `users`, `espacos`, `notificacoes`, `limites_reservas_por_unidade`: `allow read, write: if true`.
- Comentário no arquivo confirma a decisão: *"O aplicativo usa autenticação própria com SharedPreferences, sem Firebase Auth."*

**Consequência de segurança**: qualquer cliente com a `apiKey` (publicada em `firebase_options.dart`) pode ler e escrever `users` — inclusive `senha` —, `espacos` e `notificacoes`. Não há isolamento por `role`.

---

## 8. Vocabulário de status — inconsistências verificadas

| Valor | Escrito por | Lido por |
| :--- | :--- | :--- |
| `PENDENTE` | `reservas_user_page` (criação) | `analise_page`, `all_reservas_user_page`, filtros, `dashboard_relatorio` |
| `ACEITA` | `analise_page` (aprovar) | cores/labels, `reservas_service.cancelarReserva` (regra das 24 h) |
| `REJEITADA` | `analise_page`, `reservas_admin_page`, `space_page` (batch ao interditar) | cores/labels |
| `CANCELADA` | `reservas_service.cancelarReserva` | exclusões de contagem de reservas ativas |
| `REALIZADA` | **nenhum código escreve** | `_getStatusColor`/labels; exclusões de contagem |
| `APROVADA` | `reservas_service.aprovarOuRecusarReserva` | **nenhum** código lê |
| `RECUSADA` | `reservas_service.aprovarOuRecusarReserva` | **nenhum** código lê |

Conclusões:

1. `ReservasService.aprovarOuRecusarReserva` é **incompatível** com o restante do sistema (`APROVADA`/`RECUSADA` vs `ACEITA`/`REJEITADA`) e não é chamado por nenhuma página.
2. `REALIZADA` é estado **previsto na UI mas nunca produzido** — não há rotina de transição.
3. `CANCELADA` só é produzido por `ReservasService.cancelarReserva`, caminho efetivamente usado por `minhas_reservas_page`.

---

## 9. Autenticação e autorização

| Aspecto | Implementação observada |
| :--- | :--- |
| Provedor de identidade | **Nenhum** — `AuthService` consulta `users` por `login` e compara `senha` em texto plano |
| Sessão | `SharedPreferences`: chaves `username`, `role`, `ind_habilitado` |
| Revalidação | `loadUserFromPreferences()` reconsulta Firestore na inicialização; se `ind_habilitado != 'S'`, limpa o cache |
| Fallback offline | Em exceção na consulta, mantém a sessão do cache (comentário explícito no código) |
| Propagação de estado | `AuthService extends ChangeNotifier` + `AnimatedBuilder` em `MyApp` |
| Controle de acesso na UI | `role == 'admin'` em `main.dart`; `role.toLowerCase() == 'admin'` em outros pontos — **critério inconsistente** |
| Controle de acesso no servidor | Ausente (§7.2) |

Existem **duas classes `User`** distintas: `lib/models/user.dart` (com `extra`, `fromMap`/`toMap`) e uma classe interna em `lib/services/auth_service.dart` (sem `extra`). São incompatíveis entre si; `AuthService.currentUser` é do tipo da segunda.

---

## 10. Regras de domínio × implementação

Fonte: `doc/domain_rules.md`.

| ID | Regra | Onde está implementada | Situação |
| :--- | :--- | :--- | :--- |
| RD-01 | até 2 reservas futuras por unidade | `reservas_user_page._criarReserva` — conta reservas da unidade com status ativo e `hora_fim > agora`; bloqueia em `>= 2` | ✅ implementada (client-side) |
| RD-02 | salão com antecedência mínima de 48 h | `reservas_user_page._criarReserva` — detecta `'salão'`/`'salao'` no nome e compara com `now + 48h` | ✅ implementada (por substring do nome) |
| RD-03 | sem duas reservas da unidade no mesmo horário | `reservas_user_page._criarReserva` — interseção de intervalos na mesma data | ✅ implementada (conflito **por unidade**) |
| RD-04 | salão e churrasqueira exigem aprovação | `analise_page` lista pendentes e aprova/recusa | ⚠️ parcial: **toda** reserva nasce `PENDENTE`; não há distinção por espaço |
| RD-05 | cancelamento com antecedência mínima de 24 h | `reservas_service.cancelarReserva` — aplica **somente se `status == 'ACEITA'`** | ⚠️ parcial: reservas `PENDENTE` canceláveis a qualquer momento |
| RD-06 | reserva vinculada a uma unidade | `reservas_user_page` valida `id_apartamento`; `firestore.rules` exige `id_unidade` não vazio | ✅ implementada em app + regra |
| RD-07 | respeitar horário de funcionamento | `reservas_user_page._criarReserva` compara com abertura/fechamento do espaço | ✅ implementada |

### 10.1 Regras efetivas no código, ausentes na documentação de domínio

| Regra efetiva | Local | Ausente em `domain_rules.md` |
| :--- | :--- | :--- |
| Uma reserva por espaço por **dia** | `reservas_user_page._criarReserva`, `reservas_service.criarReserva`, `reservas_service.reagendarReserva` | ✅ ausente |
| Capacidade máxima = `espacos.qtd_pessoas` | `reservas_user_page._criarReserva` | ✅ ausente |
| `hora_inicio` estritamente menor que `hora_fim` | `reservas_user_page`, `reservas_admin_page`, `space_page` | ✅ ausente |
| Interditar espaço rejeita em lote as reservas associadas | `space_page._atualizarReservasAssociadas` | ✅ ausente |
| Unicidade de `id_apartamento` entre usuários | `user_service.addUserWithPassword` / `updateUser` | ✅ ausente |

---

## 11. Requisitos × implementação

Fonte: `doc/requirements.md`.

| ID | Requisito | Cobertura observada |
| :--- | :--- | :--- |
| RF-01 | autenticação do morador | `login_page` + `AuthService.login` ✅ |
| RF-02 | consultar espaços comuns | `space_page` (lista + filtro disponível/indisponível) ✅ |
| RF-03 | disponibilidade por data e horário | ⚠️ parcial — `space_page` exibe ficha e `reservas_user_page` bloqueia conflito no ato da reserva; não há tela dedicada. `calendar_page` (órfã) faria isso, mas usa `SharedPreferences` |
| RF-04 | solicitar reserva | `reservas_user_page` ✅ |
| RF-05 | morador consulta suas reservas | `minhas_reservas_page` (stream por `id_morador`) ✅ |
| RF-06 | cancelamento quando regras atendidas | `ReservasService.cancelarReserva` ✅ (ver RD-05) |
| RF-07 | admin aprova/recusa | `analise_page` ✅ |
| RF-08 | admin cadastra/altera/inativa moradores | `user_crud` + `user_service` ✅ |
| RF-09 | admin cadastra/altera espaços | `space_page` ✅; `deleteSpace` existe no service mas **o botão de exclusão foi removido da UI** (`// Removendo o botão de exclusão`) |
| RF-10 | histórico das reservas | `dashboard_relatorio` ✅ inventário; ⚠️ sem trilha de auditoria de alterações |
| RNF-01 | acesso administrativo protegido | ⚠️ apenas por `role` no client; servidor aberto (§7.2) |
| RNF-02 | controle de acesso por perfil | ⚠️ idem |
| RNF-03 | interface de fácil utilização | Material Design, navegação por drawer ✅ (não mensurável por código) |
| RNF-04 | resposta adequada nas consultas | `StreamBuilder` em listas, `FutureBuilder` + `Future.wait` em agregações ✅ |
| RNF-05 | consistência dos dados | ⚠️ parcial — `runTransaction` no cancelamento e `batch` em notificações/interdição; a **criação de reserva não é transacional** |
| RNF-06 | mecanismo de backup | ❌ **nenhum código ou configuração de backup localizado** |

---

## 12. Camada Data Connect (`dataconnect/`)

Presente e completa, mas **não conectada ao app**:

- `dataconnect.yaml`: `specVersion v1`, `serviceId projetoihc`, `location southamerica-east1`, datasource `postgresql` (Cloud SQL `projetoihc-fdc`, database `fdcdb`), `connectorDirs ["./example"]`.
- `schema/schema.gql`: tipos `User`, `CommonArea`, `Booking`, `Rule`, `Availability` (`@table`).
- `example/queries.gql`: `AddNewBooking`, `ListCommonAreas`, `UpdateUserUnitNumber`, `GetMyBookings` com `@auth(level: …)`.
- `seed_data.gql`: mutation `SeedData` com 2 usuários, 2 áreas e 2 reservas genéricas ("Meeting Room 1", "Cafeteria").

**Não há** seção `dataconnect` em `firebase.json` nem dependência `firebase_data_connect` em `pubspec.yaml` (o `firebase.json` contém apenas `flutter.platforms`).

Modelo relacional proposto (não em uso) difere do modelo real em Firestore:

| Data Connect (SQL) | Firestore (real) |
| :--- | :--- |
| `Booking.bookingDate: Date` + `startTime`/`endTime: String` | `data_reserva: Timestamp` + `hora_inicio`/`hora_fim: String` |
| `Booking.user: User!` (FK) | `id_morador` (string solta) |
| `CommonArea.bookingDuration: Int!` | `qtd_pessoas`, `custo_reserva`, horários |
| `Rule` / `Availability` (tabelas próprias) | `regras_uso` (texto) e horários no próprio espaço |

⚠️ Não determinado a partir do código se este diretório é migração planejada ou resíduo do template FlutterFire Data Connect.

---

## 13. Testes

| Arquivo | Conteúdo | Situação |
| :--- | :--- | :--- |
| `test/widget_test.dart` | `testWidgets('Counter increments smoke test')` — monta `MyApp`, espera textos `'0'`/`'1'`, toca `Icons.add` | ⚠️ **incoerente com o app**: resquício do template de contador. Não há contador nem `Icons.add` na home (o FAB é `FloatingActionButton.extended` rotulado "Relatório"). Também instancia `AuthService`/`UserService` sem `Firebase.initializeApp` |

Não há testes de unidade para `ReservasService`, `SpaceService`, `UserService` ou `AuthService`, nem testes de widget para páginas. Cobertura observada: **apenas o arquivo de template**.

---

## 14. Análise estática

`analysis_options.yaml`: `include: package:flutter_lints/flutter.yaml`; exclusões de `build/**`, `android/**`, `ios/**`, `web/**`, `windows/**`, `macos/**`, `linux/**`. Nenhuma regra customizada habilitada/desabilitada; bloco `linter.rules` apenas com exemplos comentados.

---

## 15. Documentação pré-existente no repositório

Arquivos `.md` na raiz (preservados, não editados nesta tarefa):

| Arquivo | Natureza |
| :--- | :--- |
| `README.md` | visão geral do produto (SIGEC) |
| `doc/requirements.md` | RF-01..RF-10, RNF-01..RNF-06 |
| `doc/domain_rules.md` | RD-01..RD-07 |
| `doc/doc-plan.md` | plano de geração desta documentação (define o artefato monolito HTML) |
| `FLUXO_VALIDACAO_LOGIN.md` | fluxo de `ind_habilitado` |
| `GUIA_TESTES_IND_HABILITADO.md` | 8 cenários manuais de teste |
| `VERIFICACAO_IND_HABILITADO.md`, `VERIFICACAO_FIREBASE_IND_HABILITADO.md` | checklists de verificação |
| `SUMARIO_IND_HABILITADO.md` | resumo da implementação de `ind_habilitado` |
| `CONSOLIDACAO_USER_CRUD.md`, `CONSOLIDACAO_CONCLUIDA.md`, `SUMARIO_CONSOLIDACAO_USER_CRUD.md`, `RELATORIO_FINAL_CONSOLIDACAO.md` | registro histórico da unificação de `user_crud.dart` |
| `cenarios_testes_funcionais.html`, `cenarios_testes_funcionais.doc` | cenários funcionais |
| `ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md` | boilerplate do template iOS |

### 15.1 Divergência documentação × código

`SUMARIO_IND_HABILITADO.md` e `VERIFICACAO_IND_HABILITADO.md` descrevem um **container vermelho de erro** e um **dropdown de Status (`ind_habilitado`)** em `login_page.dart` / `user_crud.dart`.

O código atual **não** apresenta esses elementos:

- `login_page.dart` exibe erros por `SnackBar` com mensagem genérica `'❌ Login ou Senha inválidos'` — não há container vermelho nem distinção entre "Usuário não encontrado", "Usuário inválido" e "Senha incorreta".
- `user_crud.dart` não possui dropdown de `ind_habilitado`; o campo é **preservado** de `user.ind_habilitado` na edição, mas **não é editável** pela UI.

A validação de `ind_habilitado` em `auth_service.dart` **está** implementada conforme documented (login, `verifyCredentials`, `loadUserFromPreferences`).

---

## 16. Resumo de achados para a fase de escopo

| Categoria | Achado |
| :--- | :--- |
| Código morto | 5 arquivos (2.7, 4.1) |
| Duplicação de modelo | 2 classes `User` incompatíveis |
| Duplicação de constante | `ReservaSortOption` declarado em `all_reservas_user_page.dart` e `minhas_reservas_page.dart` |
| Serviço órfão | `ReservasService.criarReserva`, `.aprovarOuRecusarReserva`, `.reagendarReserva` sem consumidor na UI |
| Serviço parcialmente usado | `SpaceService.deleteSpace` sem botão na UI |
| Vocabulário divergente | `APROVADA`/`RECUSADA` vs `ACEITA`/`REJEITADA` (§8) |
| Estado não produzido | `REALIZADA` |
| Regra não implementada | RNF-06 (backup) |
| Segurança | `firestore.rules` aberto; senha em texto plano |
| Teste | único arquivo é boilerplate incoerente |
| Naming | pacote `flutter_application_1` vs produto SIGEC |

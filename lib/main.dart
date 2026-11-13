import 'package:flutter_application_1/pages/all_reservas_user_page.dart';
import 'package:flutter_application_1/pages/analise_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'package:flutter_application_1/pages/login_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/pages/reservas_admin_page.dart';
import 'package:flutter_application_1/pages/minhas_reservas_page.dart';
import 'package:flutter_application_1/pages/space_page.dart';
import 'package:flutter_application_1/services/auth_service.dart';

import 'package:flutter_application_1/services/reservas_service.dart';
import 'package:flutter_application_1/services/space_service.dart';
import 'package:flutter_application_1/services/user_service.dart';
import 'package:flutter_application_1/pages/user_crud.dart';
import 'package:flutter_application_1/pages/notifications_page.dart';
import 'firebase_options.dart';
import 'package:flutter_application_1/pages/documentacao.dart';
import 'package:flutter_application_1/pages/dashboard_relatorio.dart';

/// Ponto de entrada do SIGEC.
///
/// Inicializa os bindings do Flutter, o Firebase com as opções da plataforma
/// corrente, restaura a sessão salva por [AuthService.loadUserFromPreferences]
/// e publica a árvore de widgets.
///
/// A sessão é restaurada antes de `runApp`, portanto a primeira renderização
/// já reflete o estado autenticado — não há tela de splash.
///
/// Em plataformas sem configuração Firebase (Linux), a inicialização lança
/// `UnsupportedError`.
// ...existing code...
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar o Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final authService = AuthService();
  await authService.loadUserFromPreferences();

  final userService = UserService();

  runApp(MyApp(authService: authService, userService: userService));
}

/// Raiz da aplicação.
///
/// Constrói o [MaterialApp] e decide a tela inicial conforme o estado de
/// autenticação: [MyHomePage] quando há sessão ativa, [LoginPage] caso
/// contrário. A alternância é reativa, pois `home` é um `AnimatedBuilder`
/// que escuta [AuthService].
class MyApp extends StatelessWidget {
  /// Serviço de autenticação compartilhado por toda a aplicação.
  final AuthService authService;
  /// Serviço de usuários compartilhado pelas telas administrativas.
  final UserService userService;

  const MyApp({Key? key, required this.authService, required this.userService})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, //remove a faixa de debug
      title: 'Condomínio App',
      theme: ThemeData(primarySwatch: Colors.blue),  
      home: AnimatedBuilder(
        animation: authService,
        builder: (context, _) {
          if (authService.isAuthenticated) {
            return MyHomePage(
              title: 'Bem-vindo ao Condomínio',
              authService: authService,
              userService: userService,
            );
          } else {
            return LoginPage(authService: authService);
          }
        },
      ),
    );
  }
}

/// Shell da área autenticada.
///
/// Provê a barra superior com contador de notificações não lidas, o menu
/// lateral com itens condicionados ao papel do usuário, a saudação com o nome
/// do morador e os atalhos da tela inicial.
class MyHomePage extends StatefulWidget {
  /// Serviço de autenticação, usado para obter o papel e o login correntes.
  final AuthService authService;
  /// Serviço de usuários, repassado às telas administrativas.
  final UserService userService;

  const MyHomePage({
    super.key,
    required this.title,
    required this.authService,
    required this.userService,
  });
  /// Título exibido na barra superior.
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // Lista dos espaços do condomínio

  /// Serviço de espaços criado sob demanda.
  ///
  /// Observação: cada acesso instancia uma nova cópia, não havendo estado
  /// compartilhado entre chamadas.
  SpaceService get _spaceService => SpaceService();

  /// Serviço de reservas criado sob demanda.
  ReservasService get _reservasService => ReservasService();

  /// Serviço de autenticação criado sob demanda.
  ///
  /// Atenção: retorna uma instância distinta daquela recebida via `widget`
  /// e não é utilizada no `build`.
  AuthService get _authService => AuthService();

  @override
  Widget build(BuildContext context) {
    
    final currentUserId = widget.authService.currentUser?.username;
    return Scaffold(
      // Barra superior
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          // ÍCONE DE NOTIFICAÇÕES
          if (currentUserId != null) 
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notificacoes')
                  .where('destinatario_id', isEqualTo: currentUserId) // Usa o username do seu AuthService
                  .where('lida', isEqualTo: false)
                  .snapshots(),
              builder: (context, snapshot) {
                int unreadCount = 0;
                if (snapshot.hasData) {
                  unreadCount = snapshot.data!.docs.length;
                }

                return Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                NotificationsPage(userId: currentUserId), // Passa o username
                          ),
                        );
                      },
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),

      // MENU LATERAL - Navegação dos espaços
      drawer: Drawer(
        child: Column(
          children: [
            // Cabeçalho do menu
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.indigo, Colors.blue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.apartment, size: 60, color: Colors.white),
                  SizedBox(height: 10),
                  Text(
                    '🏢 Espaços do Condomínio',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Gestão e Reservas',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),

            // Lista de espaços no menu lateral
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.meeting_room,
                      color: Colors.indigo,
                    ),
                    title: const Text('Espaços'),
                    subtitle: Text(
                      widget.authService.currentUser!.role.toLowerCase() ==
                              'admin'
                          ? 'Criar, editar e gerenciar espaços'
                          : 'Visualizar Espaços',
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SpacesPage(
                            spaceService: _spaceService,
                            isAdmin:
                                widget.authService.currentUser?.role
                                    .toLowerCase() ==
                                'admin',
                          ),
                        ),
                      );
                    },
                  ),
                  if (widget.authService.currentUser?.role == 'admin') ...[
                    const Divider(),
                    ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.supervisor_account,
                        color: Colors.indigo,
                      ),
                      title: const Text('Gerenciar Usuários'),
                      subtitle: const Text('Criar, editar e remover usuários'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                UserCrudPage(userService: widget.userService),
                          ),
                        );
                      },
                    ),
                  ],
                  const Divider(),
                  ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.book_online,
                      color: Colors.indigo,
                    ),
                    title: const Text('Reservas'),
                    subtitle: Text(
                      widget.authService.currentUser?.role == 'admin'
                          ? 'Visualizar e gerenciar reservas'
                          : 'Gerenciar minhas reservas',
                    ),
                    onTap: () {
                      Navigator.pop(context);

                      if (widget.authService.currentUser?.role == 'admin') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ReservasAdminPage(
                              authService: widget.authService,
                            ),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MinhasReservasPage(
                              userId:
                                  widget.authService.currentUser?.username ??
                                  '',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  if (widget.authService.currentUser?.role == 'admin') ...[
                    const Divider(),
                    ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.analytics,
                        color: Colors.indigo,
                      ),
                      title: const Text('Análise de Reservas'),
                      subtitle: const Text('Reservas pendentes'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AnalisePage(),
                          ),
                        );
                      },
                    ),
                  ],
                  const Divider(),
                  if (widget.authService.currentUser?.role == 'user') ...[
                    ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.calendar_month,
                        color: Colors.indigo,
                      ),
                      title: const Text('Reservar Espaço'),
                      subtitle: const Text('Visualizar e reservar espaço'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AllReservasUserPage(
                            userId:
                                  widget.authService.currentUser?.username ??
                                  '',
                          )),
                        );
                      },
                    ),                               
                  ],
                  if (widget.authService.currentUser?.role == 'user') ...[
                  const Divider(),
                  ],
                  ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.info_outline,
                      color: Colors.indigo,
                    ),
                    title: const Text('Sobre'),
                    subtitle: const Text('Documentação do sistema'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DocumentacaoPage(),
                        ),
                      );
                    },
                  ),
                  if (widget.authService.currentUser?.role == 'admin') ...[
                  const Divider(),
                  ListTile(
                    dense: true,
                    leading: const Icon(
                        Icons.bar_chart,
                        color: Colors.indigo,
                      ),
                    title: const Text('Relatório'),
                     subtitle: const Text('Estatísticas de utilização'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>  const DashboardRelatorioPage(),
                        ),
                      );
                    },
                  ),
                  ],
                  const Divider(),
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text('Sair'),
                    onTap: () async {
                      await widget.authService.logout();
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),

            // Rodapé do menu
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(children: [const Divider()]),
            ),
          ],
        ),
      ),

      // Corpo principal - Dashboard
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cartão de boas-vindas
            Card(
              elevation: 4,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: [
                      Colors.indigo.withValues(alpha:0.1),
                      Colors.blue.withValues(alpha:0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: FutureBuilder<DocumentSnapshot>(
                  // 1. A BUSCA: Vai no banco buscar os dados desse usuário
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(currentUserId)
                      .get(),
                  builder: (context, snapshot) {
                    // Valor padrão enquanto carrega ou se der erro
                    String nomeExibicao = currentUserId ?? 'Morador';
                    String? papel = widget.authService.currentUser?.role;

                    // 2. Se os dados chegaram, tenta pegar o campo 'nome'
                    if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
                      final dados = snapshot.data!.data() as Map<String, dynamic>;
                      if (dados['nome'] != null) {
                        nomeExibicao = dados['nome'];
                      }
                    }

                    // 3. A EXIBIÇÃO: O layout existente
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bem-vindo, $nomeExibicao! 👋', 
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Papel: ${papel == 'admin' ? 'Administrador' : 'Usuário'}',
                          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Acesso rápido aos espaços
            // Acesso rápido — condicional por role
            widget.authService.currentUser?.role.toLowerCase() == 'admin'
                ?
                  //CARD PARA ADMIN
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SpacesPage(
                              spaceService: _spaceService,
                              isAdmin:
                                  widget.authService.currentUser?.role
                                      .toLowerCase() ==
                                  'admin',
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 16.0,
                          horizontal: 16.0,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.meeting_room,
                              size: 36,
                              color: Colors.indigo,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Gerenciar Espaços',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Criar, editar e gerenciar espaços públicos',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                :
                  //CARD PARA USER
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MinhasReservasPage(
                              userId:
                                  widget.authService.currentUser?.username ??
                                  '',
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 16.0,
                          horizontal: 16.0,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.book_online,
                              size: 36,
                              color: Colors.indigo,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Minhas Reservas',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Gerenciar minhas reservas',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

            const SizedBox(height: 20),
            widget.authService.currentUser?.role.toLowerCase() == 'admin'
                ?
                  //CARD PARA ADMIN
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AnalisePage(),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 16.0,
                          horizontal: 16.0,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.analytics,
                              size: 36,
                              color: Colors.indigo,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Análise de Reservas',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Aprovar ou rejeitar reservas pendentes',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : const SizedBox(height: 12),
          ],
        ),
      ),

      // Botão de ação flutuante
      floatingActionButton: widget.authService.currentUser?.role == 'admin'
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DashboardRelatorioPage(),
                  ),
                );
              },
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              label: const Text('Relatório'),
              icon: const Icon(Icons.analytics),
            )
          : null,
    );
  }
}


/// Monta uma linha de relatório com rótulo à esquerda e valor destacado.
///
/// Desenha uma borda esquerda de 4 px na cor informada. Não é referenciada
/// por nenhuma tela — código órfão dentro de um arquivo ativo.
Widget _buildReportRow(String label, String value, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white10,
      border: Border(left: BorderSide(color: color, width: 4)), // << fixed here
      borderRadius: BorderRadius.circular(4),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    ),
  );
}

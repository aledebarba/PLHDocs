// Home page with role-based access
/// Tela inicial alternativa com conteúdo por papel.
///
/// Código órfão: nenhum arquivo a importa e não é alcançável a partir de
/// `main.dart`. Os botões «Manage Users» e «View Profile» não possuem ação
/// implementada. A tela efetivamente usada é `MyHomePage`, em `main.dart`.
import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/auth_service.dart';


//========================================
// !! VERIFICAR SE ESSA PAGINA É USADA  !!
//========================================


/// Página inicial por papel (não utilizada).
class HomePage extends StatelessWidget {
  /// Serviço de autenticação de onde se obtém o usuário corrente.
  final AuthService authService;

  const HomePage({super.key, required this.authService});

  @override
  Widget build(BuildContext context) {
    final user = authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, ${user?.username}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              authService.logout();
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (user?.role == 'admin') ...[
              const Text('Admin Dashboard'),
              ElevatedButton(
                onPressed: () {
                  // Navigate to admin-specific page
                },
                child: const Text('Manage Users'),
              ),
            ] else if (user?.role == 'user') ...[
              const Text('User Dashboard'),
              ElevatedButton(
                onPressed: () {
                  // Navigate to user-specific page
                },
                child: const Text('View Profile'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
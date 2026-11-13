/// Autenticação, sessão e revalidação de habilitação de usuários do SIGEC.
///
/// O SIGEC **não** utiliza Firebase Authentication. A autenticação é própria:
/// o serviço consulta a coleção `users` pelo campo `login`, compara o campo
/// `senha` em texto plano e verifica o indicador `ind_habilitado` (`'S'` ou
/// `'N'`).
///
/// A sessão é persistida em `SharedPreferences` (chaves `username`, `role` e
/// `ind_habilitado`) e revalidada contra o Firestore na inicialização do app.
///
/// Como estende [ChangeNotifier], `MyApp` escuta este serviço por meio de um
/// `AnimatedBuilder` e alterna automaticamente entre a tela de login e a home
/// quando a sessão muda.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

/// Representação mínima de usuário usada pelo serviço de autenticação.
///
/// Não confundir com `User` de `lib/models/user.dart`: esta versão não
/// possui o campo `extra` nem os métodos `fromMap`/`toMap`. As duas
/// classes são tipos distintos e incompatíveis.
class User {
  /// Identificador de login do usuário.
  final String username;
  /// Papel do usuário: `'admin'` ou `'user'`.
  final String role;
  /// Indicador de habilitação: `'S'` (habilitado) ou `'N'` (desabilitado).
  final String ind_habilitado;

  User({
    required this.username,
    required this.role,
    this.ind_habilitado = 'S',
  });
}

/// Serviço de autenticação e sessão.
///
/// Mantém o usuário autenticado em memória e notifica os ouvintes a cada
/// login, logout ou restauração de sessão.
class AuthService extends ChangeNotifier {
  /// Usuário autenticado em memória; `null` quando não há sessão ativa.
  User? _currentUser;

  /// Usuário autenticado no momento, ou `null` se não houver sessão.
  User? get currentUser => _currentUser;

  /// Indica se existe uma sessão ativa.
  bool get isAuthenticated => _currentUser != null;

  // Login e autenticação com Firestore
  /// Autentica um usuário contra a coleção `users`.
  ///
  /// Sequência de verificação: existência do documento pelo campo `login`,
  /// habilitação (`ind_habilitado` deve ser `'S'`) e conferência da senha em
  /// texto plano.
  ///
  /// Em caso de credencial inválida lança [Exception] com as mensagens
  /// `'Usuário não encontrado'`, `'Usuário inválido'` ou `'Senha incorreta'`.
  /// Em sucesso, persiste a sessão em `SharedPreferences` e chama
  /// [notifyListeners].
  Future<void> login(String username, String password) async {
    try {
      // Buscar o usuário no Firestore
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('login', isEqualTo: username)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw Exception('Usuário não encontrado');
      }

      final userDoc = querySnapshot.docs.first;
      final userData = userDoc.data();

      // Verificar se o usuário está habilitado
      final ind_habilitado = userData['ind_habilitado'] ?? 'S';
      if (ind_habilitado != 'S') {
        throw Exception('Usuário inválido');
      }

      // Verificar a senha
      if (userData['senha'] != password) {
        throw Exception('Senha incorreta');
      }

      // Criar o usuário autenticado
      _currentUser = User(
        username: userData['login'],
        role: userData['role'],
        ind_habilitado: ind_habilitado,
      );

      // Salvar o perfil no SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('username', _currentUser!.username);
      await prefs.setString('role', _currentUser!.role);
      await prefs.setString('ind_habilitado', _currentUser!.ind_habilitado);

      notifyListeners();
    } catch (e) {
      throw Exception('Erro ao autenticar: $e');
    }
  }

  // Verifica credenciais sem alterar a sessão atual. Retorna o User se válido.
  /// Confere credenciais **sem** alterar a sessão atual.
  ///
  /// Aplica as mesmas verificações de [login], mas não grava em
  /// `SharedPreferences` nem notifica ouvintes. Devolve o usuário validado.
  /// Usado para reautenticar o morador antes de operações sensíveis.
  Future<User> verifyCredentials(String username, String password) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('login', isEqualTo: username)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw Exception('Usuário não encontrado');
      }

      final userDoc = querySnapshot.docs.first;
      final userData = userDoc.data();

      // Verificar se o usuário está habilitado
      final ind_habilitado = userData['ind_habilitado'] ?? 'S';
      if (ind_habilitado != 'S') {
        throw Exception('Usuário inválido');
      }

      if (userData['senha'] != password) {
        throw Exception('Senha incorreta');
      }

      return User(
        username: userData['login'],
        role: userData['role'],
        ind_habilitado: ind_habilitado,
      );
    } catch (e) {
      throw Exception('Erro ao verificar credenciais: $e');
    }
  }

  // Logout e limpar os dados locais
  /// Encerra a sessão.
  ///
  /// Anula o usuário em memória, executa `prefs.clear()` — removendo também
  /// o cache `users_list` de `UserService` — e notifica os ouvintes.
  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }

  // Carregar o perfil salvo ao iniciar o app
  /// Restaura a sessão salva e a revalida contra o Firestore.
  ///
  /// Se o documento indicar `ind_habilitado` diferente de `'S'`, o cache é
  /// limpo e o usuário precisa autenticar-se novamente. Se a consulta ao
  /// Firestore falhar (por exemplo, sem conexão), a sessão do cache é
  /// mantida como fallback — um usuário desabilitado offline só será
  /// desconectado quando a rede retornar.
  Future<void> loadUserFromPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('username');
    final role = prefs.getString('role');
    final ind_habilitado = prefs.getString('ind_habilitado') ?? 'S';

    // Verificar se os valores não são nulos antes de criar o objeto User
    if (username != null && role != null) {
      // Validar novamente no Firestore para garantir que o usuário ainda está habilitado
      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('login', isEqualTo: username)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final userData = querySnapshot.docs.first.data();
          final firestoreIndHabilitado = userData['ind_habilitado'] ?? 'S';
          
          // Se o usuário foi desabilitado no Firestore, não carregá-lo
          if (firestoreIndHabilitado != 'S') {
            _currentUser = null;
            await prefs.clear();
            notifyListeners();
            return;
          }
        }
      } catch (e) {
        // Se houver erro ao consultar Firestore, carregue do cache local
        // (continuará a execução abaixo)
      }
      
      _currentUser = User(username: username, role: role, ind_habilitado: ind_habilitado);
      notifyListeners();
    } else {
      _currentUser = null; // Garantir que _currentUser seja null se os dados não forem encontrados
    }
  }
}
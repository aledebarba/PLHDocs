/// Modelo de usuário do SIGEC com mapeamento bidirecional para o Firestore.
///
/// Mantém como propriedades explícitas os três campos estruturais usados em
/// regras de negócio — login, papel e indicador de habilitação — e agrupa em
/// `extra` todo o restante do documento: tipicamente `nome`, `cpf`, `email`,
/// `telefone`, `id_apartamento` e `data_cadastro`.
///
/// Atenção: existe uma segunda classe `User`, declarada em
/// `lib/services/auth_service.dart`, sem o campo `extra` e sem os métodos de
/// mapeamento. As duas são tipos distintos e incompatíveis; `AuthService`
/// opera sobre a versão de `auth_service.dart`.
class User {
  /// Identificador de login; corresponde ao campo `login` no Firestore.
  final String username;
  final String role; // Exemplo: 'admin' ou 'user'
  final String ind_habilitado; // 'S' (habilitado) ou 'N' (desabilitado)
  final Map<String, dynamic>? extra; // Campos adicionais (nome, telefone, email, etc.)

  /// Cria um usuário.
  ///
  /// `ind_habilitado` assume `'S'` por padrão, de modo que usuários criados
  /// sem indicação explícita nasçam habilitados.
  User({
    required this.username,
    required this.role,
    this.ind_habilitado = 'S',
    this.extra,
  });

  // Converter de/para map para facilitar leitura/escrita no Firestore
  /// Constrói um usuário a partir de um documento do Firestore.
  ///
  /// [id] é o identificador do documento e serve como último recurso para
  /// resolver o login, dando suporte a registros legados gravados apenas
  /// com `username` ou sem campo de login explícito.
  ///
  /// [data] é o mapa do documento. Os campos `login`, `username`, `role`,
  /// `ind_habilitado` e `senha` são removidos da cópia que alimenta `extra`,
  /// restando apenas os campos não modelados.
  factory User.fromMap(String id, Map<String, dynamic> data) {
    final login = (data['login'] ?? data['username'] ?? id) as String;
    final role = (data['role'] ?? 'user') as String;
    final ind = (data['ind_habilitado'] ?? 'S') as String;

    // Remover campos conhecidos para deixar apenas extras
    final extras = Map<String, dynamic>.from(data);
    extras.remove('login');
    extras.remove('username');
    extras.remove('role');
    extras.remove('ind_habilitado');
    extras.remove('senha');

    return User(username: login, role: role, ind_habilitado: ind, extra: extras);
  }

  /// Serializa o modelo para gravação no Firestore.
  ///
  /// Sempre inclui `login`, `role` e `ind_habilitado`. O campo `senha` só é
  /// incluído quando fornecido em [senha] — padrão usado por
  /// `UserService.updateUser` para preservar a senha existente ao renomear
  /// um usuário.
  ///
  /// As entradas de `extra` são mescladas ao final do mapa, portanto uma
  /// chave homônima em `extra` sobrescreveria os campos estruturais.
  Map<String, dynamic> toMap({String? senha}) {
    final m = <String, dynamic>{
      'login': username,
      'role': role,
      'ind_habilitado': ind_habilitado,
    };
    if (senha != null) m['senha'] = senha;
    if (extra != null) {
      for (final e in extra!.entries) {
        m[e.key] = e.value;
      }
    }
    return m;
  }
}
/// Gestão de moradores: listagem, criação, edição e exclusão.
///
/// A lista é sincronizada com `UserService`, que combina Firestore e cache
/// local. A criação exige senha e valida CPF, telefone e unicidade de
/// apartamento; a edição preserva a senha e o indicador de habilitação.
///
/// Observação: o campo `ind_habilitado` não é editável pela interface, ainda
/// que seja respeitado pelo serviço de autenticação.
import 'package:flutter/material.dart';
import 'package:flutter_application_1/models/user.dart';
import 'package:flutter_application_1/services/user_service.dart';
import 'package:flutter/services.dart';

// --- 1. ENUMS PARA CONTROLE ---
/// Critério de ordenação da lista de usuários.
enum UserSortOption { nome, apartamento }
/// Filtro por papel; `usuario` abrange qualquer papel diferente de `admin`.
enum UserFilterOption { todos, admin, usuario }

// --- FORMATTERS (MANTIDOS) ---
/// Aplica máscara progressiva de CPF, limitada a 11 dígitos.
class CpfInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 11) digits = digits.substring(0, 11);
    String formatted = '';
    if (digits.length <= 3) {
      formatted = digits;
    } else if (digits.length <= 6) {
      formatted = '${digits.substring(0, 3)}.${digits.substring(3)}';
    } else if (digits.length <= 9) {
      formatted = '${digits.substring(0, 3)}.${digits.substring(3, 6)}.${digits.substring(6)}';
    } else {
      formatted = '${digits.substring(0, 3)}.${digits.substring(3, 6)}.${digits.substring(6, 9)}-${digits.substring(9)}';
    }
    return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
  }
}

/// Aplica máscara progressiva de telefone, limitada a 11 dígitos.
class TelefoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 11) digits = digits.substring(0, 11);
    String formatted = '';
    if (digits.length <= 2) {
      formatted = '($digits';
    } else if (digits.length <= 6) {
      formatted = '(${digits.substring(0, 2)})${digits.substring(2)}';
    } else if (digits.length <= 10) {
      formatted = '(${digits.substring(0, 2)})${digits.substring(2, 7)}-${digits.substring(7)}';
    } else {
      formatted = '(${digits.substring(0, 2)})${digits.substring(2, 7)}-${digits.substring(7, 11)}';
    }
    return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
  }
}

/// Página «Gerenciar Usuários».
class UserCrudPage extends StatefulWidget {
  /// Serviço de usuários compartilhado com a aplicação.
  final UserService userService;
  const UserCrudPage({Key? key, required this.userService}) : super(key: key);

  @override
  State<UserCrudPage> createState() => _UserCrudPageState();
}

class _UserCrudPageState extends State<UserCrudPage> {
  /// Cópia local da lista de usuários exibida na tela.
  List<User> _users = [];
  
  // --- 2. VARIÁVEIS DE ESTADO (NOVO) ---
  /// Critério de ordenação vigente.
  UserSortOption _criterioOrdenacao = UserSortOption.nome;
  /// Direção da ordenação; `true` para ascendente.
  bool _ordemCrescente = true;
  /// Filtro de papel vigente.
  UserFilterOption _filtroAtual = UserFilterOption.todos;

  @override
  void initState() {
    super.initState();
    _users = widget.userService.users;
    widget.userService.addListener(_onUsersChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reloadUsers();
    });
  }

  /// Recarrega a lista a partir do serviço e sincroniza o estado local.
  Future<void> _reloadUsers() async {
    await widget.userService.loadUsers();
    if (mounted) {
      setState(() {
        _users = widget.userService.users;
      });
    }
  }

  @override
  void dispose() {
    widget.userService.removeListener(_onUsersChanged);
    super.dispose();
  }

  /// Sincroniza o estado local quando o serviço notifica alterações.
  void _onUsersChanged() {
    if (!mounted) return;
    setState(() {
      _users = widget.userService.users;
    });
  }

  // --- 3. UI: BOTTOM SHEET DE FILTROS (NOVO) ---
  /// Abre o painel de filtro por papel e ordenação.
  void _mostrarOpcoesFiltro() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Filtrar por Papel", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8.0,
                    children: [
                      _buildFilterChip('Todos', UserFilterOption.todos, setModalState),
                      _buildFilterChip('Administradores', UserFilterOption.admin, setModalState, color: Colors.purple),
                      _buildFilterChip('Usuários', UserFilterOption.usuario, setModalState, color: Colors.blue),
                    ],
                  ),
                  const Divider(height: 30),
                  const Text("Ordenar por", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ListTile(
                    leading: const Icon(Icons.sort_by_alpha),
                    title: const Text("Nome"),
                    trailing: _criterioOrdenacao == UserSortOption.nome 
                        ? Icon(_ordemCrescente ? Icons.arrow_upward : Icons.arrow_downward, color: Colors.indigo) 
                        : null,
                    onTap: () => _atualizarOrdenacao(UserSortOption.nome, setModalState),
                  ),
                  ListTile(
                    leading: const Icon(Icons.apartment),
                    title: const Text("Apartamento"),
                    trailing: _criterioOrdenacao == UserSortOption.apartamento
                        ? Icon(_ordemCrescente ? Icons.arrow_upward : Icons.arrow_downward, color: Colors.indigo) 
                        : null,
                    onTap: () => _atualizarOrdenacao(UserSortOption.apartamento, setModalState),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Monta um chip de seleção de papel.
  Widget _buildFilterChip(String label, UserFilterOption valor, StateSetter setModalState, {Color? color}) {
    final bool selected = _filtroAtual == valor;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: color?.withValues(alpha:0.3) ?? Colors.indigo.withValues(alpha:0.3),
      labelStyle: TextStyle(
        color: selected ? (color ?? Colors.indigo) : Colors.black,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal
      ),
      onSelected: (bool isSelected) {
        if (isSelected) {
          setState(() => _filtroAtual = valor);
          setModalState(() {});
        }
      },
    );
  }

  /// Alterna a direção ou troca o critério de ordenação.
  void _atualizarOrdenacao(UserSortOption novoCriterio, StateSetter setModalState) {
    setState(() {
      if (_criterioOrdenacao == novoCriterio) {
        _ordemCrescente = !_ordemCrescente;
      } else {
        _criterioOrdenacao = novoCriterio;
        _ordemCrescente = true;
      }
    });
    setModalState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // --- 4. LÓGICA DE PROCESSAMENTO DA LISTA ---
    // Cria uma cópia da lista original para não alterar a fonte
    var displayUsers = List<User>.from(_users);

    // Filtrar
    if (_filtroAtual != UserFilterOption.todos) {
      displayUsers = displayUsers.where((u) {
        if (_filtroAtual == UserFilterOption.admin) return u.role == 'admin';
        if (_filtroAtual == UserFilterOption.usuario) return u.role != 'admin'; // Assume que tudo != admin é usuário
        return true;
      }).toList();
    }

    // Ordenar
    displayUsers.sort((a, b) {
      int cmp = 0;
      switch (_criterioOrdenacao) {
        case UserSortOption.nome:
          // Tenta pegar o nome no extra, senão usa o username
          String nomeA = (a.extra?['nome']?.toString() ?? a.username).toLowerCase();
          String nomeB = (b.extra?['nome']?.toString() ?? b.username).toLowerCase();
          cmp = nomeA.compareTo(nomeB);
          break;
        case UserSortOption.apartamento:
          // Tenta converter para int para ordenar numericamente (ex: 2 vem antes de 10)
          String aptStrA = a.extra?['id_apartamento']?.toString() ?? '0';
          String aptStrB = b.extra?['id_apartamento']?.toString() ?? '0';
          
          int aptA = int.tryParse(aptStrA) ?? 99999; // Joga pro fim se não for número
          int aptB = int.tryParse(aptStrB) ?? 99999;
          
          if (aptA != aptB) {
            cmp = aptA.compareTo(aptB);
          } else {
            // Se for igual (ou texto), compara como string
            cmp = aptStrA.compareTo(aptStrB);
          }
          break;
      }
      return _ordemCrescente ? cmp : -cmp;
    });

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Gerenciar Usuários', style: TextStyle(fontSize: 20)),
             if (_filtroAtual != UserFilterOption.todos)
              Text(
                _filtroAtual == UserFilterOption.admin ? 'Filtro: Administradores' : 'Filtro: Usuários',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              )
          ],
        ),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
        // Botão de filtro na AppBar
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filtrar e Ordenar',
            onPressed: _mostrarOpcoesFiltro,
          )
        ],
      ),
      body: displayUsers.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _users.isEmpty ? Icons.person_outline : Icons.filter_list_off, // Ícone diferente se for filtro vazio
                    size: 48,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _users.isEmpty 
                    ? 'Nenhum usuário cadastrado' 
                    : 'Nenhum usuário encontrado com este filtro',
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              itemCount: displayUsers.length,
              itemBuilder: (context, index) {
                final user = displayUsers[index];
                return _buildUserCard(context, user);
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showUserForm(),
        backgroundColor: Colors.indigo,
        icon: const Icon(Icons.add),
        label: const Text('Novo Usuário'),
        foregroundColor: Colors.white,
        tooltip: 'Criar novo usuário',
      ),
    );
  }

  /// Monta o cartão de um usuário, com ações de editar e remover.
  Widget _buildUserCard(BuildContext context, User user) {
    final roleName = user.role == 'admin' ? 'Administrador' : 'Usuário';
    final roleColor = user.role == 'admin' ? Colors.purple : Colors.green;
    final apartamento = user.extra?['id_apartamento']?.toString() ?? 'N/A';
    final nome = user.extra?['nome']?.toString() ?? user.username;
    final email = user.extra?['email']?.toString() ?? 'N/A';

    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        margin: const EdgeInsets.only(bottom: 16),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () => _showUserDetails(context, user),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: user.role == 'admin'
                      ? [Colors.purple.shade400, Colors.purple.shade600]
                      : [Colors.lightBlue.shade400, Colors.lightBlue.shade600],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nome,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user.username,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withValues(alpha:0.9),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: roleColor.shade200,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  roleName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: roleColor.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha:0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.white,
                                ),
                                tooltip: 'Editar',
                                onPressed: () => _showUserForm(user: user),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha:0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.white,
                                ),
                                tooltip: 'Remover',
                                onPressed: () => _confirmDelete(user),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(color: Colors.white.withValues(alpha:0.3)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildInfoChip(
                          Icons.apartment,
                          'Apartamento',
                          apartamento,
                        ),
                        _buildInfoChip(Icons.email, 'Email', email),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Monta um bloco informativo com ícone, rótulo e valor.
  Widget _buildInfoChip(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha:0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// Exibe os dados cadastrais de um usuário em um diálogo.
  void _showUserDetails(BuildContext context, User user) {
    final roleName = user.role == 'admin' ? 'Administrador' : 'Usuário';
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(user.extra?['nome']?.toString() ?? user.username),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Login', user.username),
                _buildDetailRow(
                  'Nome',
                  user.extra?['nome']?.toString() ?? 'N/A',
                ),
                _buildDetailRow('Papel', roleName),
                _buildDetailRow('CPF', user.extra?['cpf']?.toString() ?? 'N/A'),
                _buildDetailRow(
                  'Email',
                  user.extra?['email']?.toString() ?? 'N/A',
                ),
                _buildDetailRow(
                  'Telefone',
                  user.extra?['telefone']?.toString() ?? 'N/A',
                ),
                _buildDetailRow(
                  'Apartamento',
                  user.extra?['id_apartamento']?.toString() ?? 'N/A',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showUserForm(user: user);
              },
              child: const Text('Editar'),
            ),
          ],
        );
      },
    );
  }

  /// Monta uma linha rótulo/valor do diálogo de detalhes.
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  /// Abre o formulário de criação ou edição de usuário.
  ///
  /// Quando [user] é nulo, cria um usuário e exige senha (mínimo de quatro
  /// caracteres). Caso contrário, edita os dados cadastrais preservando a
  /// senha e o indicador de habilitação existentes. Erros do serviço são
  /// exibidos no topo do diálogo, que permanece aberto para correção.
  Future<void> _showUserForm({User? user}) async {
    final isEditing = user != null;

    final usernameCtrl = TextEditingController(text: user?.username ?? '');
    final nomeCtrl = TextEditingController(
      text: user?.extra?['nome']?.toString() ?? '',
    );
    final cpfCtrl = TextEditingController(
      text: user?.extra?['cpf']?.toString() ?? '',
    );
    final emailCtrl = TextEditingController(
      text: user?.extra?['email']?.toString() ?? '',
    );
    final telefoneCtrl = TextEditingController(
      text: user?.extra?['telefone']?.toString() ?? '',
    );
    final idApartamentoCtrl = TextEditingController(
      text: user?.extra?['id_apartamento']?.toString() ?? '',
    );
    final passwordCtrl = TextEditingController();

    String role = user?.role ?? 'user';
    String? errorMessage;

    final formKey = GlobalKey<FormState>();
    late StateSetter setDialogState;

    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Editar usuário' : 'Criar usuário'),
        content: StatefulBuilder(
          builder: (context, setState) {
            setDialogState = setState;
            return Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha:0.1),
                            border: Border.all(color: Colors.red),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ),
                    TextFormField(
                      controller: usernameCtrl,
                      decoration: const InputDecoration(labelText: 'Login'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Obrigatório'
                          : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: nomeCtrl,
                      decoration: const InputDecoration(labelText: 'Nome'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Obrigatório'
                          : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: cpfCtrl,
                      decoration: const InputDecoration(labelText: 'CPF'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        CpfInputFormatter(),
                      ], // Formatar CPF automaticamente
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Obrigatório';
                        // Verificar se o CPF está no formato correto (000.000.000-00)
                        if (!RegExp(
                          r'^\d{3}\.\d{3}\.\d{3}-\d{2}$',
                        ).hasMatch(v)) {
                          return 'CPF inválido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(labelText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Obrigatório'
                          : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: telefoneCtrl,
                      decoration: const InputDecoration(labelText: 'Telefone'),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [TelefoneInputFormatter()],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Obrigatório';
                        if (!RegExp(r'^\(\d{2}\)\d{5}-\d{4}$').hasMatch(v)) {
                          return 'Telefone inválido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: idApartamentoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Apartamento',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ], // Permitir apenas números
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Obrigatório';
                        if (int.tryParse(v.trim()) == null)
                          return 'Deve ser numérico';
                        final existing = widget.userService.users
                            .where(
                              (u) =>
                                  u.extra?['id_apartamento']?.toString() ==
                                  v.trim(),
                            )
                            .toList();
                        if (!isEditing && existing.isNotEmpty)
                          return 'Apartamento já cadastrado';
                        if (isEditing) {
                          final others = widget.userService.users
                              .where(
                                (u) =>
                                    u.username != user.username &&
                                    u.extra?['id_apartamento']?.toString() ==
                                        v.trim(),
                              )
                              .toList();
                          if (others.isNotEmpty)
                            return 'Apartamento já cadastrado';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: role,
                      items: const [
                        DropdownMenuItem(value: 'user', child: Text('Usuário')),
                        DropdownMenuItem(
                          value: 'admin',
                          child: Text('Administrador'),
                        ),
                      ],
                      onChanged: (v) => setState(() => role = v ?? 'user'),
                      decoration: const InputDecoration(labelText: 'Papel'),
                    ),
                    const SizedBox(height: 8),
                    if (!isEditing)
                      TextFormField(
                        controller: passwordCtrl,
                        decoration: const InputDecoration(labelText: 'Senha'),
                        obscureText: true,
                        validator: (v) => (v == null || v.trim().length < 4)
                            ? 'Senha (mín 4 caracteres)'
                            : null,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                setDialogState(() => errorMessage = null);

                try {
                  if (isEditing) {
                    final extra = <String, dynamic>{
                      'nome': nomeCtrl.text.trim(),
                      'cpf': cpfCtrl.text.trim().replaceAll(
                        RegExp(r'[^\d]'),
                        '',
                      ), // Remover formatação do CPF
                      'email': emailCtrl.text.trim(),
                      'telefone': telefoneCtrl.text.trim(),
                      'id_apartamento': idApartamentoCtrl.text.trim(),
                    };
                    final updatedUser = User(
                      username: usernameCtrl.text.trim(),
                      role: role,
                      ind_habilitado: user.ind_habilitado,
                      extra: extra,
                    );
                    await widget.userService.updateUser(
                      user.username,
                      updatedUser,
                    );
                    if (mounted) Navigator.pop(context, true);
                  } else {
                    await widget.userService.addUserWithPassword(
                      usernameCtrl.text.trim(),
                      passwordCtrl.text,
                      nomeCtrl.text.trim(),
                      cpfCtrl.text.trim().replaceAll(
                        RegExp(r'[^\d]'),
                        '',
                      ), // Remover formatação do CPF
                      emailCtrl.text.trim(),
                      telefoneCtrl.text.trim(),
                      idApartamentoCtrl.text.trim(),
                      role,
                    );
                    if (mounted) Navigator.pop(context, true);
                  }
                } catch (e) {
                  setDialogState(() => errorMessage = e.toString());
                }
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  /// Confirma e executa a exclusão de um usuário.
  Future<void> _confirmDelete(User user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir usuário'),
        content: Text('Deseja excluir o usuário "${user.username}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await widget.userService.deleteUser(user.username);
    }
  }
}

/// Listagem e gestão dos espaços comuns.
///
/// Exibe os espaços cadastrados com filtro por disponibilidade e ordenação
/// por nome ou capacidade. As ações de criação, edição e interdição aparecem
/// apenas quando [SpacesPage.isAdmin] é verdadeiro.
///
/// Interditar um espaço dispara uma notificação global e rejeita em lote
/// todas as reservas associadas, sem aviso individual ao morador.
import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/space_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'reservas_user_page.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_1/services/notification_service.dart';

// --- ENUMS PARA CONTROLE ---
/// Critério de ordenação da lista de espaços.
enum SpaceSortOption { nome, capacidade }

/// Filtro por disponibilidade aplicado sobre o estado do espaço.
enum SpaceFilterOption { todos, disponivel, indisponivel }

/// Restringe o campo de custo a dígitos e ao intervalo de 0 a 500.
///
/// Valores acima de 500 são rejeitados devolvendo o valor anterior.
class CustoInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Remove qualquer caractere que não seja número
    String digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    // Limita o valor máximo a 500
    final intValue = int.tryParse(digits) ?? 0;
    if (intValue > 500) {
      return oldValue;
    }

    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}

/// Página de espaços comuns.
class SpacesPage extends StatefulWidget {
  /// Serviço de acesso aos espaços.
  final SpaceService spaceService;
  /// Habilita as ações de gestão (criar, editar, interditar).
  final bool isAdmin;
  

  const SpacesPage({Key? key, required this.spaceService, this.isAdmin = false})
    : super(key: key);

  @override
  _SpacesPageState createState() => _SpacesPageState();
}

class _SpacesPageState extends State<SpacesPage> {
  /// Carregamento corrente da lista de espaços.
  late Future<List<Map<String, dynamic>>> _spacesFuture;

  final NotificationService _notificationService = NotificationService();

  // --- VARIÁVEIS DE ESTADO (NOVO) ---
  /// Critério de ordenação vigente.
  SpaceSortOption _criterioOrdenacao = SpaceSortOption.nome;
  /// Direção da ordenação; `true` para ascendente.
  bool _ordemCrescente = true;
  /// Filtro de disponibilidade vigente.
  SpaceFilterOption _filtroAtual = SpaceFilterOption.todos;

  @override
  void initState() {
    super.initState();
    _carregarEspacos();
  }

  /// Reinicia o carregamento da lista de espaços.
  void _carregarEspacos() {
    setState(() {
      _spacesFuture = widget.spaceService.getSpaces();
    });
  }

  // Função para permitir "Puxar para atualizar"
  /// Recarrega a lista; usado pelo gesto de puxar para atualizar.
  Future<void> _refreshList() async {
    _carregarEspacos();
    await _spacesFuture;
  }

  // Adicione o método _formatCurrency aqui
  /// Formata um valor como moeda brasileira (`R$ 0,00`).
  ///
  /// Normaliza a entrada trocando `.` por vazio e `,` por `.` antes da
  /// conversão. Retorna `R$ 0,00` quando o texto não é numérico.
  String _formatCurrency(String value) {
    final formatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    // Substituir vírgula por ponto para conversão
    String sanitized = value.replaceAll('.', '').replaceAll(',', '.');

    double? parsedValue = double.tryParse(sanitized);
    if (parsedValue == null) return 'R\$ 0,00';

    return formatter.format(parsedValue);
  }

  /// Rejeita em lote todas as reservas de um espaço.
  ///
  /// Usado quando o administrador marca o espaço como indisponível: todas as
  /// reservas com `espaco` igual a [nomeEspaco] passam a `'REJEITADA'` em um
  /// único `WriteBatch`, independentemente do status anterior.
  Future<void> _atualizarReservasAssociadas(String nomeEspaco) async {
    try {
      // Buscar todas as reservas associadas ao espaço com qualquer status
      final reservasSnapshot = await FirebaseFirestore.instance
          .collection('reservas')
          .where('espaco', isEqualTo: nomeEspaco)
          .get();

      if (reservasSnapshot.docs.isNotEmpty) {
        // Usar batch para atualizar todas as reservas de forma atômica
        final batch = FirebaseFirestore.instance.batch();
        for (var reserva in reservasSnapshot.docs) {
          batch.update(reserva.reference, {'status': 'REJEITADA'});
        }
        await batch.commit();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${reservasSnapshot.docs.length} reservas foram atualizadas para "REJEITADA".',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao atualizar reservas: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // --- UI: BOTTOM SHEET DE FILTROS (NOVO) ---
  /// Abre o painel de filtro e ordenação.
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
                  const Text(
                    "Filtrar por Status",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8.0,
                    children: [
                      _buildFilterChip(
                        'Todos',
                        SpaceFilterOption.todos,
                        setModalState,
                      ),
                      _buildFilterChip(
                        'Disponíveis',
                        SpaceFilterOption.disponivel,
                        setModalState,
                        color: Colors.green,
                      ),
                      _buildFilterChip(
                        'Indisponíveis',
                        SpaceFilterOption.indisponivel,
                        setModalState,
                        color: Colors.red,
                      ),
                    ],
                  ),
                  const Divider(height: 30),
                  const Text(
                    "Ordenar por",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  ListTile(
                    leading: const Icon(Icons.sort_by_alpha),
                    title: const Text("Nome do Espaço"),
                    trailing: _criterioOrdenacao == SpaceSortOption.nome
                        ? Icon(
                            _ordemCrescente
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            color: Colors.indigo,
                          )
                        : null,
                    onTap: () => _atualizarOrdenacao(
                      SpaceSortOption.nome,
                      setModalState,
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.people),
                    title: const Text("Capacidade"),
                    trailing: _criterioOrdenacao == SpaceSortOption.capacidade
                        ? Icon(
                            _ordemCrescente
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            color: Colors.indigo,
                          )
                        : null,
                    onTap: () => _atualizarOrdenacao(
                      SpaceSortOption.capacidade,
                      setModalState,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Monta um chip de seleção para o filtro de disponibilidade.
  Widget _buildFilterChip(
    String label,
    SpaceFilterOption valor,
    StateSetter setModalState, {
    Color? color,
  }) {
    final bool selected = _filtroAtual == valor;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor:
          color?.withValues(alpha: 0.3) ?? Colors.indigo.withValues(alpha: 0.3),
      labelStyle: TextStyle(
        color: selected ? (color ?? Colors.indigo) : Colors.black,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
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
  void _atualizarOrdenacao(
    SpaceSortOption novoCriterio,
    StateSetter setModalState,
  ) {
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
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Espaços Condominiais', style: TextStyle(fontSize: 20)),
            if (_filtroAtual != SpaceFilterOption.todos)
              Text(
                _filtroAtual == SpaceFilterOption.disponivel
                    ? 'Filtro: Disponíveis'
                    : 'Filtro: Indisponíveis',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list), // Ícone de ajustes/filtro
            tooltip: 'Filtrar e Ordenar',
            onPressed:
                _mostrarOpcoesFiltro, // Chama a mesma função do BottomSheet
          ),
        ],
      ),

      // --- FAB DUPLO (NOVO) ---
      floatingActionButton: widget.isAdmin
          ? FloatingActionButton.extended(
              // Não precisa mais de heroTag complexa pois é o único FAB
              heroTag: "btnAddSpace",
              onPressed: () => _showCreateDialog(context),
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Novo Espaço'),
              tooltip: 'Criar novo espaço',
            )
          : null, // Se não for admin, não mostra botão nenhum embaixo

      body: RefreshIndicator(
        onRefresh: _refreshList,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _spacesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Erro: ${snapshot.error}'));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 100),
                  Center(child: Text('Nenhum espaço cadastrado')),
                ],
              );
            }

            // 1. Pega a lista original
            var spaces = List<Map<String, dynamic>>.from(snapshot.data!);

            // 2. Aplica Filtro
            if (_filtroAtual != SpaceFilterOption.todos) {
              spaces = spaces.where((space) {
                final isAvail = _isAvailable(space);
                return _filtroAtual == SpaceFilterOption.disponivel
                    ? isAvail
                    : !isAvail;
              }).toList();
            }

            if (spaces.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 100),
                  Center(child: Text('Nenhum espaço com status selecionado.')),
                ],
              );
            }

            // 3. Aplica Ordenação
            spaces.sort((a, b) {
              int comparison = 0;
              switch (_criterioOrdenacao) {
                case SpaceSortOption.nome:
                  String nomeA = a['nome']?.toString().toLowerCase() ?? '';
                  String nomeB = b['nome']?.toString().toLowerCase() ?? '';
                  comparison = nomeA.compareTo(nomeB);
                  break;
                case SpaceSortOption.capacidade:
                  // Tratamento seguro para números que podem vir como String ou Int
                  int capA = int.tryParse(a['qtd_pessoas'].toString()) ?? 0;
                  int capB = int.tryParse(b['qtd_pessoas'].toString()) ?? 0;
                  comparison = capA.compareTo(capB);
                  break;
              }
              return _ordemCrescente ? comparison : -comparison;
            });

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                8,
                16,
                8,
                80,
              ), // Padding extra embaixo p/ FAB
              itemCount: spaces.length,
              itemBuilder: (context, index) {
                final space = spaces[index];
                return _buildSpaceCard(context, space);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildSpaceCard(BuildContext context, Map<String, dynamic> space) {
    final isAvailable = _isAvailable(space);
    final nome = space['nome'] ?? 'Sem nome';
    final capacidade = (space['qtd_pessoas'] ?? 'N/A').toString();
    final horario = space['horario_abertura'] ?? 'N/A';
    final motivoInterdicao = space['motivo_interdicao'] ?? 'Não informado';
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
            onTap: () => _showSpaceDetails(context, space),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isAvailable
                      ? [Colors.blue.shade400, Colors.blue.shade600]
                      : [Colors.grey.shade400, Colors.grey.shade600],
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
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isAvailable
                                          ? Colors.green.shade300
                                          : Colors.red.shade300,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      isAvailable
                                          ? 'Disponível'
                                          : 'Indisponível',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isAvailable
                                            ? Colors.green.shade900
                                            : Colors.red.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (widget.isAdmin)
                          Column(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.white,
                                  ),
                                  tooltip: 'Editar',
                                  onPressed: () =>
                                      _showEditDialog(context, space),
                                ),
                              ),
                              // Removendo o botão de exclusão
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(color: Colors.white.withValues(alpha: 0.3)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildInfoChip(Icons.people, 'Capacidade', capacidade),
                        _buildInfoChip(
                          Icons.access_time,
                          'Abertura',
                          space['horario_abertura'] ?? 'N/A',
                        ),
                        _buildInfoChip(
                          Icons.access_time,
                          'Fechamento',
                          space['horario_fechamento'] ?? 'N/A',
                        ),
                      ],
                    ),
                    if (!isAvailable) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Motivo da Interdição:',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        motivoInterdicao,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Prazo de Interdição Estimado',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${space['prazo_inter'] ?? 'Não informado'} dias',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.8),
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

  void _showSpaceDetails(BuildContext context, Map<String, dynamic> space) {
    final isAvailable = _isAvailable(space);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(space['nome'] ?? 'Detalhes do Espaço'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow(
                  'Status',
                  isAvailable ? 'Disponível' : 'Indisponível',
                ),
                if (!isAvailable)
                  _buildDetailRow(
                    'Motivo da Interdição',
                    space['motivo_interdicao'] ?? 'Não informado',
                  ),
                if (!isAvailable)
                  _buildDetailRow(
                    'Prazo de Interdição',
                    '${space['prazo_inter'] ?? 'Não informado'} dias',
                  ),
                _buildDetailRow(
                  'Capacidade',
                  '${space['qtd_pessoas'] ?? 'N/A'} pessoas',
                ),
                _buildDetailRow(
                  'Horário Abertura',
                  space['horario_abertura'] ?? 'N/A',
                ),
                _buildDetailRow(
                  'Horário Fechamento',
                  space['horario_fechamento'] ?? 'N/A',
                ),
                _buildDetailRow(
                  'Custo Reserva',
                  'R\$${space['custo_reserva'] ?? 'N/A'}',
                ),
                _buildDetailRow('Regras de Uso', space['regras_uso'] ?? 'N/A'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
            if (widget.isAdmin)
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showEditDialog(context, space);
                },
                child: const Text('Editar'),
              ),
          ],
        );
      },
    );
  }

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

  /// Interpreta o campo `status_disponivel` de um espaço.
  ///
  /// Aceita booleano ou texto (`'S'`/`'true'`, sem diferenciar maiúsculas).
  /// Ausência do campo é tratada como indisponível.
  bool _isAvailable(Map<String, dynamic> space) {
    final s = space['status_disponivel'];
    if (s == null) return false;
    if (s is bool) return s;
    if (s is String) return s.toUpperCase() == 'S' || s.toLowerCase() == 'true';
    return false;
  }

  /// Abre o diálogo de criação de espaço.
  ///
  /// Valida nome obrigatório, formato dos horários, fechamento posterior à
  /// abertura, capacidade entre 1 e 50 e custo entre 0 e 500.
  void _showCreateDialog(BuildContext context) {
    final nomeCtl = TextEditingController();
    final capacidadeCtl = TextEditingController();
    final horarioAberuraCtl = TextEditingController();
    final horarioFechamentoCtl = TextEditingController();
    final custoCtl = TextEditingController();
    final custoFocusNode = FocusNode();
    final regrasCtl = TextEditingController();
    bool disponivel = true;

    // Adicionar listener para formatar o valor ao perder o foco
    custoFocusNode.addListener(() {
      if (!custoFocusNode.hasFocus) {
        custoCtl.text = _formatCurrency(custoCtl.text);
      }
    });

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Novo Espaço'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: nomeCtl,
                  decoration: const InputDecoration(
                    labelText: 'Nome*',
                    hintText: 'Ex: Salão de Festas',
                  ),
                ),
                TextField(
                  controller: capacidadeCtl,
                  decoration: const InputDecoration(
                    labelText: 'Capacidade',
                    hintText: 'Ex: 50',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                TextField(
                  controller: horarioAberuraCtl,
                  decoration: const InputDecoration(
                    labelText: 'Horário Abertura',
                    hintText: 'HH:MM',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    HoraInputFormatter(),
                  ],
                ),
                TextField(
                  controller: horarioFechamentoCtl,
                  decoration: const InputDecoration(
                    labelText: 'Horário Fechamento',
                    hintText: 'HH:MM',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    HoraInputFormatter(),
                  ],
                ),
                TextField(
                  controller: custoCtl,
                  decoration: const InputDecoration(
                    labelText: 'Custo Reserva',
                    hintText: 'Ex: 50',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    CustoInputFormatter(), // Aplicar o formatador atualizado
                  ],
                ),
                TextField(
                  controller: regrasCtl,
                  decoration: const InputDecoration(labelText: 'Regras de Uso'),
                  maxLines: 3,
                ),
                StatefulBuilder(
                  builder: (context, setInner) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Row(
                        children: [
                          const Text('Disponível'),
                          const SizedBox(width: 16),
                          Switch(
                            value: disponivel,
                            onChanged: (v) => setInner(() => disponivel = v),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
              child: const Text('Salvar'),
              onPressed: () async {
                // Validações
                if (nomeCtl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nome é obrigatório')),
                  );
                  return;
                }

                if (!_isValidTime(horarioAberuraCtl.text) ||
                    !_isValidTime(horarioFechamentoCtl.text)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Horários inválidos. Use o formato HH:MM.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Validação: horário de fechamento > horário de abertura
                final aberturaParts = horarioAberuraCtl.text.split(':');
                final fechamentoParts = horarioFechamentoCtl.text.split(':');
                final abertura = TimeOfDay(
                  hour: int.parse(aberturaParts[0]),
                  minute: int.parse(aberturaParts[1]),
                );
                final fechamento = TimeOfDay(
                  hour: int.parse(fechamentoParts[0]),
                  minute: int.parse(fechamentoParts[1]),
                );

                if (fechamento.hour < abertura.hour ||
                    (fechamento.hour == abertura.hour &&
                        fechamento.minute <= abertura.minute)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Horário de fechamento deve ser maior que o horário de abertura.',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Validação da capacidade
                final capacidade = int.tryParse(capacidadeCtl.text);
                if (capacidade == null || capacidade < 1 || capacidade > 50) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Capacidade deve ser um número entre 1 e 50.',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final custo = int.tryParse(custoCtl.text);
                if (custo == null || custo < 0 || custo > 500) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Custo deve estar entre 0 e 500.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final payload = {
                  'nome': nomeCtl.text.trim(),
                  'qtd_pessoas': capacidade,
                  'horario_abertura': horarioAberuraCtl.text,
                  'horario_fechamento': horarioFechamentoCtl.text,
                  'custo_reserva': custo,
                  'regras_uso': regrasCtl.text,
                  'status_disponivel': disponivel ? 'S' : 'N',
                };

                Navigator.pop(context);
                try {
                  await widget.spaceService.createSpace(payload);
                  setState(() {
                    _spacesFuture = widget.spaceService.getSpaces();
                  });
                  _carregarEspacos(); // Atualiza a lista
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Espaço criado com sucesso!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Erro: $e')));
                }
              },
            ),
          ],
        );
      },
    );
  }

  /// Abre o diálogo de edição de espaço.
  ///
  /// Além das validações de criação, exige motivo quando o espaço é marcado
  /// como indisponível e exige prazo de interdição numérico. Ao salvar um
  /// espaço indisponível, envia notificação global e rejeita as reservas
  /// associadas.
  void _showEditDialog(BuildContext context, Map<String, dynamic> space) {
    final id = space['id'] as String?;
    final nomeCtl = TextEditingController(text: space['nome'] ?? '');
    final capacidadeCtl = TextEditingController(
      text: space['qtd_pessoas']?.toString() ?? '',
    );
    final horarioAberuraCtl = TextEditingController(
      text: space['horario_abertura'] ?? '',
    );
    final horarioFechamentoCtl = TextEditingController(
      text: space['horario_fechamento'] ?? '',
    );
    final custoCtl = TextEditingController(
      text: space['custo_reserva']?.toString() ?? '',
    );
    final regrasCtl = TextEditingController(text: space['regras_uso'] ?? '');
    final motivoInterdicaoCtl = TextEditingController(
      text: space['motivo_interdicao'] ?? '',
    );
    final prazoInterdicaoCtl = TextEditingController(
      text: space['prazo_inter']?.toString() ?? '',
    );
    bool disponivel = _isAvailable(space);

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Editar Espaço'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: nomeCtl,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                TextField(
                  controller: capacidadeCtl,
                  decoration: const InputDecoration(labelText: 'Capacidade'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                TextField(
                  controller: horarioAberuraCtl,
                  decoration: const InputDecoration(
                    labelText: 'Horário Abertura',
                    hintText: 'HH:MM',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    HoraInputFormatter(),
                  ],
                ),
                TextField(
                  controller: horarioFechamentoCtl,
                  decoration: const InputDecoration(
                    labelText: 'Horário Fechamento',
                    hintText: 'HH:MM',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    HoraInputFormatter(),
                  ],
                ),
                TextField(
                  controller: custoCtl,
                  decoration: const InputDecoration(
                    labelText: 'Custo Reserva',
                    hintText: 'Ex: 50',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    CustoInputFormatter(), // Aplicar o formatador atualizado
                  ],
                ),
                TextField(
                  controller: regrasCtl,
                  decoration: const InputDecoration(labelText: 'Regras de Uso'),
                  maxLines: 3,
                ),
                StatefulBuilder(
                  builder: (context, setInner) {
                    return Column(
                      children: [
                        Row(
                          children: [
                            const Text('Disponível'),
                            const SizedBox(width: 16),
                            Switch(
                              value: disponivel,
                              onChanged: (v) {
                                setInner(() => disponivel = v);
                              },
                            ),
                          ],
                        ),
                        if (!disponivel) ...[
                          TextField(
                            controller: motivoInterdicaoCtl,
                            decoration: const InputDecoration(
                              labelText: 'Motivo da Interdição*',
                              hintText: 'Informe o motivo da interdição',
                            ),
                            maxLines: 3,
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: prazoInterdicaoCtl,
                            decoration: const InputDecoration(
                              labelText: 'Prazo de Interdição Estimado (dias)*',
                              hintText: 'Informe o prazo em dias',
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                if (id == null) return;

                // Validações
                if (nomeCtl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nome é obrigatório')),
                  );
                  return;
                }
                if (!disponivel && motivoInterdicaoCtl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Motivo da interdição é obrigatório.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                if (prazoInterdicaoCtl.text.trim().isEmpty ||
                    int.tryParse(prazoInterdicaoCtl.text.trim()) == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Prazo de interdição é obrigatório e deve ser numérico.',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                if (!_isValidTime(horarioAberuraCtl.text) ||
                    !_isValidTime(horarioFechamentoCtl.text)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Horários inválidos. Use o formato HH:MM.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Validação: horário de fechamento > horário de abertura
                final aberturaParts = horarioAberuraCtl.text.split(':');
                final fechamentoParts = horarioFechamentoCtl.text.split(':');
                final abertura = TimeOfDay(
                  hour: int.parse(aberturaParts[0]),
                  minute: int.parse(aberturaParts[1]),
                );
                final fechamento = TimeOfDay(
                  hour: int.parse(fechamentoParts[0]),
                  minute: int.parse(fechamentoParts[1]),
                );

                if (fechamento.hour < abertura.hour ||
                    (fechamento.hour == abertura.hour &&
                        fechamento.minute <= abertura.minute)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Horário de fechamento deve ser maior que o horário de abertura.',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Validação da capacidade
                final capacidade = int.tryParse(capacidadeCtl.text);
                if (capacidade == null || capacidade < 1 || capacidade > 50) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Capacidade deve ser um número entre 1 e 50.',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Substituir vírgula por ponto para conversão
                final custo = int.tryParse(custoCtl.text);
                if (custo == null || custo < 0 || custo > 500) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Custo deve estar entre 0 e 500.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final payload = {
                  'nome': nomeCtl.text.trim(),
                  'qtd_pessoas': capacidade,
                  'horario_abertura': horarioAberuraCtl.text,
                  'horario_fechamento': horarioFechamentoCtl.text,
                  'custo_reserva': custo,
                  'regras_uso': regrasCtl.text,
                  'status_disponivel': disponivel ? 'S' : 'N',
                  'motivo_interdicao': disponivel
                      ? null
                      : motivoInterdicaoCtl.text.trim(),

                  'prazo_inter': disponivel
                      ? null
                      : int.tryParse(prazoInterdicaoCtl.text.trim()),
                };

                Navigator.pop(context);
                try {
                  await widget.spaceService.updateSpace(id, payload);

                  if (!disponivel) {
                    // Se o admin marcou como indisponível, avisa todo mundo
                    await _notificationService.enviarNotificacaoGlobal(
                      titulo: 'Espaço Interditado',
                      mensagem: 'O espaço "${nomeCtl.text}" encontra-se temporariamente indisponível devido a "${motivoInterdicaoCtl.text}".',
                    );
                    await _atualizarReservasAssociadas(nomeCtl.text.trim());
                    
                  }

                  setState(() {
                    _spacesFuture = widget.spaceService.getSpaces();
                  });
                  _carregarEspacos(); // Atualiza a lista
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Espaço atualizado com sucesso!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Erro: $e')));
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }

  // Reutilizando a função _isValidTime do reservas_user_page.dart
  /// Valida um horário no formato `HH:MM`.
  ///
  /// Lógica duplicada em `reservas_user_page.dart` e
  /// `reservas_admin_page.dart`.
  bool _isValidTime(String? time) {
    if (time == null || time.isEmpty) return false;

    final parts = time.split(':');
    if (parts.length != 2) return false;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) return false;
    if (hour < 0 || hour > 23) return false;
    if (minute < 0 || minute > 59) return false;

    return true;
  }

  /// Confirma e executa a exclusão de um espaço.
  ///
  /// Não é invocado em nenhum ponto da interface: o botão de exclusão foi
  /// removido, embora `SpaceService.deleteSpace` continue disponível.
  void _confirmDelete(BuildContext context, Map<String, dynamic> space) {
    final id = space['id'] as String?;
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Excluir Espaço'),
          content: Text('Deseja excluir permanentemente "${space['nome']}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                if (id == null) return;
                try {
                  await widget.spaceService.deleteSpace(id);
                  setState(() {
                    _spacesFuture = widget.spaceService.getSpaces();
                  });
                  _carregarEspacos(); // Atualiza a lista
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Espaço removido com sucesso!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Erro: $e')));
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'reservas_user_page.dart'; 
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:flutter_application_1/services/notification_service.dart';

// 1. Enum para os tipos de ordenação
/// Critério de ordenação do painel administrativo de reservas.
enum CriterioOrdenacao { data, espaco, morador }

/// Painel administrativo com todas as reservas do condomínio.
///
/// Permite filtrar por status, ordenar por data, espaço ou morador, editar os
/// dados de uma reserva e recusá-la com motivo obrigatório, notificando o
/// morador.
class ReservasAdminPage extends StatefulWidget {
  /// Serviço de autenticação recebido do menu lateral.
  ///
  /// Não é consultado no `build` desta página.
  final AuthService? authService;

  const ReservasAdminPage({Key? key, this.authService}) : super(key: key);

  @override
  State<ReservasAdminPage> createState() => _ReservasAdminPageState();
}

class _ReservasAdminPageState extends State<ReservasAdminPage> {
  final CollectionReference reservasCollection = FirebaseFirestore.instance
      .collection('reservas');

  /// Serviço de notificações usado ao recusar reservas.
  final NotificationService _notificationService = NotificationService();

  // Variável para guardar o futuro (evita recarregamentos desnecessários)
  /// Carregamento corrente das reservas, preservado entre reconstruções.
  Future<List<Map<String, dynamic>>>? _reservasFuture;

  @override
  void initState() {
    super.initState();
    // Inicia a busca assim que a tela abre
    _reservasFuture = _fetchReservasComNomes();
  }

  // Função OTIMIZADA para buscar dados e nomes
  /// Carrega as reservas e enriquece cada uma com o nome do morador.
  ///
  /// As buscas por usuário são disparadas em paralelo e reunidas com
  /// `Future.wait`. Usuário inexistente resulta em `'Desconhecido'`; ausência
  /// de `id_morador` resulta em `'Não informado'`.
  Future<List<Map<String, dynamic>>> _fetchReservasComNomes() async {
    // 1. Busca todas as reservas no banco
    final reservasSnapshot = await reservasCollection.get();

    // 2. Prepara a busca paralela dos nomes dos moradores
    final futures = reservasSnapshot.docs.map((doc) async {
      final reserva = doc.data() as Map<String, dynamic>;
      reserva['id'] = doc.id; // Guarda o ID do documento

      // Se tiver id_morador, busca o nome na coleção users
      if (reserva['id_morador'] != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(reserva['id_morador'])
            .get();

        // Adiciona o campo 'nome_morador' ao mapa da reserva
        reserva['nome_morador'] = (userDoc.exists && userDoc.data() != null)
            ? userDoc.data()!['nome']
            : 'Desconhecido';
      } else {
        reserva['nome_morador'] = 'Não informado';
      }

      return reserva;
    }).toList();

    // 3. Espera todas as buscas terminarem e retorna a lista completa
    return Future.wait(futures);
  }

  // Função para recarregar a lista manualmente (Pull-to-refresh)
  /// Recarrega a lista manualmente.
  ///
  /// Usado pelo gesto de puxar para atualizar e após edições ou recusas.
  Future<void> _atualizarLista() async {
    setState(() {
      _reservasFuture = _fetchReservasComNomes();
    });
    await _reservasFuture;
  }

  // 2. Variáveis de controle de estado da ordenação
  /// Critério de ordenação vigente.
  CriterioOrdenacao _criterioAtual = CriterioOrdenacao.data;
  /// Direção da ordenação; `true` para ascendente.
  bool _ordemCrescente = true;
  /// Status usado como filtro; `'TODOS'` desativa a filtragem.
  String _filtroStatus = 'TODOS';

  // --- FUNÇÕES DE AUXÍLIO VISUAL ---
  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'ACEITA':
        return Colors.green;
      case 'REJEITADA':
        return Colors.red;
      case 'PENDENTE':
        return Colors.orange;
      case 'REALIZADA':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusBackground(String status) {
    switch (status.toUpperCase()) {
      case 'ACEITA':
        return Colors.green.withValues(alpha: 0.15);
      case 'REJEITADA':
        return Colors.red.withValues(alpha: 0.15);
      case 'PENDENTE':
        return Colors.orange.withValues(alpha: 0.15);
      case 'REALIZADA':
        return Colors.blue.withValues(alpha: 0.15);
      default:
        return Colors.grey.withValues(alpha: 0.15);
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'ACEITA':
        return 'Aceita';
      case 'REJEITADA':
        return 'Rejeitada';
      case 'PENDENTE':
        return 'Pendente';
      case 'REALIZADA':
        return 'Realizada';
      default:
        return status;
    }
  }

  // --- RECUSAR RESERVA COM MOTIVO ---
  /// Recusa uma reserva, exigindo motivo.
  ///
  /// Apesar do nome, não exclui o documento: grava `status: 'REJEITADA'` e
  /// `motivo_cancelamento`, e em seguida notifica o morador. O motivo vazio
  /// impede a confirmação.
  Future<void> _excluirReserva(String id) async {
    // 1. Exibe o diálogo pedindo o motivo
    final String? motivoCancelamento = await showDialog<String>(
      context: context,
      builder: (context) {
        final TextEditingController motivoController = TextEditingController();
        return AlertDialog(
          title: const Text('Recusar Reserva'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Tem certeza que deseja recusar esta reserva?'),
              const SizedBox(height: 16),
              TextField(
                controller: motivoController,
                decoration: const InputDecoration(
                  labelText: 'Informe o motivo',
                  hintText: 'Ex: Manutenção, Regras do condomínio...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null), // Retorna null se cancelar
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                // Validação simples: obriga a digitar algo
                if (motivoController.text.trim().isEmpty) {
                   ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Por favor, informe o motivo.')),
                  );
                  return;
                }
                // Retorna o texto digitado
                Navigator.pop(context, motivoController.text.trim());
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Recusar'),
            ),
          ],
        );
      },
    );

    // 2. Se o motivo foi preenchido (não é nulo), prossegue
    if (motivoCancelamento != null) {
      try {
        // A. Atualiza no Firebase com o status e o motivo
        await reservasCollection.doc(id).update({
          'status': 'REJEITADA',
          'motivo_cancelamento': motivoCancelamento,
        });

        // B. Busca dados para a notificação
        final docReserva = await reservasCollection.doc(id).get();
        final dados = docReserva.data() as Map<String, dynamic>;
        final idMorador = dados['id_morador'];
        final nomeEspaco = dados['espaco'] ?? 'Espaço';
        
        // Formatação da data para a mensagem
        Timestamp timestamp = dados['data_reserva'];
        String dataFormatada = DateFormat('dd/MM/yyyy').format(timestamp.toDate());

        // C. Envia a notificação com o motivo digitado
        if (idMorador != null) {
          await _notificationService.enviarNotificacao(
            userId: idMorador,
            titulo: 'Reserva Recusada',
            // Usamos a variável motivoCancelamento diretamente aqui
            mensagem: 'Sua reserva para "$nomeEspaco" em $dataFormatada foi recusada. Motivo: $motivoCancelamento',
            tipo: 'reserva_recusada',
          );
        }

        // D. Atualiza a lista e avisa o admin
        await _atualizarLista();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reserva recusada e morador notificado!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao recusar reserva: $e')),
          );
        }
      }
    }
  }

  // --- EDITAR RESERVA ---
  /// Edita os dados de uma reserva.
  ///
  /// Permite alterar espaço, horários, motivo e observações. Valida o formato
  /// `HH:MM` e exige que o fim seja posterior ao início. A gravação é feita
  /// diretamente no Firestore, sem passar por `ReservasService`, e não
  /// verifica conflitos nem demais regras de domínio.
  Future<void> _editarReserva(
    Map<String, dynamic> reserva,
    String docId,
  ) async {
    await showDialog(
      context: context,
      builder: (context) {
        final _formKey = GlobalKey<FormState>();

        String? espaco = reserva['espaco'];
        String? horaInicio = reserva['hora_inicio'];
        String? horaFim = reserva['hora_fim'];
        String? observacoes = reserva['observacoes'];

        return AlertDialog(
          title: const Text('Editar Reserva'),
          content: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: espaco,
                  decoration: const InputDecoration(labelText: 'Espaço'),
                  onSaved: (value) => espaco = value,
                  validator: (value) => value == null || value.isEmpty
                      ? 'Informe o espaço'
                      : null,
                ),
                TextFormField(
                  initialValue: horaInicio,
                  decoration: const InputDecoration(
                    labelText: 'Hora de Início',
                    hintText: 'HH:MM',
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    HoraInputFormatter(),
                  ],
                  onSaved: (value) => horaInicio = value,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Informe a hora de início';
                    }
                    if (!_isValidTime(value)) {
                      return 'Horário inválido. Use o formato HH:MM.';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  initialValue: horaFim,
                  decoration: const InputDecoration(
                    labelText: 'Hora de Fim',
                    hintText: 'HH:MM',
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    HoraInputFormatter(),
                  ],
                  onSaved: (value) => horaFim = value,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Informe a hora de fim';
                    }
                    if (!_isValidTime(value)) {
                      return 'Horário inválido. Use o formato HH:MM.';
                    }
                    if (horaInicio != null && _isValidTime(horaInicio)) {
                      // Comparar horaInicio e horaFim
                      final inicioParts = horaInicio!.split(':');
                      final fimParts = value.split(':');

                      final inicio = TimeOfDay(
                        hour: int.parse(inicioParts[0]),
                        minute: int.parse(inicioParts[1]),
                      );
                      final fim = TimeOfDay(
                        hour: int.parse(fimParts[0]),
                        minute: int.parse(fimParts[1]),
                      );

                      if (fim.hour < inicio.hour ||
                          (fim.hour == inicio.hour &&
                              fim.minute <= inicio.minute)) {
                        return 'Hora de fim deve ser maior que a hora de início.';
                      }
                    }
                    return null;
                  },
                ),
                TextFormField(
                  initialValue: reserva['motivo_cancelamento'],
                  decoration: const InputDecoration(
                    labelText: 'Motivo do Cancelamento',
                  ),
                  onSaved: (value) => reserva['motivo_cancelamento'] = value,
                ),
                TextFormField(
                  initialValue: observacoes,
                  decoration: const InputDecoration(labelText: 'Observações'),
                  onSaved: (value) => observacoes = value,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: const Text('Salvar'),
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  _formKey.currentState!.save();

                  await reservasCollection.doc(docId).update({
                    'espaco': espaco,
                    'hora_inicio': horaInicio,
                    'hora_fim': horaFim,
                    'observacoes': observacoes,
                    'motivo_cancelamento': reserva['motivo_cancelamento'],
                  });

                  Navigator.pop(context);
                }
              },
            ),
          ],
        );
      },
    );
  }


  String _formatDate(dynamic data) {
    if (data is Timestamp) {
      return data.toDate().toString().split(' ')[0];
    }
    return '';
  }

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

  // 3. PAINEL DE FILTROS E ORDENAÇÃO (BOTTOM SHEET) ---
  /// Abre o painel de filtro por status e ordenação.
  void _mostrarOpcoesFiltro() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        // Usamos StatefulBuilder para que o BottomSheet possa atualizar seu próprio estado visual
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
                    spacing: 4.0,
                    runSpacing: 1.0,
                    children: [
                      _buildChoiceChip('Todos', 'TODOS', setModalState),
                      _buildChoiceChip(
                        'Pendentes',
                        'PENDENTE',
                        setModalState,
                        color: Colors.orange,
                      ),
                      _buildChoiceChip(
                        'Aceitas',
                        'ACEITA',
                        setModalState,
                        color: Colors.green,
                      ),
                      _buildChoiceChip(
                        'Rejeitadas',
                        'REJEITADA',
                        setModalState,
                        color: Colors.red,
                      ),
                      _buildChoiceChip(
                        'Realizadas',
                        'REALIZADA',
                        setModalState,
                        color: Colors.blue,
                      ),
                    ],
                  ),
                  const Divider(height: 30),
                  const Text(
                    "Ordenar por",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: const Text("Data da Reserva"),
                    trailing: _criterioAtual == CriterioOrdenacao.data
                        ? Icon(
                            _ordemCrescente
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            color: Colors.indigo,
                          )
                        : null,
                    onTap: () {
                      _atualizarOrdenacao(
                        CriterioOrdenacao.data,
                        setModalState,
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.meeting_room),
                    title: const Text("Nome do Espaço"),
                    trailing: _criterioAtual == CriterioOrdenacao.espaco
                        ? Icon(
                            _ordemCrescente
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            color: Colors.indigo,
                          )
                        : null,
                    onTap: () {
                      _atualizarOrdenacao(
                        CriterioOrdenacao.espaco,
                        setModalState,
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.person),
                    title: const Text("Morador"),
                    trailing: _criterioAtual == CriterioOrdenacao.morador
                        ? Icon(
                            _ordemCrescente
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            color: Colors.indigo,
                          )
                        : null,
                    onTap: () {
                      _atualizarOrdenacao(
                        CriterioOrdenacao.morador,
                        setModalState,
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 3a. Auxiliar para atualizar a ordenação dentro do Modal e na Tela Principal
  /// Alterna a direção ou troca o critério, sincronizando página e modal.
  void _atualizarOrdenacao(
    CriterioOrdenacao novoCriterio,
    StateSetter setModalState,
  ) {
    setState(() {
      // Atualiza a tela principal
      if (_criterioAtual == novoCriterio) {
        _ordemCrescente = !_ordemCrescente;
      } else {
        _criterioAtual = novoCriterio;
        _ordemCrescente = true;
      }
    });
    setModalState(() {}); // Atualiza o ícone dentro do Modal
  }

  // 3b. Auxiliar para criar os Chips dentro do Modal
  /// Monta um chip de seleção de status.
  Widget _buildChoiceChip(
    String label,
    String valor,
    StateSetter setModalState, {
    Color? color,
  }) {
    final bool selected = _filtroStatus == valor;
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
          setState(() => _filtroStatus = valor); // Atualiza tela principal
          setModalState(() {}); // Atualiza modal
        }
      },
    );
  }

  // --- BUILD ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Reservas', style: TextStyle(fontSize: 20)),
            // Mostra um subtítulo pequeno se houver filtro ativo
            if (_filtroStatus != 'TODOS')
              Text(
                'Filtro: $_filtroStatus',
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

      // --- 4. BOTÕES FLUTUANTES ---
      /* floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        spacing: 4.0,
        children: [          
           FloatingActionButton(
            heroTag: "btnAdd",
            onPressed: _criarReserva, // Chama a função de criar
            backgroundColor: Colors.indigo,
            child: const Icon(Icons.add),
          ), 
        ],
      ),*/
      body: RefreshIndicator(
        onRefresh: _atualizarLista, // Permite puxar pra baixo para atualizar
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _reservasFuture, // Usa a variável criada no passo 1
          builder: (context, snapshot) {
            // 1. Estados de Carregamento e Erro
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Erro: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              // Importante: ListView para permitir o RefreshIndicator funcionar mesmo vazio
              return ListView(
                children: const [
                  SizedBox(height: 100),
                  Center(child: Text('Nenhuma reserva encontrada.')),
                ],
              );
            }

            // 2. Prepara a lista base
            // Note que snapshot.data JÁ É UMA LISTA agora, não precisa converter docs
            var listaReservas = List<Map<String, dynamic>>.from(snapshot.data!);

            // 3. APLICA O FILTRO (Status)
            if (_filtroStatus != 'TODOS') {
              listaReservas = listaReservas.where((reserva) {
                return (reserva['status'].toUpperCase() ?? 'PENDENTE') ==
                    _filtroStatus;
              }).toList();
            }

            if (listaReservas.isEmpty) {
              return ListView(
                // ListView permite o scroll para refresh
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                  Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.filter_list_off,
                          size: 48,
                          color: Colors.grey[300],
                        ),
                        Text(
                          'Sem reservas "$_filtroStatus"',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            // 4. APLICA A ORDENAÇÃO (AGORA FUNCIONA POR NOME!)
            listaReservas.sort((a, b) {
              int comparison = 0;

              switch (_criterioAtual) {
                case CriterioOrdenacao.data:
                  Timestamp tA = a['data_reserva'] ?? Timestamp.now();
                  Timestamp tB = b['data_reserva'] ?? Timestamp.now();
                  comparison = tA.compareTo(tB);
                  break;

                case CriterioOrdenacao.espaco:
                  String sA = a['espaco']?.toString() ?? '';
                  String sB = b['espaco']?.toString() ?? '';
                  comparison = sA.compareTo(sB);
                  break;

                case CriterioOrdenacao.morador:
                  // --- A MÁGICA ACONTECE AQUI ---
                  // Agora temos o campo 'nome_morador' disponível!
                  String mA = a['nome_morador']?.toString().toLowerCase() ?? '';
                  String mB = b['nome_morador']?.toString().toLowerCase() ?? '';
                  comparison = mA.compareTo(mB);
                  break;
              }
              return _ordemCrescente ? comparison : -comparison;
            });

            // 5. Constrói a Lista Visual
            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: listaReservas.length,
              itemBuilder: (context, index) {
                final reserva = listaReservas[index];
                final status = reserva['status'].toUpperCase() ?? 'PENDENTE';
                final docId = reserva['id']; // ID recuperado na função fetch

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                reserva['espaco'] ?? '',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.person,
                                    size: 20,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  // Agora exibimos o NOME, não o ID
                                  Expanded(
                                    child: Text(
                                      reserva['nome_morador'] ??
                                          'Carregando...',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today,
                                    size: 20,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatDate(
                                      reserva['data_reserva'],
                                    ), // Sua função auxiliar
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.access_time,
                                    size: 20,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${reserva['hora_inicio']} - ${reserva['hora_fim']}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  if (reserva['motivo_cancelamento'] != null &&
                                      reserva['motivo_cancelamento']
                                          .toString()
                                          .isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Motivo do Cancelamento: ${reserva['motivo_cancelamento']}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        // ... Coluna de Status e Botões (igual ao anterior) ...
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusBackground(status),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _getStatusLabel(status),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: _getStatusColor(status),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                InkWell(
                                  onTap: () async {
                                    // 1. Chama a função de edição normalmente
                                    // Note que usamos reserva['id'] pois guardamos ele lá na busca
                                    await _editarReserva(
                                      reserva,
                                      reserva['id'],
                                    );

                                    // 2. Força o recarregamento após a edição fechar
                                    _atualizarLista();
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.all(4.0),
                                    child: Icon(
                                      Icons.edit,
                                      size: 20,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () =>
                                      _excluirReserva(reserva['id']).then(
                                        (_) => _atualizarLista(),
                                      ), // Atualiza após excluir
                                  child: const Padding(
                                    padding: EdgeInsets.all(4.0),
                                    child: Icon(
                                      Icons.block,
                                      size: 20,
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

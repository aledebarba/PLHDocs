import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/pages/reservas_user_page.dart';

// Pagina que lista todas as reservas pendentes e aprovadas para usuario
/// Visão agregada das reservas do condomínio.
///
/// Lista as reservas com status `'ACEITA'` ou `'PENDENTE'` de todas as
/// unidades, com filtro e ordenação aplicados em memória, e serve de ponto de
/// partida para solicitar uma nova reserva.
///
/// Critério de ordenação da lista. Declarado também em
/// `minhas_reservas_page.dart`, em duplicidade.
enum ReservaSortOption { data, espaco }

/// Página «Todas Reservas» na visão do morador.
class AllReservasUserPage extends StatefulWidget {
  /// Login do morador; repassado ao formulário de nova reserva.
  final String userId;

  const AllReservasUserPage({Key? key, required this.userId}) : super(key: key);

  @override
  State<AllReservasUserPage> createState() => _AllReservasUserPage();
}

class _AllReservasUserPage extends State<AllReservasUserPage> {
  /// Referência à coleção `reservas`.
  final CollectionReference reservasCollection = FirebaseFirestore.instance
      .collection('reservas');

  // 2. Variáveis de Estado para Filtro e Ordenação
  /// Status usado como filtro; `'TODOS'` desativa a filtragem.
  String _filtroStatus = 'TODOS';
  ReservaSortOption _criterioOrdenacao = ReservaSortOption.data;
  bool _ordemCrescente = false; // Começa decrescente (mais recente primeiro)

  // --- FUNÇÕES AUXILIARES VISUAIS ---
  /// Mapeia o status da reserva para a cor correspondente.
  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'ACEITA':
        return Colors.green;
      case 'PENDENTE':
        return Colors.orange;
      case 'REJEITADA':
        return Colors.red;
      case 'REALIZADA':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  /// Formata um [Timestamp] como `dd/MM/yyyy`.
  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
 

  // --- 3. MENU DE FILTRO E ORDENAÇÃO (BOTTOM SHEET) ---
  /// Abre o painel de filtro por status e ordenação.
  ///
  /// Nesta tela há apenas os chips «Todos», «Pendentes» e «Aceitas», pois a
  /// consulta já exclui os demais status.
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
                    spacing: 2.0,
                    runSpacing: 1.0,
                    children: [
                      _buildFilterChip('Todos', 'TODOS', setModalState),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'Pendentes',
                        'PENDENTE',
                        setModalState,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'Aceitas',
                        'ACEITA',
                        setModalState,
                        color: Colors.green,
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
                    trailing: _criterioOrdenacao == ReservaSortOption.data
                        ? Icon(
                            _ordemCrescente
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            color: Colors.indigo,
                          )
                        : null,
                    onTap: () => _atualizarOrdenacao(
                      ReservaSortOption.data,
                      setModalState,
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.meeting_room),
                    title: const Text("Nome do Espaço"),
                    trailing: _criterioOrdenacao == ReservaSortOption.espaco
                        ? Icon(
                            _ordemCrescente
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            color: Colors.indigo,
                          )
                        : null,
                    onTap: () => _atualizarOrdenacao(
                      ReservaSortOption.espaco,
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

  /// Monta um chip de seleção de status.
  Widget _buildFilterChip(
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
          setState(() => _filtroStatus = valor);
          setModalState(() {});
        }
      },
    );
  }

  /// Alterna a direção ou troca o critério de ordenação.
  void _atualizarOrdenacao(
    ReservaSortOption novoCriterio,
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
            const Text('Todas Reservas'),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filtrar e Ordenar',
            onPressed: _mostrarOpcoesFiltro,
          ),
        ],
      ),

      body: StreamBuilder<QuerySnapshot>(
        // Removemos o orderBy do Firebase para ordenar localmente com flexibilidade
        stream: FirebaseFirestore.instance
          .collection('reservas')
          .where('status', whereIn: ['ACEITA', 'PENDENTE'])
          .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Erro ao carregar dados'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          // 4. PROCESSAMENTO LOCAL DA LISTA
          var listaReservas = List<DocumentSnapshot>.from(snapshot.data!.docs);

          // A. Filtrar
          if (_filtroStatus != 'TODOS') {
            listaReservas = listaReservas.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return (data['status'].toUpperCase() ?? 'PENDENTE') ==
                  _filtroStatus;
            }).toList();
          }

          if (listaReservas.isEmpty) {
            return Center(
              child: Text('Nenhuma reserva encontrada em "$_filtroStatus"'),
            );
          }

          // B. Ordenar
          listaReservas.sort((a, b) {
            final dataA = a.data() as Map<String, dynamic>;
            final dataB = b.data() as Map<String, dynamic>;
            int cmp = 0;

            switch (_criterioOrdenacao) {
              case ReservaSortOption.data:
                Timestamp tA = dataA['data_reserva'] ?? Timestamp.now();
                Timestamp tB = dataB['data_reserva'] ?? Timestamp.now();
                cmp = tA.compareTo(tB);
                break;
              case ReservaSortOption.espaco:
                String sA = dataA['espaco']?.toString() ?? '';
                String sB = dataB['espaco']?.toString() ?? '';
                cmp = sA.compareTo(sB);
                break;
            }
            // Inverte se for decrescente
            return _ordemCrescente ? cmp : -cmp;
          });

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              8,
              8,
              8,
              80,
            ), // Padding extra embaixo para o FAB
            itemCount: listaReservas.length,
            itemBuilder: (context, index) {
              final doc = listaReservas[index];
              final data = doc.data() as Map<String, dynamic>;
              final docId = doc.id;
              final status = data['status'] ?? 'PENDENTE';

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _mostrarDetalhes({...data, 'id': docId}),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Espaço + status
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                data['espaco'] ?? 'Espaço não especificado',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(
                                  status,
                                ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _getStatusColor(status),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  color: _getStatusColor(status),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Data e horário
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatDate(data['data_reserva']),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Icon(
                              Icons.access_time,
                              size: 16,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${data['hora_inicio']} - ${data['hora_fim']}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),

                        // Observações
                        if (data['observacoes'] != null &&
                            data['observacoes'].toString().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Obs: ${data['observacoes']}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black87,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],

                        if (data['motivo_cancelamento'] != null &&
                            data['motivo_cancelamento']
                                .toString()
                                .isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Motivo do Cancelamento: ${data['motivo_cancelamento']}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 12),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () =>
                                  _mostrarDetalhes({...data, 'id': docId}),
                              icon: const Icon(Icons.info_outline, size: 18),
                              label: const Text('Detalhes'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.indigo,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReservarEspacoPage(userId: widget.userId),
            ),
          );
          if (result == true && mounted) setState(() {});
        },
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nova Reserva'),
        tooltip: 'Criar nova reserva.',
      ),
    );
  }

  /// Estado exibido quando não há reservas visíveis.
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.calendar_today_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Nenhuma reserva encontrada.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            'Clique no botão abaixo para criar sua primeira reserva!',
            style: TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // =============================
  // D I A L O G   D E   D E T A L H E S
  // =============================
  /// Exibe os detalhes de uma reserva em um diálogo.
  void _mostrarDetalhes(Map<String, dynamic> reserva) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.info_outline, color: Colors.indigo),
            SizedBox(width: 8),
            Text('Detalhes da Reserva'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetalheItem('Espaço', reserva['espaco'] ?? 'N/A'),
              const Divider(),
              _buildDetalheItem('Data', _formatDate(reserva['data_reserva'])),
              const Divider(),
              _buildDetalheItem(
                'Horário',
                '${reserva['hora_inicio']} - ${reserva['hora_fim']}',
              ),
              const Divider(),
              _buildDetalheItem(
                'Status',
                reserva['status'] ?? 'PENDENTE',
                statusColor: _getStatusColor(reserva['status'] ?? 'PENDENTE'),
              ),
              const Divider(),
              _buildDetalheItem(
                'Número de Convidados',
                '${reserva['qtd_convidados'] ?? 'Não informado'}',
              ),
              if (reserva['observacoes'] != null &&
                  reserva['observacoes'].toString().isNotEmpty) ...[
                const Divider(),
                _buildDetalheItem('Observações', reserva['observacoes']),
              ],
              if (reserva['data_criacao'] != null) ...[
                const Divider(),
                _buildDetalheItem(
                  'Criada em',
                  _formatDate(reserva['data_criacao']),
                ),
              ],
              if (reserva['status'] == 'REJEITADA' &&
                  reserva['motivo_cancelamento'] != null) ...[
                const Divider(),
                _buildDetalheItem(
                  'Motivo do Cancelamento',
                  reserva['motivo_cancelamento'],
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  /// Monta uma linha rótulo/valor do diálogo de detalhes.
  Widget _buildDetalheItem(String label, String value, {Color? statusColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: statusColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

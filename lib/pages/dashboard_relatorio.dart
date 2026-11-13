/// Relatório de utilização dos espaços comuns.
///
/// Permite escolher um período (mês/ano inicial e final) e apresenta o total
/// de reservas, o espaço mais reservado, a distribuição por espaço e o
/// detalhamento das reservas do intervalo.
///
/// Os dados são agregados por `DashboardRelatorioService`; o filtro não
/// considera o status da reserva.
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/dashboard_relatorio_service.dart';

/// Página do relatório de utilização.
class DashboardRelatorioPage extends StatefulWidget {
  const DashboardRelatorioPage({Key? key}) : super(key: key);

  @override
  State<DashboardRelatorioPage> createState() => _DashboardRelatorioPageState();
}

class _DashboardRelatorioPageState extends State<DashboardRelatorioPage> {
  final DashboardRelatorioService _service = DashboardRelatorioService();
  
  // Data
  /// Espaços carregados do Firestore.
  List<Map<String, dynamic>> _allSpaces = [];
  /// Reservas carregadas, já enriquecidas com o nome do morador.
  List<Map<String, dynamic>> _allReservations = [];
  /// Indica carregamento em andamento.
  bool _isLoading = true;

  // Filter State
  int _startMonth = DateTime.now().month;
  int _startYear = DateTime.now().year;
  int _endMonth = DateTime.now().month;
  int _endYear = DateTime.now().year;
  
  // Calculated Data
  /// Métricas calculadas para o período selecionado.
  Map<String, dynamic> _metrics = {};

  final List<String> _months = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
  ];

  /// Lista os anos disponíveis para seleção, de 2020 até o ano corrente.
  List<int> _getYears() {
    final currentYear = DateTime.now().year;
    final years = <int>[];
    for (int i = 2020; i <= currentYear; i++) {
      years.add(i);
    }
    return years;
  }

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  /// Carrega espaços e reservas e calcula as métricas iniciais.
  Future<void> _initializeData() async {
    setState(() => _isLoading = true);
    try {
      final spaces = await _service.fetchAllSpaces();
      final reservations = await _service.fetchAllReservations();
      
      if (mounted) {
        setState(() {
          _allSpaces = spaces;
          _allReservations = reservations;
          _updateMetrics();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Erro ao inicializar dados: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Recalcula as métricas para o período selecionado.
  ///
  /// O fim do período é obtido com a expressão `mês + 1, dia 0`, que resolve
  /// para o último dia do mês de encerramento.
  void _updateMetrics() {
    // Create start date (1st day of start month)
    final startDate = DateTime(_startYear, _startMonth, 1);
    
    // Create end date (last day of end month)
    // To get last day, go to next month day 0
    final endDate = DateTime(_endYear, _endMonth + 1, 0, 23, 59, 59);

    final metrics = _service.calculateGeneralMetrics(
      _allReservations,
      _allSpaces,
      startDate,
      endDate,
    );

    setState(() {
      _metrics = metrics;
    });
  }

  /// Mapeia o status da reserva para a cor correspondente.
  ///
  /// Reconhece tanto `'APROVADO'`/`'ACEITA'` quanto `'CANCELADO'`/`'NEGADA'`,
  /// acomodando vocabulários distintos.
  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'APROVADO':
      case 'ACEITA':
        return Colors.green;
      case 'CANCELADO':
      case 'NEGADA':
        return Colors.red;
      case 'PENDENTE':
        return Colors.orange;
      case 'REALIZADA':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  /// Formata um [Timestamp] como `dd/MM/yyyy`; `'Data inválida'` em erro.
  String _formatDate(dynamic data) {
    try {
      if (data is Timestamp) {
        final dateTime = data.toDate();
        return DateFormat('dd/MM/yyyy').format(dateTime);
      }
    } catch (e) {
      print('Erro ao formatar data: $e');
    }
    return 'Data inválida';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        title: const Text(
          'Relatório de Utilização',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFilterSection(),
                  const SizedBox(height: 24),
                  _buildSummarySection(),
                  const SizedBox(height: 24),
                  _buildDetailedListSection(),
                ],
              ),
            ),
    );
  }

  /// Monta a seção de seleção do período de análise.
  Widget _buildFilterSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Período de Análise',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
            const SizedBox(height: 16),
            
            // Start Date Row
            const Text('De:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildDropdown<int>(
                    value: _startMonth,
                    items: List.generate(12, (i) => i + 1),
                    label: (val) => _months[val - 1],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _startMonth = val;
                          _updateMetrics();
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: _buildDropdown<int>(
                    value: _startYear,
                    items: _getYears(),
                    label: (val) => val.toString(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _startYear = val;
                          _updateMetrics();
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // End Date Row
            const Text('Até:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildDropdown<int>(
                    value: _endMonth,
                    items: List.generate(12, (i) => i + 1),
                    label: (val) => _months[val - 1],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _endMonth = val;
                          _updateMetrics();
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: _buildDropdown<int>(
                    value: _endYear,
                    items: _getYears(),
                    label: (val) => val.toString(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _endYear = val;
                          _updateMetrics();
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Monta um seletor genérico com borda arredondada.
  Widget _buildDropdown<T>({
    required T value,
    required List<T> items,
    required String Function(T) label,
    required Function(T?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(label(item)),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  /// Monta a seção de resumo: cartões de destaque e distribuição por espaço.
  Widget _buildSummarySection() {
    final total = _metrics['totalReservations'] as int? ?? 0;
    final mostReserved = _metrics['mostReservedSpace'] as String? ?? '-';
    final perSpace = _metrics['reservationsPerSpace'] as Map<String, int>? ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Resumo Geral',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.indigo,
          ),
        ),
        const SizedBox(height: 12),
        
        // Key Metrics Cards
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Total Reservas',
                total.toString(),
                Icons.assessment,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                'Mais Popular',
                mostReserved,
                Icons.star,
                Colors.orange,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Per Space Breakdown
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Reservas por Espaço',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 12),
                if (perSpace.isEmpty)
                  const Text('Nenhum dado disponível')
                else
                  ...perSpace.entries.map((entry) {
                    final percentage = total > 0 ? entry.value / total : 0.0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(entry.key),
                              Text(
                                '${entry.value} (${(percentage * 100).toStringAsFixed(1)}%)',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: percentage,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Monta um cartão de métrica com ícone e valor em destaque.
  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Monta a listagem detalhada das reservas do período.
  ///
  /// Ordena por data decrescente; datas ausentes são tratadas como 2000.
  Widget _buildDetailedListSection() {
    final reservations = _metrics['filteredReservations'] as List<Map<String, dynamic>>? ?? [];
    
    // Sort by date descending
    reservations.sort((a, b) {
      final dateA = (a['data_reserva'] as Timestamp?)?.toDate() ?? DateTime(2000);
      final dateB = (b['data_reserva'] as Timestamp?)?.toDate() ?? DateTime(2000);
      return dateB.compareTo(dateA);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Detalhamento',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.indigo,
          ),
        ),
        const SizedBox(height: 12),
        if (reservations.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('Nenhuma reserva encontrada no período selecionado'),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: reservations.length,
            itemBuilder: (context, index) {
              final reservation = reservations[index];
              final spaceName = reservation['espaco'] ?? 'Espaço Desconhecido';
              final residentName = reservation['morador'] ?? 'Residente Desconhecido';
              final status = (reservation['status'] ?? 'PENDENTE').toString();
              final dataReserva = reservation['data_reserva'];
              final horaInicio = reservation['hora_inicio'] ?? '00:00';
              final horaFim = reservation['hora_fim'] ?? '00:00';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: CircleAvatar(
                    backgroundColor: _getStatusColor(status).withValues(alpha: 0.1),
                    child: Icon(
                      Icons.event_note,
                      color: _getStatusColor(status),
                      size: 20,
                    ),
                  ),
                  title: Text(
                    spaceName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('Morador: $residentName'),
                      Text(
                        '${_formatDate(dataReserva)} • $horaInicio - $horaFim',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _getStatusColor(status).withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(status),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
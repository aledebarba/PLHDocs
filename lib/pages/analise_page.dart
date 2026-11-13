/// Fila de aprovação de reservas.
///
/// Lista as reservas com status `'PENDENTE'` e permite ao administrador
/// aceitá-las ou recusá-las. A recusa exige motivo e, em ambos os casos, o
/// morador é notificado.
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; 
import 'package:flutter_application_1/services/notification_service.dart'; 

/// Página «Análise de Reservas».
class AnalisePage extends StatefulWidget {
  const AnalisePage({Key? key}) : super(key: key);

  @override
  State<AnalisePage> createState() => _AnalisePageState();
}

class _AnalisePageState extends State<AnalisePage> {
  // 1. Instancia o serviço de notificação
  /// Serviço usado para avisar o morador sobre a decisão.
  final NotificationService _notificationService = NotificationService();

  /// Carrega as reservas pendentes com o nome do morador.
  ///
  /// As consultas a `users` ocorrem em laço sequencial. Usuário não
  /// localizado resulta em `'Desconhecido'`.
  Future<List<Map<String, dynamic>>> _fetchReservasPendentes() async {
    final reservasSnapshot = await FirebaseFirestore.instance
        .collection('reservas')
        .where('status', isEqualTo: 'PENDENTE')
        .get();

    List<Map<String, dynamic>> reservas = [];
    
    // DICA DE PERFORMANCE: Future.wait para carregar nomes mais rápido
    // Mas mantendo a lógica original para não complicar
    for (var doc in reservasSnapshot.docs) {
      final reserva = doc.data();
      reserva['id'] = doc.id;

      // Buscar nome do morador
      if (reserva['id_morador'] != null) {
        final userSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(reserva['id_morador'])
            .get();
            
        reserva['nome_morador'] = userSnapshot.exists && userSnapshot.data() != null
            ? userSnapshot.data()!['nome']
            : 'Desconhecido';
      } else {
        reserva['nome_morador'] = 'Desconhecido';
      }

      reservas.add(reserva);
    }
    return reservas;
  }

  // 2. Função auxiliar para formatar data (para usar na mensagem da notificação)
  /// Formata um [Timestamp] como `dd/MM/yyyy`; vazio para outros tipos.
  String _formatData(dynamic data) {
    if (data is Timestamp) {
      return DateFormat('dd/MM/yyyy').format(data.toDate());
    }
    return '';
  }

  // 3. Alterado para receber o MAP inteiro da reserva, não só o ID
  /// Aprova ou recusa uma reserva e notifica o morador.
  ///
  /// Recebe o mapa completo (e não apenas o identificador) para poder montar
  /// a mensagem da notificação. Quando [novoStatus] é `'REJEITADA'`, exige um
  /// motivo e grava também `motivo_cancelamento`.
  Future<void> _atualizarStatus(Map<String, dynamic> reserva, String novoStatus) async {
    final String id = reserva['id'];
    final String idMorador = reserva['id_morador'];
    final String nomeEspaco = reserva['espaco'] ?? 'Espaço';
    final String dataFormatada = _formatData(reserva['data_reserva']);

    try {
      if (novoStatus == 'REJEITADA') {
        final motivoCancelamento = await _mostrarDialogoMotivoCancelamento();
        
        if (motivoCancelamento == null || motivoCancelamento.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Por favor, informe o motivo.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        // Atualiza no Banco
        await FirebaseFirestore.instance.collection('reservas').doc(id).update({
          'status': novoStatus,
          'motivo_cancelamento': motivoCancelamento.trim(),
        });

        // --- ENVIA NOTIFICAÇÃO DE RECUSA ---
        await _notificationService.enviarNotificacao(
          userId: idMorador,
          titulo: 'Reserva Recusada',
          mensagem: 'Sua reserva para "$nomeEspaco" no dia $dataFormatada foi recusada. Motivo: ${motivoCancelamento.trim()}',
          tipo: 'reserva_recusada',
        );

      } else {
        // Atualiza no Banco (ACEITA)
        await FirebaseFirestore.instance.collection('reservas').doc(id).update({
          'status': novoStatus,
        });

        // --- ENVIA NOTIFICAÇÃO DE APROVAÇÃO ---
        await _notificationService.enviarNotificacao(
          userId: idMorador,
          titulo: 'Reserva Aprovada!',
          mensagem: 'Sua reserva para "$nomeEspaco" no dia $dataFormatada foi confirmada com sucesso.',
          tipo: 'reserva_aceita',
        );
      }

      // Feedback visual para o Admin
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(novoStatus == 'ACEITA' ? 'Reserva aprovada e e morador notificado!' : 'Reserva recusada e morador notificado!'),
            backgroundColor: novoStatus == 'ACEITA' ? Colors.green : Colors.orange,
          ),
        );
        setState(() {}); // Recarrega a lista
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Solicita o motivo da recusa ao administrador.
  ///
  /// Retorna o texto informado ou `null` se o diálogo for cancelado.
  Future<String?> _mostrarDialogoMotivoCancelamento() async {
    String? motivo;
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Motivo da recusa'),
          content: TextField(
            onChanged: (value) => motivo = value,
            decoration: const InputDecoration(
              labelText: 'Informe o motivo',
              hintText: 'Ex: Manutenção, Regras do condomínio...',
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, motivo),
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );
  }

  /// Exibe os detalhes de uma reserva em um diálogo somente leitura.
  void _mostrarDetalhes(BuildContext context, Map<String, dynamic> reserva) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Detalhes da Reserva'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Espaço', reserva['espaco'] ?? ''),
                _buildDetailRow('Responsável', reserva['nome_morador'] ?? ''),
                _buildDetailRow('Data', _formatData(reserva['data_reserva'])),
                _buildDetailRow(
                  'Horário',
                  '${reserva['hora_inicio']} - ${reserva['hora_fim']}',
                ),
                _buildDetailRow(
                  'Quantidade de Pessoas',
                  '${reserva['qtd_convidados'] ?? 0}',
                ),
                _buildDetailRow('Status', reserva['status'] ?? ''),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }

  /// Monta uma linha rótulo/valor do diálogo de detalhes.
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Análise de Reservas'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchReservasPendentes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Nenhuma reserva pendente.'));
          }

          final reservas = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reservas.length,
            itemBuilder: (context, index) {
              final reserva = reservas[index];
              return _buildReservaCard(context, reserva);
            },
          );
        },
      ),
    );
  }

  /// Monta o cartão de uma reserva pendente, com ações de aceitar e recusar.
  Widget _buildReservaCard(BuildContext context, Map<String, dynamic> reserva) {
    final dataReserva = _formatData(reserva['data_reserva']);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _mostrarDetalhes(context, reserva),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                reserva['espaco'] ?? 'Espaço Desconhecido',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.person, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '  ${reserva['nome_morador']}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '  $dataReserva',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '  ${reserva['hora_inicio']} - ${reserva['hora_fim']}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    // 4. ATUALIZAÇÃO AQUI: Passando a 'reserva' inteira, não só o ID
                    onPressed: () => _atualizarStatus(reserva, 'ACEITA'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Aceitar'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    // 4. ATUALIZAÇÃO AQUI: Passando a 'reserva' inteira
                    onPressed: () => _atualizarStatus(reserva, 'REJEITADA'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Recusar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
/// Caixa de entrada de notificações do usuário.
///
/// Alimentada por um `StreamBuilder` filtrado por `destinatario_id`.
/// Notificações não lidas são destacadas e marcadas ao serem tocadas.
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/services/notification_service.dart';
import 'package:intl/intl.dart';

/// Página de notificações.
class NotificationsPage extends StatelessWidget {
  /// Login do usuário cujas notificações serão exibidas.
  final String userId;
  /// Serviço usado para marcar notificações como lidas.
  final NotificationService _service = NotificationService();

  NotificationsPage({Key? key, required this.userId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificações'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Marcar todas como lidas',
            onPressed: () => _service.marcarTodasComoLidas(userId),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notificacoes')
            .where('destinatario_id', isEqualTo: userId)
            //.orderBy('data_criacao', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text("Você não tem notificações."));
          }

          var listaNotificacoes = docs;

          listaNotificacoes.sort((a, b) {
            // Pega os dados com segurança
            final dataA = a.data() as Map<String, dynamic>;
            final dataB = b.data() as Map<String, dynamic>;

            // Pega o Timestamp (protegendo contra null)
            final Timestamp tA =
                dataA['data_criacao'] ?? Timestamp.fromDate(DateTime(2000));
            final Timestamp tB =
                dataB['data_criacao'] ?? Timestamp.fromDate(DateTime(2000));

            // Compara B com A para ficar Decrescente (mais novo primeiro)
            return tB.compareTo(tA);
          });

          return ListView.builder(
            itemCount: listaNotificacoes.length,
            itemBuilder: (context, index) {
              final data =
                  listaNotificacoes[index].data() as Map<String, dynamic>;
              final bool lida = data['lida'] ?? false;
              final docId = listaNotificacoes[index].id;

              return Dismissible(
                key: Key(docId),
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (direction) {
                  FirebaseFirestore.instance
                      .collection('notificacoes')
                      .doc(docId)
                      .delete();
                },
                child: Container(
                  color: lida
                      ? null
                      : Colors.indigo.withValues(
                          alpha: 0.05,
                        ), // Destaque para não lidas
                  child: ListTile(
                    leading: Icon(
                      _getIconForType(data['tipo']),
                      color: lida ? Colors.grey : Colors.indigo,
                    ),
                    title: Text(
                      data['titulo'] ?? 'Aviso',
                      style: TextStyle(
                        fontWeight: lida ? FontWeight.normal : FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data['mensagem'] ?? ''),
                        const SizedBox(height: 4),
                        Text(
                          _formatTime(data['data_criacao']),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      // Ao clicar, marca como lida
                      if (!lida) _service.marcarComoLida(docId);
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Escolhe o ícone conforme o tipo da notificação.
  IconData _getIconForType(String? tipo) {
    switch (tipo) {
      case 'reserva_aceita':
        return Icons.check_circle;
      case 'reserva_recusada':
        return Icons.cancel;
      case 'geral':
        return Icons.info;
      default:
        return Icons.notifications;
    }
  }

  /// Formata o horário da notificação como `dd/MM HH:mm`.
  ///
  /// Retorna string vazia quando o timestamp é nulo.
  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    return DateFormat('dd/MM HH:mm').format(timestamp.toDate());
  }
}

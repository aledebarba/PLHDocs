/// Envio e marcação de notificações na coleção `notificacoes`.
///
/// As notificações são registros internos do aplicativo — não há push nativo.
/// Cada documento é endereçado a um `destinatario_id` e classificado por
/// `tipo` (`'aviso'`, `'reserva_aceita'`, `'reserva_recusada'`, `'geral'`).
import 'package:cloud_firestore/cloud_firestore.dart';

/// Serviço de notificações.
class NotificationService {
  /// Referência à coleção `notificacoes`.
  final CollectionReference _notifCollection =
      FirebaseFirestore.instance.collection('notificacoes');

  // 1. Enviar para um usuário específico (ex: Reserva aceita)
  /// Envia uma notificação a um usuário específico.
  ///
  /// Grava `lida: false` e `data_criacao` com o horário do servidor.
  /// [tipo] assume `'aviso'` por padrão.
  Future<void> enviarNotificacao({
    required String userId,
    required String titulo,
    required String mensagem,
    String tipo = 'aviso', // 'aviso', 'reserva_aceita', 'reserva_recusada'
  }) async {
    await _notifCollection.add({
      'destinatario_id': userId,
      'titulo': titulo,
      'mensagem': mensagem,
      'lida': false,
      'data_criacao': FieldValue.serverTimestamp(),
      'tipo': tipo,
    });
  }

  // 2. Enviar para TODOS os usuários (ex: Espaço interditado)
  /// Envia a mesma notificação a todos os usuários cadastrados.
  ///
  /// Percorre a coleção `users` e grava uma notificação por documento em um
  /// único `WriteBatch`, com `tipo: 'geral'`. A abordagem é adequada ao
  /// volume de um condomínio; em escala maior, o envio seria delegado a
  /// Cloud Functions.
  // Nota: Em apps gigantes isso seria feito via Cloud Functions, 
  // mas para um condomínio (poucos usuários), um loop simples funciona bem.
  Future<void> enviarNotificacaoGlobal({
    required String titulo,
    required String mensagem,
  }) async {
    // Busca todos os usuários
    final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
    
    final batch = FirebaseFirestore.instance.batch();

    for (var doc in usersSnapshot.docs) {
      // Cria uma notificação para cada morador
      final docRef = _notifCollection.doc(); // Gera ID novo
      batch.set(docRef, {
        'destinatario_id': doc.id, // ID do documento do usuário
        'titulo': titulo,
        'mensagem': mensagem,
        'lida': false,
        'data_criacao': FieldValue.serverTimestamp(),
        'tipo': 'geral',
      });
    }
    
    await batch.commit();
  }

  // 3. Marcar como lida
  /// Marca uma notificação como lida.
  Future<void> marcarComoLida(String notifId) async {
    await _notifCollection.doc(notifId).update({'lida': true});
  }
  
  // 4. Marcar todas como lidas
  /// Marca como lidas todas as notificações não lidas de um usuário.
  ///
  /// Aplica as alterações em um único `WriteBatch`.
  Future<void> marcarTodasComoLidas(String userId) async {
    final snap = await _notifCollection
        .where('destinatario_id', isEqualTo: userId)
        .where('lida', isEqualTo: false)
        .get();
        
    final batch = FirebaseFirestore.instance.batch();
    for (var doc in snap.docs) {
      batch.update(doc.reference, {'lida': true});
    }
    await batch.commit();
  }
}
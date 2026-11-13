/// Operações de reserva sobre a coleção `reservas`.
///
/// Reúne criação, aprovação/recusa, cancelamento e reagendamento. Apenas o
/// cancelamento é consumido pela interface: `MinhasReservasPage` delega a
/// `cancelarReserva`. Os demais métodos não têm chamador nas telas roteadas.
///
/// Atenção ao vocabulário de status: este serviço produz `'APROVADA'` e
/// `'RECUSADA'`, enquanto o restante da aplicação usa `'ACEITA'` e
/// `'REJEITADA'`. Os dois conjuntos não são interoperáveis.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Serviço de reservas.
class ReservasService {
  /// Referência tipada à coleção `reservas`.
  final CollectionReference<Map<String, dynamic>> reservasCollection =
      FirebaseFirestore.instance.collection('reservas');

  /// Cria uma reserva com status inicial `'PENDENTE'`.
  ///
  /// Exige `id_unidade` não vazio e recusa quando já existir reserva para o
  /// mesmo espaço na mesma data.
  ///
  /// O documento é gravado com o **nome do espaço como identificador**, o
  /// que difere da interface (que usa identificadores automáticos) e implica
  /// que só pode existir uma reserva por espaço ao longo de todo o histórico.
  Future<void> criarReserva(Map<String, dynamic> reservaData) async {
    try {
      final unidade = reservaData['id_unidade']?.toString().trim();
      if (unidade == null || unidade.isEmpty) {
        throw Exception('Toda reserva deve estar associada a uma unidade.');
      }

      final String nomeEspaco = reservaData['espaco'];
      final DateTime dataReserva = reservaData['data_reserva'];

      // Verificar se já existe uma reserva para o mesmo espaço e data
      final QuerySnapshot reservasExistentes = await reservasCollection
          .where('espaco', isEqualTo: nomeEspaco)
          .where('data_reserva', isEqualTo: dataReserva)
          .get();

      if (reservasExistentes.docs.isNotEmpty) {
        throw Exception('O dia já foi reservado para este espaço.');
      }

      // Criar a nova reserva
      final novaReserva = {
        'data_criacao': FieldValue.serverTimestamp(),
        'status': 'PENDENTE',
        ...reservaData,
        'id_unidade': unidade,
      };

      // Usar o nome do espaço como o ID do documento
      await reservasCollection.doc(nomeEspaco).set(novaReserva);
    } catch (e) {
      throw Exception('Erro ao criar reserva: $e');
    }
  }

  /// Aprova ou recusa uma reserva.
  ///
  /// Aceita apenas `'APROVADA'` ou `'RECUSADA'`. Esses valores divergem do
  /// vocabulário usado pelas telas (`'ACEITA'`/`'REJEITADA'`), portanto uma
  /// reserva alterada por aqui não é reconhecida pelos filtros da interface.
  Future<void> aprovarOuRecusarReserva(String idReserva, String status) async {
    try {
      if (status != 'APROVADA' && status != 'RECUSADA') {
        throw Exception('Status inválido. Use APROVADA ou RECUSADA.');
      }
      await reservasCollection.doc(idReserva).update({'status': status});
    } catch (e) {
      throw Exception('Erro ao atualizar status da reserva: $e');
    }
  }

  /// Cancela uma reserva do próprio morador, dentro de uma transação.
  ///
  /// Verifica, nesta ordem: existência da reserva, propriedade
  /// (`id_morador` deve ser igual a [userId]), validade de data e horário e,
  /// **somente quando o status é `'ACEITA'`**, o prazo mínimo de 24 horas de
  /// antecedência.
  ///
  /// Em sucesso grava `status: 'CANCELADA'` e `data_cancelamento` com o
  /// horário do servidor. Retorna `null` em sucesso ou a mensagem de erro
  /// correspondente.
  Future<String?> cancelarReserva(String idReserva, String userId) async {
    const mensagemPrazo =
        'Cancelamento não pode ser realizado para reservas devido ao prazo ser inferior a 24 horas do evento';
    final mensagemErro = await FirebaseFirestore.instance
        .runTransaction<String?>((transaction) async {
          final reservaRef = reservasCollection.doc(idReserva);
          final reservaSnapshot = await transaction.get(reservaRef);
          final reserva = reservaSnapshot.data();

          if (reserva == null) {
            return 'Reserva não encontrada.';
          }
          if (reserva['id_morador'] != userId) {
            return 'Você só pode cancelar suas próprias reservas.';
          }

          if ((reserva['status'] ?? '').toString().toUpperCase() == 'ACEITA') {
            final dataReserva = reserva['data_reserva'];
            final horaInicio = reserva['hora_inicio']?.toString().split(':');
            if (dataReserva is! Timestamp ||
                horaInicio == null ||
                horaInicio.length != 2) {
              return 'Data ou horário da reserva inválido.';
            }

            final hora = int.tryParse(horaInicio[0]);
            final minuto = int.tryParse(horaInicio[1]);
            if (hora == null ||
                minuto == null ||
                hora < 0 ||
                hora > 23 ||
                minuto < 0 ||
                minuto > 59) {
              return 'Data ou horário da reserva inválido.';
            }

            final data = dataReserva.toDate();
            final inicioReserva = DateTime(
              data.year,
              data.month,
              data.day,
              hora,
              minuto,
            );
            if (inicioReserva.difference(DateTime.now()) <
                const Duration(hours: 24)) {
              return mensagemPrazo;
            }
          }

          transaction.update(reservaRef, {
            'status': 'CANCELADA',
            'data_cancelamento': FieldValue.serverTimestamp(),
          });
          return null;
        });

    if (mensagemErro == mensagemPrazo) {
      debugPrint(mensagemPrazo);
    }
    return mensagemErro;
  }

  /// Altera data e horários de uma reserva existente.
  ///
  /// Recusa quando já houver outra reserva do mesmo espaço na nova data,
  /// desconsiderando o próprio documento na verificação. Não valida horário
  /// de funcionamento nem demais regras de domínio.
  Future<void> reagendarReserva(
    String idReserva,
    DateTime novaData,
    String horaInicio,
    String horaFim,
  ) async {
    try {
      // Obter o documento da reserva atual
      final reservaAtual = await reservasCollection.doc(idReserva).get();
      if (!reservaAtual.exists) {
        throw Exception('Reserva não encontrada.');
      }

      final String nomeEspaco = reservaAtual['espaco'];

      // Verificar se já existe uma reserva para o mesmo espaço e data
      final QuerySnapshot reservasExistentes = await reservasCollection
          .where('espaco', isEqualTo: nomeEspaco)
          .where('data_reserva', isEqualTo: novaData)
          .get();

      // Excluir a reserva atual da verificação
      final reservasConflitantes = reservasExistentes.docs.where(
        (doc) => doc.id != idReserva,
      );

      if (reservasConflitantes.isNotEmpty) {
        throw Exception('O dia já foi reservado para este espaço.');
      }

      // Atualizar a reserva com a nova data e horários
      await reservasCollection.doc(idReserva).update({
        'data_reserva': novaData,
        'hora_inicio': horaInicio,
        'hora_fim': horaFim,
      });
    } catch (e) {
      throw Exception('Erro ao reagendar reserva: $e');
    }
  }
}

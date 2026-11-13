/// Agregação de dados para o relatório de utilização dos espaços.
///
/// Carrega espaços e reservas e calcula métricas por período. Não persiste
/// nada: apenas lê o Firestore e devolve estruturas em memória.
///
/// Para enriquecer cada reserva com o nome do morador, dispara uma leitura
/// adicional em `users` por reserva (padrão N+1), reunindo os resultados com
/// `Future.wait`.
import 'package:cloud_firestore/cloud_firestore.dart';

/// Serviço de dados do relatório de utilização.
class DashboardRelatorioService {
  /// Instância do Cloud Firestore.
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Carrega todos os espaços cadastrados.
  ///
  /// Injeta a chave `id` em cada item. Em caso de erro, registra a falha e
  /// retorna uma lista vazia, em vez de propagar a exceção.
  Future<List<Map<String, dynamic>>> fetchAllSpaces() async {
    try {
      final querySnapshot = await _firestore.collection('espacos').get();
      return querySnapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Erro ao buscar espaços: $e');
      return [];
    }
  }

  // ...existing code...
  /// Carrega todas as reservas, enriquecidas com o nome do morador.
  ///
  /// Para cada reserva com `id_morador`, busca o documento correspondente em
  /// `users` e grava os campos `morador` e `nome_morador`. Quando o usuário
  /// não existe, usa `'Usuário não encontrado'`; quando a consulta falha, usa
  /// `'Erro na busca'`; sem `id_morador`, usa `'Não informado'`.
  ///
  /// Em caso de erro geral, registra a falha e retorna uma lista vazia.
  Future<List<Map<String, dynamic>>> fetchAllReservations() async {
    try {
      final querySnapshot = await _firestore.collection('reservas').get();
      
      // Mapeia cada documento para um Future que busca os dados do usuário
      final futures = querySnapshot.docs.map((doc) async {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;

        // --- LÓGICA DE BUSCA DE USUÁRIO (Copiada e adaptada do Admin) ---
        if (data['id_morador'] != null) {
          try {
            final userDoc = await _firestore
                .collection('users')
                .doc(data['id_morador'])
                .get();

            if (userDoc.exists && userDoc.data() != null) {
              // A página de relatório espera o campo 'morador' com o nome
              final nomeUsuario = userDoc.data()!['nome'];
              data['morador'] = nomeUsuario;
              data['nome_morador'] = nomeUsuario; // Mantendo compatibilidade
            } else {
              data['morador'] = 'Usuário não encontrado';
            }
          } catch (e) {
            print('Erro ao buscar usuário ${data['id_morador']}: $e');
            data['morador'] = 'Erro na busca';
          }
        } else {
          // Se não tiver id_morador, verifica se já tem o nome salvo na reserva
          if (data['morador'] == null) {
            data['morador'] = 'Não informado';
          }
        }
        // ----------------------------------------------------------------

        return data;
      }).toList();

      // Aguarda todas as buscas paralelas terminarem
      return await Future.wait(futures);
    } catch (e) {
      print('Erro ao buscar reservas: $e');
      return [];
    }
  }
// ...existing code...

  /// Calcula métricas gerais de utilização para um período.
  ///
  /// [reservations] são as reservas já carregadas; [spaces], os espaços
  /// cadastrados; [startDate] e [endDate] delimitam o período (comparação
  /// inclusiva nas bordas, aplicada a `data_reserva`).
  ///
  /// Retorna um mapa com `filteredReservations`, `reservationsPerSpace`
  /// (contagem por nome de espaço, inicializada em zero para todos os
  /// espaços), `mostReservedSpace` (`'-'` quando não há reservas) e
  /// `totalReservations`.
  ///
  /// O filtro não considera o campo `status`.
  Map<String, dynamic> calculateGeneralMetrics(
      List<Map<String, dynamic>> reservations,
      List<Map<String, dynamic>> spaces,
      DateTime startDate,
      DateTime endDate) {
    
    // Filter reservations by date range
    final filteredReservations = reservations.where((reservation) {
      final dataReserva = reservation['data_reserva'];
      if (dataReserva is Timestamp) {
        final date = dataReserva.toDate();
        // Inclusive comparison
        return !date.isBefore(startDate) && !date.isAfter(endDate);
      }
      return false;
    }).toList();

    // Calculate totals per space
    final Map<String, int> reservationsPerSpace = {};
    for (var space in spaces) {
      final spaceName = space['nome']?.toString() ?? 'Desconhecido';
      reservationsPerSpace[spaceName] = 0;
    }

    // Count reservations
    for (var reservation in filteredReservations) {
      final spaceName = reservation['espaco']?.toString() ?? 'Desconhecido';
      if (reservationsPerSpace.containsKey(spaceName)) {
        reservationsPerSpace[spaceName] = (reservationsPerSpace[spaceName] ?? 0) + 1;
      } else {
        reservationsPerSpace[spaceName] = 1;
      }
    }

    // Find most reserved space
    String mostReservedSpace = '-';
    int maxReservations = -1;
    
    reservationsPerSpace.forEach((space, count) {
      if (count > maxReservations) {
        maxReservations = count;
        mostReservedSpace = space;
      }
    });

    if (maxReservations == 0) mostReservedSpace = '-';

    return {
      'filteredReservations': filteredReservations,
      'reservationsPerSpace': reservationsPerSpace,
      'mostReservedSpace': mostReservedSpace,
      'totalReservations': filteredReservations.length,
    };
  }
}
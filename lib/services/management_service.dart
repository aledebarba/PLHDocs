/// Serviço de listagem simples de reservas.
///
/// Fornece uma leitura "flat" de toda a coleção `reservas`, sem enriquecer os
/// documentos com dados do morador e sem qualquer filtro. É consumido apenas
/// por `ManagementPage`, tela que não é alcançável a partir de `main.dart`
/// (código órfão).
///
/// Há sobreposição funcional com [ReservasService] e com
/// [DashboardRelatorioService], que cobrem os mesmos dados com mais recursos.
import 'package:cloud_firestore/cloud_firestore.dart';

/// Serviço de acesso à coleção `reservas` para listagem administrativa.
class ManagementService {
  /// Referência à coleção `reservas` no Cloud Firestore.
  final CollectionReference reservasCollection = FirebaseFirestore.instance
      .collection('reservas');

  /// Retorna todas as reservas cadastradas.
  ///
  /// Cada item do resultado é o mapa do documento acrescido da chave `id`,
  /// que ecoa o identificador do documento no Firestore.
  ///
  /// Lança uma [Exception] com a mensagem `'Erro ao buscar reservas: ...'`
  /// caso a leitura falhe.
  Future<List<Map<String, dynamic>>> getReservas() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('reservas')
          .get();
      return querySnapshot.docs.map((doc) {
        return {'id': doc.id, ...doc.data()};
      }).toList();
    } catch (e) {
      throw Exception('Erro ao buscar reservas: $e');
    }
  }
}

/// CRUD dos espaços comuns do condomínio (coleção `espacos`).
///
/// O identificador de cada documento é derivado do nome do espaço, após
/// sanitização. Isso torna a renomeação uma operação de criar-e-apagar, e
/// implica que o nome funciona como chave natural do cadastro.
import 'package:cloud_firestore/cloud_firestore.dart';

/// Serviço de acesso à coleção `espacos`.
class SpaceService {
  /// Instância do Cloud Firestore.
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  /// Referência à coleção `espacos`.
  final CollectionReference _col = FirebaseFirestore.instance.collection('espacos');

  /// Normaliza o nome do espaço para uso como identificador de documento.
  ///
  /// Apara espaços em branco e substitui sequências de `\` ou `/` por `-`,
  /// já que esses caracteres não são permitidos em IDs do Firestore.
    String _sanitizeId(String s) {
    return s.trim().replaceAll(RegExp(r'[\\/]+'), '-');
  }
  /// Retorna a lista de espaços cadastrados.
  ///
  /// Cada item recebe a chave `id` com o identificador do documento — campo
  /// que existe apenas em memória, não sendo persistido.
  Future<List<Map<String, dynamic>>> getSpaces() async {
    try {
      final querySnapshot = await _col.get();
      return querySnapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Cria um novo documento e retorna o id gerado.
  ///
  /// Exige `nome` não vazio e recusa nomes cujo identificador sanitizado já
  /// exista. O campo `nome` é sempre regravado com o valor aparado.
  Future<String> createSpace(Map<String, dynamic> space) async {
    try {
      final rawName = (space['nome'] ?? '').toString().trim();
      if (rawName.isEmpty) throw Exception('Nome é obrigatório');
      final docId = _sanitizeId(rawName);

      final docRef = _col.doc(docId);
      final existing = await docRef.get();
      if (existing.exists) {
        throw Exception('Já existe um espaço com o nome "$rawName".');
      }

      // Garantir que o campo 'nome' esteja definido no documento
      final payload = Map<String, dynamic>.from(space);
      payload['nome'] = rawName;

      await docRef.set(payload);
      return docId;
    } catch (e) {
      throw Exception('Falha ao criar espaço: $e');
    }
  }

  /// Atualiza os campos do documento identificado por [id].
  ///
  /// Se o nome informado em `data['nome']` gerar um identificador diferente
  /// de [id], a operação vira um rename: cria o documento de destino e apaga
  /// o antigo. O documento de destino não pode existir previamente.
  ///
  /// Observação: as reservas guardam o **nome** do espaço em
  /// `reservas.espaco`; renomear aqui não atualiza as reservas existentes.
  /// Se o campo 'nome' for alterado para um valor diferente, realiza rename
  /// criando um novo documento com o novo ID (nome sanitized) e removendo o antigo.
  Future<void> updateSpace(String id, Map<String, dynamic> data) async {
    try {
      final newNameRaw = (data['nome'] ?? '').toString().trim();
      final newDocId = newNameRaw.isNotEmpty ? _sanitizeId(newNameRaw) : null;

      if (newDocId != null && newDocId != id) {
        // renomear: verificar existência do destino
        final newDocRef = _col.doc(newDocId);
        final newDoc = await newDocRef.get();
        if (newDoc.exists) {
          throw Exception('Já existe um espaço com o nome "$newNameRaw".');
        }

        // Preparar payload garantindo 'nome' correto
        final payload = Map<String, dynamic>.from(data);
        payload['nome'] = newNameRaw;

        // Criar novo documento e remover o antigo
        await newDocRef.set(payload);
        await _col.doc(id).delete();
        return;
      }

      // Atualização simples no mesmo documento
      await _col.doc(id).update(data);
    } catch (e) {
      throw Exception('Falha ao atualizar espaço: $e');
    }
  }

  /// Remove o documento do Firestore (hard delete)
  Future<void> deleteSpace(String id) async {
    try {
      await _col.doc(id).delete();
    } catch (e) {
      throw Exception('Falha ao remover espaço: $e');
    }
  }
}
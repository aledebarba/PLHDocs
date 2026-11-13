/// CRUD de usuários com estratégia de cache local.
///
/// Tenta carregar a lista do Cloud Firestore (coleção `users`) e recorre ao
/// `SharedPreferences` quando a leitura falha ou não retorna documentos. O
/// cache é gravado sob a chave `users_list`, com `Timestamp` e `DateTime`
/// convertidos para ISO-8601 a fim de permitir a codificação JSON.
///
/// Como estende [ChangeNotifier], telas podem observar mudanças na lista por
/// `addListener`.
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/models/user.dart';

/// Serviço de gerência de usuários.
///
/// Mantém a lista de usuários em memória, sincronizada com o Firestore e com
/// um cache local.
class UserService extends ChangeNotifier {
  /// Chave usada para persistir a lista em `SharedPreferences`.
  static const _kUsersKey = 'users_list';

  /// Lista de usuários em memória.
  List<User> _users = [];

  /// Visão não modificável da lista de usuários.
  List<User> get users => List.unmodifiable(_users);

  /// Cria o serviço e dispara o carregamento inicial.
  ///
  /// O carregamento assíncrono não é aguardado no construtor; consumidores
  /// devem observar este [ChangeNotifier] para reagir ao resultado.
  UserService() {
    _load();
  }

  /// Carrega a lista de usuários em cascata: Firestore, cache local e, por
  /// último, um usuário administrador de exemplo.
  ///
  /// O usuário `admin` criado como semente existe apenas no cache local: não
  /// é gravado no Firestore e, portanto, não é autenticável por
  /// `AuthService.login`.
  Future<void> _load() async {
    // Primeiro tenta carregar a lista do Firestore (coleção 'users').
    // Se houver falha ou nenhum documento, cai de volta para o cache local em SharedPreferences.
    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').get();
      if (snapshot.docs.isNotEmpty) {
        _users = snapshot.docs.map((doc) {
          final data = doc.data();
          return User.fromMap(doc.id, data);
        }).toList();
        // atualiza cache local
        await _save();
        notifyListeners();
        return;
      }
    } catch (e) {
      // se falhar (ex: sem conexão ou sem configuração), iremos para o cache local
    }

    // fallback: ler do SharedPreferences (cache local)
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kUsersKey);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        _users = list.map((e) {
          final m = e as Map<String, dynamic>;
          final extra = Map<String, dynamic>.from(m);
          extra.remove('username');
          extra.remove('role');
          extra.remove('ind_habilitado');
          return User(username: m['username'] as String, role: m['role'] as String, ind_habilitado: m['ind_habilitado'] as String? ?? 'S', extra: extra);
        }).toList();
      } catch (_) {
        _users = [];
      }
    } else {
      // Inicializa com um usuário admin de exemplo se não existir
      _users = [User(username: 'admin', role: 'admin', ind_habilitado: 'S')];
      await _save();
    }
    notifyListeners();
  }

  /// Persiste a lista em `SharedPreferences` como JSON.
  ///
  /// Converte `Timestamp` e `DateTime` para ISO-8601, pois JSON não representa
  /// esses tipos nativamente.
  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _users.map((u) {
      final m = <String, dynamic>{'username': u.username, 'role': u.role, 'ind_habilitado': u.ind_habilitado};
      if (u.extra != null) {
        for (final e in u.extra!.entries) {
          final v = e.value;
          // Converter Timestamp para string ISO para permitir serialização em JSON
          if (v is Timestamp) {
            m[e.key] = v.toDate().toIso8601String();
          } else if (v is DateTime) {
            m[e.key] = v.toIso8601String();
          } else {
            m[e.key] = v;
          }
        }
      }
      return m;
    }).toList(growable: false);
    await prefs.setString(_kUsersKey, jsonEncode(list));
  }

  /// Retorna a lista de usuários, carregando-a se estiver vazia.
  Future<List<User>> getUsers() async {
    if (_users.isEmpty) await _load();
    return users;
  }

  // Método público para forçar recarga dos usuários do Firestore
  /// Força a recarga dos usuários a partir do Firestore.
  Future<void> loadUsers() async {
    await _load();
  }

  /// Caminho bloqueado de criação de usuário.
  ///
  /// Rejeita duplicatas por `username` e sempre lança [Exception], pois a
  /// criação exige senha e deve passar por [addUserWithPassword].
  Future<void> addUser(User user) async {
    // evite duplicados
    if (_users.any((u) => u.username == user.username)) {
      throw Exception('Usuário já existe');
    }
    // For security, require a password when adding a user that should be persisted to Firestore.
    throw Exception('Use addUserWithPassword to create a user with password in Firestore');
  }

  // Novo método: adicionar usuário com campos padrão obrigatórios
  // Campos: cpf, email, id_apartamento, login, nome, role, senha, telefone
  /// Cria um usuário com os campos padrão obrigatórios.
  ///
  /// Valida senha não vazia, unicidade de `username`, nome e CPF presentes,
  /// CPF e apartamento numéricos e unicidade de `id_apartamento`.
  ///
  /// Grava o documento em `users/{username}` com `ind_habilitado: 'S'` e
  /// `data_cadastro` preenchido, e então atualiza o cache e notifica.
  Future<void> addUserWithPassword(
    String username,
    String password,
    String nome,
    String cpf,
    String email,
    String telefone,
    String idApartamento,
    String role,
  ) async {
    if (password.trim().isEmpty) throw Exception('Senha é obrigatória');
    if (_users.any((u) => u.username == username)) throw Exception('Usuário já existe');
    if (nome.trim().isEmpty) throw Exception('Nome é obrigatório');
    if (cpf.trim().isEmpty) throw Exception('CPF é obrigatório');
    if (int.tryParse(cpf.trim()) == null) throw Exception('CPF deve ser numérico');
    if (int.tryParse(idApartamento.trim()) == null) throw Exception('ID Apartamento deve ser numérico');

    // Verificar unicidade de id_apartamento
    if (_users.any((u) => u.extra?['id_apartamento']?.toString() == idApartamento.trim())) {
      throw Exception('Apartamento já cadastrado');
    }

    // Preparar documento a ser escrito com campos padrão
    final docMap = <String, dynamic>{
      'login': username,
      'nome': nome,
      'cpf': cpf.trim(),
      'email': email.trim(),
      'telefone': telefone.trim(),
      'id_apartamento': idApartamento.trim(),
      'role': role,
      'senha': password,
      'ind_habilitado': 'S',
      'data_cadastro': Timestamp.fromDate(DateTime.now()),
    };

    try {
      await FirebaseFirestore.instance.collection('users').doc(username).set(docMap);
    } catch (e) {
      throw Exception('Falha ao criar usuário no Firestore: $e');
    }

    // Atualizar cache local
    final extra = <String, dynamic>{
      'nome': nome,
      'cpf': cpf.trim(),
      'email': email.trim(),
      'telefone': telefone.trim(),
      'id_apartamento': idApartamento.trim(),
    };
    final newUser = User(username: username, role: role, ind_habilitado: 'S', extra: extra);
    _users.add(newUser);
    await _save();
    notifyListeners();
  }

  /// Atualiza um usuário existente.
  ///
  /// Se o `username` mudar, a operação equivale a renomear: a senha e o
  /// `data_cadastro` do documento antigo são preservados, o documento antigo
  /// é apagado e um novo é criado. Sem mudança de `username`, apenas `role`,
  /// `ind_habilitado` e os campos de `extra` são atualizados.
  ///
  /// A renomeação não é atômica: uma falha entre a exclusão e a criação deixa
  /// o usuário inexistente.
  Future<void> updateUser(String oldUsername, User updated) async {
    final idx = _users.indexWhere((u) => u.username == oldUsername);
    if (idx == -1) throw Exception('Usuário não encontrado');
    // se mudou para um username já existente e diferente do atual
    if (oldUsername != updated.username && _users.any((u) => u.username == updated.username)) {
      throw Exception('Já existe outro usuário com esse nome');
    }

    // If username changed, we need to delete the old document and create a new one
    if (oldUsername != updated.username) {
      try {
        // Get old document to retrieve password before deleting
        final oldDoc = await FirebaseFirestore.instance.collection('users').doc(oldUsername).get();
        final oldData = oldDoc.exists ? (oldDoc.data() ?? {}) : {};
        final password = (oldData['senha'] as String?) ?? '';

        // Delete old document from Firestore
        await FirebaseFirestore.instance.collection('users').doc(oldUsername).delete();

        // Create new document with updated data (retaining the password from the old doc)
        final newMap = updated.toMap(senha: password);
        // preserve data_cadastro from old doc if present
        if (oldData.containsKey('data_cadastro')) {
          newMap['data_cadastro'] = oldData['data_cadastro'];
        } else {
          newMap['data_cadastro'] = Timestamp.fromDate(DateTime.now());
        }
        await FirebaseFirestore.instance.collection('users').doc(updated.username).set(newMap);
      } catch (e) {
        throw Exception('Falha ao atualizar usuário no Firestore: $e');
      }
    } else {
      // Username didn't change, just update the fields
      try {
        final updateMap = <String, dynamic>{'role': updated.role, 'ind_habilitado': updated.ind_habilitado};
        if (updated.extra != null) {
          // se id_apartamento foi alterado, garantir unicidade
          if (updated.extra!.containsKey('id_apartamento')) {
            final newApt = updated.extra!['id_apartamento'].toString();
            final others = _users.where((u) => u.username != oldUsername && u.extra?['id_apartamento']?.toString() == newApt).toList();
            if (others.isNotEmpty) throw Exception('id_apartamento já cadastrado');
          }
          for (final e in updated.extra!.entries) {
            updateMap[e.key] = e.value;
          }
        }
        await FirebaseFirestore.instance.collection('users').doc(updated.username).update(updateMap);
      } catch (e) {
        throw Exception('Falha ao atualizar usuário no Firestore: $e');
      }
    }

    // If Firestore update succeeded, update local cache
    _users[idx] = updated;
    await _save();
    notifyListeners();
  }

  /// Remove definitivamente um usuário do Firestore e do cache.
  ///
  /// As reservas históricas do usuário permanecem em `reservas`, com
  /// `id_morador` apontando para um documento que não existe mais; as telas
  /// que buscam o nome exibirão um valor de fallback.
  Future<void> deleteUser(String username) async {
    final idx = _users.indexWhere((u) => u.username == username);
    if (idx == -1) throw Exception('Usuário não encontrado');

    // Delete from Firestore
    try {
      await FirebaseFirestore.instance.collection('users').doc(username).delete();
    } catch (e) {
      throw Exception('Falha ao excluir usuário do Firestore: $e');
    }

    // If Firestore deletion succeeded, update local cache
    _users.removeAt(idx);
    await _save();
    notifyListeners();
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/management_service.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:intl/intl.dart'; // Importar o pacote intl
import 'package:cloud_firestore/cloud_firestore.dart'; // Importar para usar Timestamp


//========================================
// !! VERIFICAR SE ESSA PAGINA É USADA  !!
//========================================


/// Listagem de reservas por perfil (não utilizada).
///
/// Código órfão: não é alcançável a partir de `main.dart`. Filtraria as
/// reservas por `id_morador` para moradores e exibiria todas para o
/// administrador. Funcionalmente sobreposta por `ReservasAdminPage` e
/// `MinhasReservasPage`.
class ManagementPage extends StatefulWidget {
  /// Serviço que fornece a lista de reservas.
  final ManagementService managementService;
  /// Serviço de autenticação usado para descobrir o papel do usuário.
  final AuthService authService;

  const ManagementPage({Key? key, required this.managementService, required this.authService})
    : super(key: key);

  @override
  _ManagementPageState createState() => _ManagementPageState();
}

class _ManagementPageState extends State<ManagementPage> {
  /// Reservas exibidas após o filtro por perfil.
  List<Map<String, dynamic>> reservas = [];
  /// Indica carregamento em andamento.
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarReservas();
  }

// Alterado para mostrar reservas baseadas no usuario 16/11/25
/// Carrega as reservas e as filtra conforme o papel do usuário.
///
/// Administradores veem todas; demais perfis veem apenas aquelas cujo
/// `id_morador` coincide com o login corrente.
Future<void> _carregarReservas() async {
  try {
    final reservasData = await widget.managementService.getReservas();
    
    
    final usuarioAtual = widget.authService.currentUser?.username;
    final roleUsuario = widget.authService.currentUser?.role;
    
    
    final reservasFiltradas = (roleUsuario?.toLowerCase() == 'admin') 
        ? reservasData  // Admin vê todas
        : reservasData.where(
            (reserva) => reserva['id_morador'] == usuarioAtual
          ).toList();  // Usuários veem só as suas
    
    print('Total de reservas: ${reservasFiltradas.length}');
    
    setState(() {
      reservas = reservasFiltradas;
      isLoading = false;
    });
  } catch (e) {
    setState(() {
      isLoading = false;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Erro ao carregar reservas: $e')));
  }
}






  String _formatarData(Timestamp timestamp) {
    try {
      // Converte o Timestamp para DateTime
      final DateTime dateTime = timestamp.toDate();
      // Formata a data no formato DD/MM/YYYY
      return DateFormat('dd/MM/yyyy').format(dateTime);
    } catch (e) {
      return 'Data inválida'; // Retorna uma mensagem padrão em caso de erro
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar Reservas'),
        backgroundColor: const Color.fromARGB(255, 153, 157, 175),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : reservas.isEmpty
          ? const Center(child: Text('Nenhuma reserva encontrada.'))
          : ListView.builder(
              itemCount: reservas.length,
              itemBuilder: (context, index) {
                final reserva = reservas[index];
                return Card(
                  child: ListTile(
                    title: Text('Espaço: ${reserva['espaco']}'),
                    subtitle: Text(
                      'Data: ${_formatarData(reserva['data_reserva'])}\n'
                      'Hora: ${reserva['hora_inicio']} - ${reserva['hora_fim']}',
                    ),
                  ),
                );
              },
            ),
    );
  }
}

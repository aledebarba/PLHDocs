/// Vitrine de espaços em layout mestre-detalhe (não utilizada).
///
/// Código órfão: não é alcançável a partir de `main.dart` e o próprio arquivo
/// traz a marca `!! VERIFICAR SE ESSA PAGINA É USADA !!`. Trabalha com campos
/// (`emoji`, `cor`, `status`, `descricao`, `detalhes`) que não existem no
/// esquema real da coleção `espacos`. Substituída por `SpacesPage`.
import 'package:flutter/material.dart';

//========================================
// !! VERIFICAR SE ESSA PAGINA É USADA  !!
//========================================

/// Página de exibição de espaços (não utilizada).
class EspacosPage extends StatefulWidget {
  /// Lista de espaços recebida do chamador.
  final List<Map<String, dynamic>> espacos;

  const EspacosPage({Key? key, required this.espacos}) : super(key: key);

  @override
  State<EspacosPage> createState() => _EspacosPageState();
}

class _EspacosPageState extends State<EspacosPage> {
  late List<Map<String, dynamic>> _espacos;
  String _espacoEscolhido = 'Nenhum espaço selecionado';
  String _statusAtual = '📍';
  Color _corAtual = Colors.indigo;
  String _descricaoAtual = 'Selecione um espaço na lista ao lado para visualizar detalhes.';

  @override
  void initState() {
    super.initState();
    _espacos = List<Map<String, dynamic>>.from(
      widget.espacos.map((e) => Map<String, dynamic>.from(e)),
    );
  }

  /// Mapeia o status textual para a cor correspondente.
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'disponível':
        return Colors.green;
      case 'ocupado':
        return Colors.red;
      case 'manutenção':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  /// Mapeia o status textual para o ícone correspondente.
  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'disponível':
        return Icons.check_circle;
      case 'ocupado':
        return Icons.cancel;
      case 'manutenção':
        return Icons.build_circle;
      default:
        return Icons.help_outline;
    }
  }

  /// Atualiza o painel de detalhes com o espaço escolhido.
  void _selecionarEspaco(Map<String, dynamic> espaco) {
    setState(() {
      _espacoEscolhido = espaco['nome'];
      _statusAtual = espaco['emoji'];
      _corAtual = espaco['cor'];
      _descricaoAtual = espaco['descricao'];
    });
  }

  /// Exibe o diálogo de detalhes de um espaço.
  void _mostrarDetalhesEspaco(Map<String, dynamic> espaco) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Text(espaco['emoji']),
              const SizedBox(width: 8),
              Expanded(child: Text(espaco['nome'])),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _getStatusIcon(espaco['status']),
                    color: _getStatusColor(espaco['status']),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Status: ${espaco['status']}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(espaco['status']),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                espaco['descricao'],
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              const Text(
                'Detalhes:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...espaco['detalhes'].entries.map<Widget>((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• ${entry.key.toString().toUpperCase()}: '),
                      Expanded(child: Text(entry.value.toString())),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Fechar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            if (espaco['status'] == 'Disponível')
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: espaco['cor'],
                  foregroundColor: Colors.white,
                ),
                child: const Text('Reservar'),
                onPressed: () {
                  Navigator.of(context).pop();
                  _selecionarEspaco(espaco);
                },
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _espacos);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: _corAtual,
          foregroundColor: Colors.white,
          title: const Text('Espaços Comuns'),
          centerTitle: true,
        ),
        body: Row(
          children: [
            // Painel lateral com lista de espaços
            Container(
              width: 300,
              color: Colors.grey[100],
              child: ListView.builder(
                itemCount: _espacos.length,
                itemBuilder: (context, index) {
                  final espaco = _espacos[index];

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: _espacoEscolhido == espaco['nome']
                          ? Border.all(color: espaco['cor'], width: 2)
                          : null,
                    ),
                    child: ListTile(
                      dense: true,
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: espaco['cor'].withValues(alpha:0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Text(
                            espaco['emoji'],
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                      title: Text(
                        espaco['nome'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: espaco['cor'],
                        ),
                      ),
                      subtitle: Row(
                        children: [
                          Icon(
                            _getStatusIcon(espaco['status']),
                            size: 12,
                            color: _getStatusColor(espaco['status']),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            espaco['status'],
                            style: TextStyle(
                              color: _getStatusColor(espaco['status']),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.info_outline, size: 18),
                        onPressed: () => _mostrarDetalhesEspaco(espaco),
                        color: espaco['cor'],
                      ),
                      onTap: () => _selecionarEspaco(espaco),
                      tileColor: _espacoEscolhido == espaco['nome']
                          ? espaco['cor'].withValues(alpha:0.1)
                          : null,
                    ),
                  );
                },
              ),
            ),
            // Painel principal com detalhes do espaço
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Card principal do espaço
                    Card(
                      elevation: 8,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            colors: [_corAtual.withValues(alpha:0.1), _corAtual.withValues(alpha:0.05)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Column(
                          children: [
                            // Ícone do espaço
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: _corAtual.withValues(alpha:0.2),
                                borderRadius: BorderRadius.circular(50),
                                border: Border.all(color: _corAtual, width: 3),
                              ),
                              child: Center(
                                child: Text(
                                  _statusAtual,
                                  style: const TextStyle(fontSize: 50),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Nome do espaço
                            Text(
                              _espacoEscolhido,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: _corAtual,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            // Descrição
                            Text(
                              _descricaoAtual,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[700],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Instruções de uso
                    if (_espacoEscolhido == 'Nenhum espaço selecionado')
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info_outline, color: Colors.blue),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Como usar:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Text('1. Selecione um espaço na lista à esquerda'),
                              const Text('2. Toque no ícone (ⓘ) para ver detalhes completos'),
                              const Text('3. Use o botão "Reservar" quando disponível'),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

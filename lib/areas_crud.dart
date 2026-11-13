/// CRUD de áreas mantido apenas em memória (não utilizado).
///
/// Código órfão: não é alcançável a partir de `main.dart` e não persiste nada
/// — as alterações existem somente na lista local e são devolvidas ao
/// chamador por `Navigator.pop`. Está na raiz de `lib/`, fora da convenção de
/// organização do projeto.
import 'package:flutter/material.dart';

/// Página de gestão de áreas em memória (não utilizada).
class AreasCrudPage extends StatefulWidget {
  /// Lista inicial de áreas recebida do chamador.
  final List<Map<String, dynamic>> espacos;
  const AreasCrudPage({Key? key, required this.espacos}) : super(key: key);

  @override
  State<AreasCrudPage> createState() => _AreasCrudPageState();
}

class _AreasCrudPageState extends State<AreasCrudPage> {
  /// Cópia local editável da lista de áreas.
  late List<Map<String, dynamic>> _list;

  /// Cores disponíveis para identificação visual de uma área.
  final Map<String, Color> _colorOptions = {
    'Indigo': Colors.indigo,
    'Blue': Colors.blue,
    'Green': Colors.green,
    'Orange': Colors.orange,
    'Red': Colors.red,
    'Purple': Colors.purple,
    'Teal': Colors.teal,
    'Brown': Colors.brown,
    'Grey': Colors.grey,
  };

  @override
  void initState() {
    super.initState();
    _list = widget.espacos.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// Abre o diálogo de criação (quando [index] é nulo) ou edição de área.
  void _showEditDialog({int? index}) {
    final isNew = index == null;
    Map<String, dynamic> current = isNew
        ? {
            'nome': '',
            'emoji': '🏢',
            'cor': Colors.indigo,
            'status': 'Disponível',
            'descricao': '',
            'icone': Icons.apartment,
            'detalhes': {
              'capacidade': '',
              'equipamentos': '',
              'horario': '',
              'regras': '',
            },
          }
        : Map<String, dynamic>.from(_list[index]);

    final nomeCtrl = TextEditingController(text: current['nome']);
    final emojiCtrl = TextEditingController(text: current['emoji']);
    final descricaoCtrl = TextEditingController(text: current['descricao']);
    final capacidadeCtrl = TextEditingController(
      text: current['detalhes']['capacidade'],
    );
    final equipamentosCtrl = TextEditingController(
      text: current['detalhes']['equipamentos'],
    );
    final horarioCtrl = TextEditingController(
      text: current['detalhes']['horario'],
    );
    final regrasCtrl = TextEditingController(
      text: current['detalhes']['regras'],
    );
    String status = current['status'] ?? 'Disponível';
    String selectedColorName = _colorOptions.entries
        .firstWhere(
          (e) => e.value == (current['cor'] as Color?),
          orElse: () => _colorOptions.entries.first,
        )
        .key;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isNew ? 'Nova Área' : 'Editar Área'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nomeCtrl,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                TextFormField(
                  controller: emojiCtrl,
                  decoration: const InputDecoration(labelText: 'Emoji'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  items: ['Disponível', 'Ocupado', 'Manutenção']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => status = v ?? status,
                  decoration: const InputDecoration(labelText: 'Status'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: selectedColorName,
                  items: _colorOptions.keys
                      .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                      .toList(),
                  onChanged: (v) => selectedColorName = v ?? selectedColorName,
                  decoration: const InputDecoration(labelText: 'Cor'),
                ),
                TextFormField(
                  controller: descricaoCtrl,
                  decoration: const InputDecoration(labelText: 'Descrição'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: capacidadeCtrl,
                  decoration: const InputDecoration(labelText: 'Capacidade'),
                ),
                TextFormField(
                  controller: equipamentosCtrl,
                  decoration: const InputDecoration(labelText: 'Equipamentos'),
                ),
                TextFormField(
                  controller: horarioCtrl,
                  decoration: const InputDecoration(labelText: 'Horário'),
                ),
                TextFormField(
                  controller: regrasCtrl,
                  decoration: const InputDecoration(labelText: 'Regras'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final Map<String, dynamic> updated = {
                  'nome': nomeCtrl.text.trim(),
                  'emoji': emojiCtrl.text.trim().isEmpty
                      ? '🏢'
                      : emojiCtrl.text.trim(),
                  'cor': _colorOptions[selectedColorName] ?? Colors.indigo,
                  'status': status,
                  'descricao': descricaoCtrl.text.trim(),
                  'icone': Icons.apartment,
                  'detalhes': {
                    'capacidade': capacidadeCtrl.text.trim(),
                    'equipamentos': equipamentosCtrl.text.trim(),
                    'horario': horarioCtrl.text.trim(),
                    'regras': regrasCtrl.text.trim(),
                  },
                };

                setState(() {
                  if (isNew) {
                    _list.add(updated);
                  } else {
                    _list[index] = updated;
                  }
                });
                Navigator.pop(context);
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }

  /// Confirma e remove uma área da lista local.
  void _deleteItem(int index) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Confirmar exclusão'),
            content: Text('Deseja excluir "${_list[index]['nome']}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Excluir'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmed) {
      setState(() => _list.removeAt(index));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar Áreas'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _list),
            child: const Text('Salvar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _list.isEmpty
          ? const Center(child: Text('Nenhuma área cadastrada'))
          : ListView.builder(
              itemCount: _list.length,
              itemBuilder: (context, index) {
                final item = _list[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        (item['cor'] as Color?)?.withValues(alpha: 0.2) ??
                        Colors.grey.withValues(alpha: 0.2),
                    child: Text(item['emoji'] ?? '🏢'),
                  ),
                  title: Text(item['nome'] ?? ''),
                  subtitle: Text(item['status'] ?? ''),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showEditDialog(index: index),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _deleteItem(index),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Nova Área'),
      ),
    );
  }
}

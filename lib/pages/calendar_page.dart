/// Agenda local de uso dos espaços (não utilizada).
///
/// Código órfão: não é alcançável a partir de `main.dart`. Toda a agenda é
/// persistida em `SharedPreferences`, sob a chave `bookings_list`, e nunca
/// toca o Cloud Firestore. Os dados ficam isolados por dispositivo e o modelo
/// não corresponde à coleção `reservas`, o que a torna incompatível com o
/// restante do sistema.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/services/auth_service.dart';

class CalendarPage extends StatefulWidget {
  final List<Map<String, dynamic>> espacos;
  final AuthService authService;

  const CalendarPage({Key? key, required this.espacos, required this.authService}) : super(key: key);

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

/// Agendamento local usado apenas por [CalendarPage].
class Booking {
  /// Nome do espaço reservado.
  final String espaco;
  final String date; // yyyy-MM-dd
  final String time; // HH:mm
  final int durationMinutes;
  final String reservedBy; // username who reserved

  /// Cria um agendamento.
  Booking({required this.espaco, required this.date, required this.time, required this.durationMinutes, required this.reservedBy});

  /// Serializa o agendamento para armazenamento em `SharedPreferences`.
  Map<String, dynamic> toJson() => {
        'espaco': espaco,
        'date': date,
        'time': time,
        'duration': durationMinutes,
        'reservedBy': reservedBy,
      };

  /// Reconstrói um agendamento a partir do mapa serializado.
  ///
  /// `reservedBy` assume `'unknown'` quando ausente.
  static Booking fromJson(Map<String, dynamic> m) => Booking(
        espaco: m['espaco'] as String,
        date: m['date'] as String,
        time: m['time'] as String,
        durationMinutes: (m['duration'] as num).toInt(),
        reservedBy: (m['reservedBy'] as String?) ?? 'unknown',
      );
}

class _CalendarPageState extends State<CalendarPage> {
  /// Chave de persistência da agenda em `SharedPreferences`.
  static const _kBookingsKey = 'bookings_list';

  late List<Map<String, dynamic>> _espacos;
  String? _selectedEspaco;
  DateTime _selectedDate = DateTime.now();
  List<Booking> _bookings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _espacos = widget.espacos;
    if (_espacos.isNotEmpty) _selectedEspaco = _espacos.first['nome'] as String;
    _loadBookings();
  }

  /// Lê a agenda do armazenamento local.
  ///
  /// Conteúdo corrompido resulta em agenda vazia.
  Future<void> _loadBookings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kBookingsKey);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        _bookings = list.map((e) => Booking.fromJson(Map<String, dynamic>.from(e))).toList();
      } catch (_) {
        _bookings = [];
      }
    } else {
      _bookings = [];
    }
    setState(() {
      _loading = false;
    });
  }

  /// Persiste a agenda no armazenamento local como JSON.
  Future<void> _saveBookings() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _bookings.map((b) => b.toJson()).toList(growable: false);
    await prefs.setString(_kBookingsKey, jsonEncode(list));
  }

  /// Filtra a agenda pelo espaço e pela data selecionados, ordenando por
  /// horário.
  List<Booking> _bookingsForSelected() {
    final keyDate = _formatDate(_selectedDate);
    return _bookings.where((b) => b.espaco == _selectedEspaco && b.date == keyDate).toList()
      ..sort((a, b) => a.time.compareTo(b.time));
  }

  /// Formata a data como `yyyy-MM-dd`, usada como chave de comparação.
  String _formatDate(DateTime dt) => '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  /// Abre o seletor de data da agenda.
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final res = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year, now.month - 6),
      lastDate: DateTime(now.year + 2),
    );
    if (res != null) setState(() => _selectedDate = res);
  }

  /// Cria um agendamento local.
  ///
  /// Exige reautenticação do morador por `verifyCredentials`, coleta horário e
  /// duração (30 a 240 minutos) e recusa quando já existe agendamento no mesmo
  /// horário — a comparação é por igualdade de string, não por sobreposição.
  Future<void> _addBooking() async {
    if (_selectedEspaco == null) return;

    // pedir credenciais do usuário (nome + senha) para confirmar identidade
    final creds = await showDialog<Map<String, String>?>(
      context: context,
      builder: (c) {
        final userController = TextEditingController();
        final passController = TextEditingController();
        return AlertDialog(
          title: const Text('Confirme suas credenciais'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: userController, decoration: const InputDecoration(labelText: 'Usuário')),
              TextField(controller: passController, decoration: const InputDecoration(labelText: 'Senha'), obscureText: true),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, null), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.pop(c, {'u': userController.text, 'p': passController.text}), child: const Text('OK')),
          ],
        );
      },
    );

    if (creds == null) return;

    // Verificar as credenciais sem mudar a sessão
    dynamic verifiedUser;
    try {
      verifiedUser = await widget.authService.verifyCredentials(creds['u'] ?? '', creds['p'] ?? '');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falha na autenticação: ${e.toString()}')));
      return;
    }

    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null) return;

    final duration = await showDialog<int?>(
      context: context,
      builder: (c) {
        int minutes = 60;
        return AlertDialog(
          title: const Text('Duração (minutos)'),
          content: StatefulBuilder(builder: (c2, setState2) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Slider(
                  value: minutes.toDouble(),
                  min: 30,
                  max: 240,
                  divisions: 7,
                  label: '$minutes min',
                  onChanged: (v) => setState2(() => minutes = v.toInt()),
                ),
                Text('$minutes minutos'),
              ],
            );
          }),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, null), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.pop(c, minutes), child: const Text('OK')),
          ],
        );
      },
    );

    if (duration == null) return;

    final booking = Booking(
      espaco: _selectedEspaco!,
      date: _formatDate(_selectedDate),
      time: time.format(context),
      durationMinutes: duration,
      reservedBy: verifiedUser.username ?? 'unknown',
    );

    // basic conflict detection: same space and overlapping time (by string compare for simplicity)
    final existing = _bookingsForSelected();
    final conflict = existing.any((b) => b.time == booking.time);
    if (conflict) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Horário já reservado')));
      return;
    }

    setState(() {
      _bookings.add(booking);
    });
    await _saveBookings();
  }

  /// Cancela um agendamento, restrito a administradores.
  Future<void> _deleteBooking(Booking b) async {
    // Apenas admins podem cancelar reservas
    final current = widget.authService.currentUser;
    if (current == null || current.role != 'admin') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Apenas administradores podem cancelar reservas')));
      return;
    }

    // pedir confirmação antes de excluir
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Confirmar cancelamento'),
        content: Text('Deseja cancelar a reserva de ${b.reservedBy} para ${b.espaco} em ${b.date} às ${b.time}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Não')),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sim')),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _bookings.remove(b));
    await _saveBookings();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reserva cancelada')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendário'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Espaço selector
                  DropdownButtonFormField<String>(
                    initialValue: _selectedEspaco,
                    decoration: const InputDecoration(labelText: 'Espaço'),
                    items: _espacos.map((e) => DropdownMenuItem(value: e['nome'] as String, child: Text(e['nome'] as String))).toList(),
                    onChanged: (v) => setState(() => _selectedEspaco = v),
                  ),
                  const SizedBox(height: 12),

                  // Date picker
                  Row(
                    children: [
                      Text('Data: ${_formatDate(_selectedDate)}'),
                      const SizedBox(width: 12),
                      ElevatedButton(onPressed: _pickDate, child: const Text('Selecionar data')),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Bookings list for selected
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Agendamentos', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Expanded(
                              child: _bookingsForSelected().isEmpty
                                  ? const Center(child: Text('Sem agendamentos'))
                                  : ListView.builder(
                                      itemCount: _bookingsForSelected().length,
                                      itemBuilder: (context, i) {
                                        final b = _bookingsForSelected()[i];
                                        return ListTile(
                                          title: Text('${b.time} (${b.durationMinutes} min) — ${b.reservedBy}'),
                                          subtitle: Text('${b.espaco} — ${b.date}'),
                                          trailing: widget.authService.currentUser?.role == 'admin'
                                              ? IconButton(
                                                  icon: const Icon(Icons.delete),
                                                  onPressed: () => _deleteBooking(b),
                                                )
                                              : const SizedBox.shrink(),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      ElevatedButton.icon(onPressed: _addBooking, icon: const Icon(Icons.add), label: const Text('Agendar')),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context, _bookings),
                        icon: const Icon(Icons.check),
                        label: const Text('Concluir'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}


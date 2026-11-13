/// Formulário de criação de reserva.
///
/// Concentra a maior parte das regras de domínio do SIGEC: vínculo com
/// unidade, capacidade, horário de funcionamento, intervalo válido,
/// antecedência do salão, unicidade diária por espaço, conflito de horário da
/// unidade e limite de duas reservas futuras.
///
/// As verificações ocorrem no cliente e não são transacionais: duas
/// submissões simultâneas podem violar as regras de contagem e de conflito.
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

// Mascara entrada de horarios formato HH:MM
/// Aplica máscara `HH:MM` a um campo de horário.
///
/// Mantém apenas dígitos, limita o total a quatro e insere `:` após o
/// segundo dígito, reposicionando o cursor ao final do texto formatado.
///
/// Exportado e reutilizado por `space_page.dart` e
/// `reservas_admin_page.dart`.
class HoraInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.length > 4) {
      digits = digits.substring(0, 4);
    }

    String formatted = '';
    if (digits.length >= 3) {
      formatted = digits.substring(0, 2) + ':' + digits.substring(2);
    } else {
      formatted = digits;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

//classe principal
/// Tela de solicitação de reserva.
class ReservarEspacoPage extends StatefulWidget {
  /// Login do morador que está solicitando a reserva; vira `id_morador`.
  final String userId;

  const ReservarEspacoPage({Key? key, required this.userId}) : super(key: key);

  @override
  State<ReservarEspacoPage> createState() => _ReservarEspacoPageState();
}

class _ReservarEspacoPageState extends State<ReservarEspacoPage> {
  /// Chave de validação do formulário.
  final _formKey = GlobalKey<FormState>();
  /// Nome do espaço selecionado.
  String? _espaco;
  DateTime? _dataReserva;
  String? _horaInicio;
  String? _horaFim;
  String? _observacoes;
  int? _qtdConvidados; // já armazenará convidados + proprietário

  /// Combina uma data e um horário `HH:MM` em um [DateTime].
  ///
  /// Retorna `null` quando a data é nula, o horário não contém `:`, não tem
  /// exatamente duas partes ou os componentes não são numéricos.
  ///
  /// É o utilitário usado nas comparações de intervalo das regras de conflito
  /// e de contagem de reservas futuras.
  DateTime? horaReserva(Timestamp? dataReserva, String? hora) {
    if (dataReserva == null || hora == null || !hora.contains(':')) {
      return null;
    }

    final partes = hora.split(':');
    if (partes.length != 2) return null;

    final horaDoDia = int.tryParse(partes[0]);
    final minuto = int.tryParse(partes[1]);
    if (horaDoDia == null || minuto == null) return null;

    final data = dataReserva.toDate();
    return DateTime(data.year, data.month, data.day, horaDoDia, minuto);
  }

  /// Carrega os espaços marcados como disponíveis.
  ///
  /// Filtra por `status_disponivel == 'S'` sem tolerância a valores
  /// booleanos; espaços gravados como booleano não aparecem neste seletor.
  Future<List<Map<String, dynamic>>> _fetchEspacosDisponiveis() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('espacos')
        .where('status_disponivel', isEqualTo: 'S')
        .get();
    // retornamos cada doc.data() (Map)
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  // Função para validar horários no formato HH:MM
  /// Valida um horário no formato `HH:MM`, com hora em 0–23 e minuto em 0–59.
  bool _isValidTime(String? time) {
    if (time == null || time.isEmpty) return false;

    final parts = time.split(':');
    if (parts.length != 2) return false;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) return false;
    if (hour < 0 || hour > 23) return false;
    if (minute < 0 || minute > 59) return false;

    return true;
  }

  /// Indica se [time] é anterior a [reference] no mesmo dia.
  bool _isTimeBefore(TimeOfDay time, TimeOfDay reference) {
    return time.hour < reference.hour ||
        (time.hour == reference.hour && time.minute < reference.minute);
  }

  /// Indica se [time] é posterior a [reference] no mesmo dia.
  bool _isTimeAfter(TimeOfDay time, TimeOfDay reference) {
    return time.hour > reference.hour ||
        (time.hour == reference.hour && time.minute > reference.minute);
  }

  /// Executa todas as validações e grava a reserva.
  ///
  /// Cada falha interrompe o fluxo com uma mensagem ao usuário. A ordem das
  /// verificações é: campos obrigatórios, formato dos horários, existência do
  /// espaço, existência do morador, unidade vinculada, capacidade, horário de
  /// funcionamento, intervalo válido, antecedência de 48 h para o salão,
  /// unicidade por espaço e data, conflito de horário da unidade e limite de
  /// duas reservas futuras.
  ///
  /// Em sucesso, grava o documento com `status: 'PENDENTE'` e retorna à tela
  /// anterior.
  Future<void> _criarReserva() async {
    // valida o form
    if (!_formKey.currentState!.validate()) return;

    // salva os campos (onSaved)
    _formKey.currentState!.save();

    // checagens básicas de null (evita crashes)
    if (_espaco == null ||
        _dataReserva == null ||
        _horaInicio == null ||
        _horaFim == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha todos os campos obrigatórios.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    // Validar horários de início e fim
    if (!_isValidTime(_horaInicio) || !_isValidTime(_horaFim)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Horários inválidos. Use o formato HH:MM.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Buscar os dados do espaço selecionado
    final espacoQuery = await FirebaseFirestore.instance
        .collection('espacos')
        .where('nome', isEqualTo: _espaco)
        .limit(1)
        .get();

    if (espacoQuery.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Espaço selecionado não encontrado.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final espacoDoc = espacoQuery.docs.first;
    final espacoData = espacoDoc.data();

    // Validar se o usuário tem um apartamento associado

    final moradorDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get();

    if (!moradorDoc.exists || moradorDoc.data() == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Usuário não encontrado.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final moradorData = moradorDoc.data()!;
    final unidade = moradorData['id_apartamento']?.toString().trim();

    if (unidade == null || unidade.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta unidade não está cadastrada para o usuário.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // --- CAPACIDADE MÁXIMA: ler qtd_pessoas com segurança ---
    int capacidadeMax = 0;
    final rawQtd = espacoData['qtd_pessoas'];
    if (rawQtd is int) {
      capacidadeMax = rawQtd;
    } else if (rawQtd is String) {
      capacidadeMax = int.tryParse(rawQtd) ?? 0;
    } else if (rawQtd is double) {
      capacidadeMax = rawQtd.toInt();
    }

    // Se _qtdConvidados ainda null (por algum motivo), garantir valor mínimo 1 (proprietário)
    final convidadosTotal = (_qtdConvidados != null) ? _qtdConvidados! : 1;

    // valida capacidade
    if (capacidadeMax > 0 && convidadosTotal > capacidadeMax) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Número máximo permitido neste espaço: $capacidadeMax pessoas.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // pegar horários do espaço (com segurança)
    TimeOfDay? horarioAbertura;
    TimeOfDay? horarioFechamento;
    try {
      final abertura = (espacoData['horario_abertura'] ?? '').toString();
      final fechamento = (espacoData['horario_fechamento'] ?? '').toString();

      if (abertura.isNotEmpty && abertura.contains(':')) {
        horarioAbertura = TimeOfDay(
          hour: int.parse(abertura.split(':')[0]),
          minute: int.parse(abertura.split(':')[1]),
        );
      }
      if (fechamento.isNotEmpty && fechamento.contains(':')) {
        horarioFechamento = TimeOfDay(
          hour: int.parse(fechamento.split(':')[0]),
          minute: int.parse(fechamento.split(':')[1]),
        );
      }
    } catch (_) {
      // se falhar parse, continuamos, mas validaremos depois
      horarioAbertura = null;
      horarioFechamento = null;
    }

    // Converter os horários da reserva para TimeOfDay — com try/catch para evitar crash
    late TimeOfDay horaInicioTD;
    late TimeOfDay horaFimTD;
    try {
      final partsInicio = _horaInicio!.split(':');
      final partsFim = _horaFim!.split(':');
      horaInicioTD = TimeOfDay(
        hour: int.parse(partsInicio[0]),
        minute: int.parse(partsInicio[1]),
      );
      horaFimTD = TimeOfDay(
        hour: int.parse(partsFim[0]),
        minute: int.parse(partsFim[1]),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Formato de hora inválido. Use HH:MM.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validar se os horários estão dentro do intervalo permitido (se tivermos dados do espaço)
    if (horarioAbertura != null && horarioFechamento != null) {
      if (_isTimeBefore(horaInicioTD, horarioAbertura) ||
          _isTimeAfter(horaFimTD, horarioFechamento)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Horário da reserva está fora do horário de funcionamento do espaço.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // Validar — hora inicio < hora fim
    if (_isTimeAfter(horaInicioTD, horaFimTD) ||
        (horaInicioTD.hour == horaFimTD.hour &&
            horaInicioTD.minute == horaFimTD.minute)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hora de início deve ser menor que a hora de fim.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    // Validação para antecedência mínima de 48h para o salão de festas
    final inicioReserva = DateTime(
      _dataReserva!.year,
      _dataReserva!.month,
      _dataReserva!.day,
      horaInicioTD.hour,
      horaInicioTD.minute,
    );

    final nomeEspaco = _espaco!.trim().toLowerCase();
    final ehSalao =
        nomeEspaco.contains('salão') || nomeEspaco.contains('salao');

    if (ehSalao &&
        inicioReserva.isBefore(DateTime.now().add(const Duration(hours: 48)))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'O salão de festas exige antecedência mínima de 48 horas.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Verificar se já existe uma reserva para o mesmo espaço e data
    final reservasCollection = FirebaseFirestore.instance.collection(
      'reservas',
    );
    QuerySnapshot<Map<String, dynamic>> reservasExistentes;
    try {
      reservasExistentes = await reservasCollection
          .where('espaco', isEqualTo: _espaco)
          .where('data_reserva', isEqualTo: Timestamp.fromDate(_dataReserva!))
          .get();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível verificar o espaço: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (reservasExistentes.docs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Já existe uma reserva para este espaço nesta data.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    // Consultar as reservas futuras da unidade, considerando também os horários.
    final inicioDia = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    QuerySnapshot<Map<String, dynamic>> reservasUnidadeSnapshot;
    try {
      reservasUnidadeSnapshot = await reservasCollection
          .where('id_unidade', isEqualTo: unidade)
          .where(
            'data_reserva',
            isGreaterThanOrEqualTo: Timestamp.fromDate(inicioDia),
          )
          .get();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Não foi possível consultar as reservas da unidade: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    DateTime? fimReservaExistente(Map<String, dynamic> data) {
      final dataReserva = (data['data_reserva'] as Timestamp?)?.toDate();
      final horaFim = data['hora_fim']?.toString().split(':');
      if (dataReserva == null || horaFim == null || horaFim.length != 2) {
        return null;
      }

      final hora = int.tryParse(horaFim[0]);
      final minuto = int.tryParse(horaFim[1]);
      if (hora == null || minuto == null) return null;

      return DateTime(
        dataReserva.year,
        dataReserva.month,
        dataReserva.day,
        hora,
        minuto,
      );
    }

    final agora = DateTime.now();
    final reservasAtivas = reservasUnidadeSnapshot.docs.where((doc) {
      final data = doc.data();
      final status = (data['status'] ?? '').toString().toUpperCase();
      final statusAtivo =
          status != 'CANCELADA' &&
          status != 'RECUSADA' &&
          status != 'REJEITADA' &&
          status != 'REALIZADA';
      final fim = fimReservaExistente(data);

      return statusAtivo && (fim == null || fim.isAfter(agora));
    }).length;

    final inicioNovaReserva = horaReserva(
      Timestamp.fromDate(_dataReserva!),
      _horaInicio,
    );
    final fimNovaReserva = horaReserva(
      Timestamp.fromDate(_dataReserva!),
      _horaFim,
    );

    final conflitoHorario =
        inicioNovaReserva != null &&
        fimNovaReserva != null &&
        reservasUnidadeSnapshot.docs.any((doc) {
          final data = doc.data();
          final status = (data['status'] ?? '').toString().toUpperCase();
          final statusAtivo =
              status != 'CANCELADA' &&
              status != 'RECUSADA' &&
              status != 'REJEITADA' &&
              status != 'REALIZADA';

          final dataReserva = (data['data_reserva'] as Timestamp?)?.toDate();
          final mesmaData =
              dataReserva != null &&
              dataReserva.year == _dataReserva!.year &&
              dataReserva.month == _dataReserva!.month &&
              dataReserva.day == _dataReserva!.day;
          if (!statusAtivo || !mesmaData) return false;

          final inicioExistente = horaReserva(
            data['data_reserva'] as Timestamp?,
            data['hora_inicio']?.toString(),
          );
          final fimExistente = horaReserva(
            data['data_reserva'] as Timestamp?,
            data['hora_fim']?.toString(),
          );

          return inicioExistente != null &&
              fimExistente != null &&
              inicioNovaReserva.isBefore(fimExistente) &&
              inicioExistente.isBefore(fimNovaReserva);
        });

    if (conflitoHorario) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta unidade já possui uma reserva neste horário.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (reservasAtivas >= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta unidade já possui 2 reservas futuras.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final novaReservaRef = reservasCollection.doc();
      final novaReserva = {
        'data_criacao': FieldValue.serverTimestamp(),
        'data_reserva': Timestamp.fromDate(_dataReserva!),
        'espaco': _espaco,
        'hora_inicio': _horaInicio,
        'hora_fim': _horaFim,
        'id_unidade': unidade,
        'id_morador': widget.userId,
        'observacoes': _observacoes,
        'qtd_convidados': convidadosTotal,
        'status': 'PENDENTE',
        'id_reserva': DateTime.now().millisecondsSinceEpoch,
      };

      await novaReservaRef.set(novaReserva);
    } catch (e) {
      final firebaseError = e is FirebaseException ? e : null;
      final mensagem =
          firebaseError?.message ??
          e.toString().replaceFirst('Exception: ', '');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            mensagem.contains('já possui 2 reservas')
                ? 'Esta unidade já possui 2 reservas futuras.'
                : firebaseError?.code == 'permission-denied'
                ? 'Não foi possível criar a reserva: acesso não autorizado.'
                : 'Não foi possível criar a reserva: $mensagem',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reserva criada com sucesso!'),
        backgroundColor: Colors.green,
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reservar Espaço'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchEspacosDisponiveis(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Nenhum espaço disponível.'));
          }

          final espacos = snapshot.data!;
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Espaço'),
                    initialValue: _espaco,
                    items: espacos.map((espaco) {
                      return DropdownMenuItem<String>(
                        value: espaco['nome'],
                        child: Text(espaco['nome']),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _espaco = value;
                      });
                    },
                    validator: (value) =>
                        value == null ? 'Selecione um espaço' : null,
                  ),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Data da Reserva',
                    ),
                    readOnly: true,
                    onTap: () async {
                      final data = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (data != null) {
                        setState(() {
                          _dataReserva = data;
                        });
                      }
                    },
                    validator: (value) =>
                        _dataReserva == null ? 'Selecione uma data' : null,
                    controller: TextEditingController(
                      text: _dataReserva != null
                          ? '${_dataReserva!.day}/${_dataReserva!.month}/${_dataReserva!.year}'
                          : '',
                    ),
                  ),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Hora de Início (HH:MM)',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      HoraInputFormatter(),
                    ],
                    onSaved: (value) => _horaInicio = value,
                    validator: (value) => value == null || value.isEmpty
                        ? 'Informe a hora de início'
                        : null,
                  ),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Hora de Fim (HH:MM)',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      HoraInputFormatter(),
                    ],
                    onSaved: (value) => _horaFim = value,
                    validator: (value) => value == null || value.isEmpty
                        ? 'Informe a hora de fim'
                        : null,
                  ),

                  // NOVO CAMPO: Quantidade de convidados (antes das observações)
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Quantidade de Convidados',
                      hintText: 'Somente números (sem contar o proprietário)',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value == null || value.isEmpty)
                        return 'Informe a quantidade';
                      final v = int.tryParse(value);
                      if (v == null) return 'Informe um número válido';
                      if (v < 0) return 'Informe um número válido';
                      return null;
                    },
                    onSaved: (value) {
                      final conv = int.tryParse(value ?? '0') ?? 0;
                      _qtdConvidados = conv + 1; // convidados + proprietário
                    },
                  ),

                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Observações'),
                    onSaved: (value) => _observacoes = value,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _criarReserva,
                    child: const Text('Reservar'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

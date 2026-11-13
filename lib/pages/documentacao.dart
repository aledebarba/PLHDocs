/// Tela «Sobre», com a documentação de uso embutida no aplicativo.
///
/// Conteúdo integralmente estático, apresentado como um único texto rico com
/// seções sobre acesso, visualização de espaços, reservas, segurança e
/// experiência de uso. Não consome serviços nem mantém estado.
import 'package:flutter/material.dart';

/// Página estática de documentação do sistema.
class DocumentacaoPage extends StatelessWidget {
  const DocumentacaoPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Documentação do Sistema"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: const Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: "Sistema de Reservas do Condomínio\n\n",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),

              TextSpan(
                text:
                    "O aplicativo foi criado para facilitar o uso dos espaços comuns do condomínio, permitindo que moradores e administradores gerenciem informações e reservas de forma prática e segura.\n\n",
                style: TextStyle(fontSize: 16),
              ),

              // Acesso Personalizado
              TextSpan(
                text: "Acesso Personalizado\n",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text:
                    "• Cada usuário possui seu login próprio.\n"
                    "• Moradores visualizam apenas suas reservas.\n"
                    "• Administradores podem acessar e gerenciar todas as informações do sistema.\n\n",
                style: TextStyle(fontSize: 16),
              ),

              // Visualização dos Espaços
              TextSpan(
                text: "Visualização dos Espaços\n",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text:
                    "• Exibição de todos os espaços do condomínio.\n"
                    "• Moradores podem visualizar detalhes dos espaços.\n"
                    "• Administradores podem criar, editar e gerenciar cada espaço.\n\n",
                style: TextStyle(fontSize: 16),
              ),

              // Reservas
              TextSpan(
                text: "Reservas\n",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text:
                    "• Moradores visualizam apenas suas próprias reservas.\n"
                    "• Administradores visualizam todas as reservas.\n"
                    "• Cada reserva apresenta data, horários, espaço selecionado, status e observações.\n"
                    "• O sistema valida horários para impedir que o início seja maior que o fim.\n\n",
                style: TextStyle(fontSize: 16),
              ),

              // Segurança
              TextSpan(
                text: "Segurança e Armazenamento\n",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text:
                    "• Informações armazenadas com segurança no Firestore.\n"
                    "• Permissões aplicadas conforme o papel do usuário (role).\n"
                    "• Atualizações em tempo real.\n\n",
                style: TextStyle(fontSize: 16),
              ),

              // Experiência
              TextSpan(
                text: "Experiência Intuitiva\n",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text:
                    "• Navegação simples e rápida.\n"
                    "• Menus organizados.\n"
                    "• Mensagens claras e amigáveis.\n"
                    "• Conteúdo exibido conforme o tipo de usuário.",
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tela de autenticação do SIGEC.
///
/// Renderizada por `MyApp` quando não há sessão ativa. Delega a verificação
/// de credenciais a `AuthService.login` e, em caso de erro, exibe uma
/// mensagem genérica — as mensagens específicas do serviço não chegam ao
/// usuário.
import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/auth_service.dart';

/// Página de login.
class LoginPage extends StatefulWidget {
  /// Serviço de autenticação usado ao submeter o formulário.
  final AuthService authService;

  const LoginPage({Key? key, required this.authService}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState(); // Corrigido para usar "State<LoginPage>"
}

class _LoginPageState extends State<LoginPage> {
  /// Chave de validação do formulário.
  final _formKey = GlobalKey<FormState>();
  /// Controlador do campo de login.
  final _loginController = TextEditingController();
  /// Controlador do campo de senha.
  final _passwordController = TextEditingController();
  /// Indica submissão em andamento; troca o botão por um indicador.
  bool _isLoading = false;
  /// Habilita o botão «Entrar» quando ambos os campos têm conteúdo.
  bool _isButtonEnabled = false;

  @override
  void initState() {
    super.initState();

    // Adiciona listeners para monitorar mudanças nos campos
    _loginController.addListener(_updateButtonState);
    _passwordController.addListener(_updateButtonState);
  }

  /// Recalcula [_isButtonEnabled] a cada alteração nos campos.
  void _updateButtonState() {
    setState(() {
      _isButtonEnabled =
          _loginController.text.isNotEmpty &&
          _passwordController.text.isNotEmpty;
    });
  }

  /// Valida o formulário e tenta autenticar.
  ///
  /// Em sucesso, apenas exibe confirmação: a troca de tela é consequência de
  /// `notifyListeners()` em `AuthService`. Em falha, mostra uma mensagem
  /// genérica, sem distinguir usuário inexistente, desabilitado ou senha
  /// incorreta.
  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Chama o método de login do AuthService
        await widget.authService.login(
          _loginController.text.trim(),
          _passwordController.text.trim(),
        );

        // Exibe mensagem de sucesso
        if (!mounted) return; // Verifica se o widget ainda está montado
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Login realizado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        // Exibe mensagem de erro genérica
        if (!mounted) return; // Verifica se o widget ainda está montado
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Login ou Senha inválidos'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login'), centerTitle: true),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Ícone de login
                const Icon(Icons.lock_outline, size: 80, color: Colors.indigo),
                const SizedBox(height: 16),
                const Text(
                  'Acesse sua conta',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
                const SizedBox(height: 32),

                // Campo de login
                TextFormField(
                  controller: _loginController,
                  decoration: const InputDecoration(
                    labelText: 'Login',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  keyboardType: TextInputType.text,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Login ou Senha inválidos';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Campo de senha
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Senha',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Login ou Senha inválidos';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Botão de login ou indicador de carregamento
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _isButtonEnabled ? _login : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 32,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Entrar',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),

                const SizedBox(height: 32),

                // Mensagem de rodapé
                const Text(
                  'Para redefinição de senha contate o administrador',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _loginController.removeListener(_updateButtonState);
    _passwordController.removeListener(_updateButtonState);
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

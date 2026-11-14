import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'Tela_inicial.dart';

class TelaRedefinirSenha extends StatefulWidget {
  const TelaRedefinirSenha({super.key});

  @override
  State<TelaRedefinirSenha> createState() => _TelaRedefinirSenhaState();
}

class _TelaRedefinirSenhaState extends State<TelaRedefinirSenha> {
  final _senha = TextEditingController();
  final _confirmacao = TextEditingController();
  bool _salvando = false;
  bool _senhaAlterada = false;

  Future<void> _salvarNovaSenha() async {
    if (_salvando) return;

    final senha = _senha.text;
    if (!_senhaAlterada && (senha.isEmpty || senha != _confirmacao.text)) {
      _mostrarMensagem('Preencha os dois campos com a mesma senha.');
      return;
    }

    setState(() => _salvando = true);
    final auth = Supabase.instance.client.auth;

    try {
      if (!_senhaAlterada) {
        await auth.updateUser(UserAttributes(password: senha));
        _senhaAlterada = true;
      }

      await auth.signOut();
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil<void>(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
      _mostrarMensagem('Senha alterada. Entre com a nova senha.');
    } on AuthException catch (erro) {
      if (!mounted) return;
      _mostrarMensagem(
        _senhaAlterada
            ? 'Senha alterada. Toque em Voltar ao login para tentar novamente.'
            : erro.message,
      );
    } catch (_) {
      if (!mounted) return;
      _mostrarMensagem('Ocorreu um erro. Tente novamente.');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  void _mostrarMensagem(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto)),
    );
  }

  @override
  void dispose() {
    _senha.dispose();
    _confirmacao.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
  final decoracaoCampo = InputDecoration(
    filled: true,
    fillColor: const Color(0xFFF4F9FD),
    prefixIcon: const Icon(
      Icons.lock_outline,
      color: Color(0xFF0754A5),
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFD7E7F0)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(
        color: Color(0xFF0754A5),
        width: 2,
      ),
    ),
  );

  return PopScope(
    canPop: false,
    child: Scaffold(
      backgroundColor: const Color(0xFFE8F7FF),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFB3D8F5),
              Color(0xFFF0F7FF),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Card(
                  color: Colors.white,
                  surfaceTintColor: Colors.transparent,
                  elevation: 8,
                  shadowColor: const Color(0x220754A5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(
                          Icons.water_drop_rounded,
                          size: 52,
                          color: Color(0xFF168EE5),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'FloodSense',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF0754A5),
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 28),
                        const Text(
                          'Crie sua nova senha',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF0754A5),
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Digite a nova senha e confirme no campo abaixo.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF53627A),
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 28),
                        TextField(
                          controller: _senha,
                          obscureText: true,
                          enabled: !_salvando && !_senhaAlterada,
                          enableSuggestions: false,
                          autocorrect: false,
                          textInputAction: TextInputAction.next,
                          decoration: decoracaoCampo.copyWith(
                            labelText: 'Nova senha',
                          ),
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: _confirmacao,
                          obscureText: true,
                          enabled: !_salvando && !_senhaAlterada,
                          enableSuggestions: false,
                          autocorrect: false,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _salvarNovaSenha(),
                          decoration: decoracaoCampo.copyWith(
                            labelText: 'Confirmar nova senha',
                          ),
                        ),
                        const SizedBox(height: 28),
                        FilledButton(
                          onPressed: _salvando ? null : _salvarNovaSenha,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFFF861D),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 18,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _salvando
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _senhaAlterada
                                      ? 'Voltar ao login'
                                      : 'Salvar nova senha',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
}
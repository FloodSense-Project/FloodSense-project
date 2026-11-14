// Importação do pacote principal do Flutter para a interface visual
import 'package:flutter/material.dart';

// Importação do pacote oficial do Supabase para conectar com o banco de dados
import 'package:supabase_flutter/supabase_flutter.dart';

// Conecta a interface de login ("Tela_inicial.dart") com o "main.dart"
import 'Tela_inicial.dart';

import 'dart:async';

import 'Tela_redefinir_senha.dart';

import 'package:flutter/foundation.dart';


// IMPORTAÇÃO DA TELA DE OCORRÊNCIA (Necessário para o app saber para onde ir se estiver logado)

// =========================================================================
// ATALHO GLOBAL DO SUPABASE
// Permite usar o comando 'supabase' em qualquer tela do app de forma simples
// =========================================================================
final supabase = Supabase.instance.client;

// A função main() é a primeira coisa que o celular executa quando abre o App.
// O 'async' permite que o app espere o Supabase conectar antes de desenhar a tela.
Future<void> main() async {
  // Garante a inicialização dos componentes nativos do Flutter antes de ligar o banco
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa a conexão com o servidor do Supabase
  await Supabase.initialize(
    authOptions: FlutterAuthClientOptions(
    detectSessionInUri: !kIsWeb,
   ),
    url: 'https://ntmvcluauovtxvbissku.supabase.co',      // URl que conecta o app ao banco de dados do Supabase
    publishableKey: 'sb_publishable_GxRL1O1fCQD0T0q19i0T-w_uzF68kOa', // chave publica de identificação do app no Supabase
  );

  // 'runApp' diz ao Flutter para rodar a classe principal 'FloodSenseApp'
  runApp(const FloodSenseApp());
}

// ==========================================
// CLASSE PRINCIPAL DO APLICATIVO
// ==========================================
class FloodSenseApp extends StatefulWidget {
  const FloodSenseApp({super.key});

  @override
  State<FloodSenseApp> createState() => _FloodSenseAppState();
}

class _FloodSenseAppState extends State<FloodSenseApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final StreamSubscription<AuthState> _authSubscription;
  bool _redefinicaoAberta = false;

  @override
  void initState() {
    super.initState();

    _authSubscription = supabase.auth.onAuthStateChange.listen(
      (state) {
        if (state.event != AuthChangeEvent.passwordRecovery ||
            state.session == null ||
            _redefinicaoAberta) {
          return;
        }

        _redefinicaoAberta = true;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;

          await _navigatorKey.currentState!.push<void>(
            MaterialPageRoute(
              builder: (_) => const TelaRedefinirSenha(),
            ),
          );

          _redefinicaoAberta = false;
        });
        WidgetsBinding.instance.ensureVisualUpdate();
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Falha ao processar um evento de autenticação.');
      },
    );
    if (kIsWeb) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) {
      unawaited(_processarLinkWeb());
      }
    });
   }
  }
  Future<void> _processarLinkWeb() async {
  final uri = Uri.base;
  final parametros = {
    ...uri.queryParameters,
    ...Uri.splitQueryString(uri.fragment),
  };

  final tokenHash = parametros['token_hash'];
  final temRetorno = tokenHash != null ||
      parametros.containsKey('code') ||
      parametros.containsKey('access_token') ||
      parametros.containsKey('error') ||
      parametros.containsKey('error_description');

  if (!temRetorno) return;

  try {
    if (tokenHash != null) {
      if (tokenHash.isEmpty || parametros['type'] != 'recovery') {
        throw const AuthException('Link de recuperação inválido.');
      }

      await supabase.auth.verifyOTP(
        tokenHash: tokenHash,
        type: OtpType.recovery,
      );
    } else {
      await supabase.auth.getSessionFromUrl(uri);
    }
  } catch (erro) {
    debugPrint('ERRO NO LINK DE RECUPERACAO: $erro');

    if (!mounted) return;
    final contexto = _navigatorKey.currentContext;
    if (contexto == null || !contexto.mounted) return;

    ScaffoldMessenger.of(contexto).showSnackBar(
      const SnackBar(
        content: Text(
          'Não foi possível validar o link. Solicite outro e-mail.',
        ),
        duration: Duration(seconds: 10),
      ),
    );
  }
}
  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'FloodSense',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto',
      ),
      home: const LoginPage(),
    );
  }
}
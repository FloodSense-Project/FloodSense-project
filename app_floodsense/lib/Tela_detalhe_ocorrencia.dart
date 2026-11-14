import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TelaDetalheOcorrencia extends StatefulWidget {
  final int idOcorrencia;
  final int numeroOcorrencia;

  const TelaDetalheOcorrencia({
    super.key,
    required this.idOcorrencia,
    required this.numeroOcorrencia,
  });

  @override
  State<TelaDetalheOcorrencia> createState() =>
      _TelaDetalheOcorrenciaState();
}

class _TelaDetalheOcorrenciaState
    extends State<TelaDetalheOcorrencia> {
  late Future<Map<String, dynamic>> _detalhes;

  @override
  void initState() {
    super.initState();
    _detalhes = _buscarDetalhes();
  }

  Future<Map<String, dynamic>> _buscarDetalhes() async {
    final cliente = Supabase.instance.client;
    final usuario = cliente.auth.currentUser;

    if (usuario == null) {
      throw const AuthException('Entre na sua conta para continuar.');
    }

    final ocorrencia = await cliente
        .from('ocorrencia')
        .select('id_ocorrencia, descricao, status')
        .eq('id_ocorrencia', widget.idOcorrencia)
        .eq('id_usuario', usuario.id)
        .maybeSingle();

    if (ocorrencia == null) {
      throw StateError('Ocorrência não encontrada.');
    }

    final imagens = await cliente
        .from('imagem')
        .select('caminho_imagem')
        .eq('id_ocorrencia', widget.idOcorrencia);

    return {
      ...ocorrencia,
      'imagens': imagens,
    };
  }

  void _atualizar() {
    setState(() {
      _detalhes = _buscarDetalhes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F7FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE8F7FF),
        foregroundColor: const Color(0xFF0754A5),
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Text('Ocorrência ${widget.numeroOcorrencia}'),
        actions: [
          IconButton(
            onPressed: _atualizar,
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _detalhes,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Não foi possível carregar a ocorrência.'),
                  ElevatedButton(
                    onPressed: _atualizar,
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            );
          }

          final dados = snapshot.data!;
          final imagens =
              dados['imagens'] as List<Map<String, dynamic>>;
          final descricao =
              (dados['descricao'] as String?)?.trim() ?? '';
          final status =
              dados['status'] as String? ?? 'Não informado';

          return Center(
          child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
          Card(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 2,
          shadowColor: const Color(0x220754A5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Acompanhamento',
                  style: TextStyle(
                    color: Color(0xFF0754A5),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Status atual da sua ocorrência',
                  style: TextStyle(color: Color(0xFF53627A)),
                ),
                const SizedBox(height: 12),
                Chip(
                  avatar: const Icon(
                    Icons.assignment_outlined,
                    color: Color(0xFF0754A5),
                    size: 20,
                  ),
                  label: Text(status),
                  labelStyle: const TextStyle(
                    color: Color(0xFF0754A5),
                    fontWeight: FontWeight.bold,
                  ),
                  backgroundColor: const Color(0xFFE8F7FF),
                  side: BorderSide.none,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Divider(color: Color(0xFFD7E7F0)),
                ),
                const Text(
                  'Descrição',
                  style: TextStyle(
                    color: Color(0xFF0754A5),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  descricao.isEmpty ? 'Sem descrição' : descricao,
                  style: const TextStyle(
                    color: Color(0xFF53627A),
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Fotos da ocorrência',
                  style: TextStyle(
                    color: Color(0xFF0754A5),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                if (imagens.isEmpty)
                  const Text('Nenhuma foto disponível.'),
                for (final imagem in imagens)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F7FF),
                      border: Border.all(
                        color: const Color(0xFF0754A5),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        imagem['caminho_imagem'] as String,
                        height: 400,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox(
                          height: 120,
                          child: Center(
                            child: Text('Não foi possível carregar a foto.'),
                          ),
                         ),
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
        },
      ),
    );
  }
}
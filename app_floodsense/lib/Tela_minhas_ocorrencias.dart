import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'Tela_detalhe_ocorrencia.dart';

class TelaMinhasOcorrencias extends StatefulWidget {
  const TelaMinhasOcorrencias({super.key});

  @override
  State<TelaMinhasOcorrencias> createState() =>
      _TelaMinhasOcorrenciasState();
}

class _TelaMinhasOcorrenciasState
    extends State<TelaMinhasOcorrencias> {
  late Future<List<Map<String, dynamic>>> _ocorrencias;

  @override
  void initState() {
    super.initState();
    _ocorrencias = _buscarOcorrencias();
  }

  Future<List<Map<String, dynamic>>> _buscarOcorrencias() async {
    final cliente = Supabase.instance.client;
    final usuario = cliente.auth.currentUser;

    if (usuario == null) {
      throw const AuthException('Entre na sua conta para continuar.');
    }

    return await cliente
        .from('ocorrencia')
        .select('id_ocorrencia, descricao')
        .eq('id_usuario', usuario.id)
        .order('id_ocorrencia', ascending: false);
  }

  void _recarregar() {
    setState(() {
      _ocorrencias = _buscarOcorrencias();
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
        title: const Text('Minhas ocorrências'),
        actions: [
          IconButton(
            onPressed: _recarregar,
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _ocorrencias,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Não foi possível carregar suas ocorrências.'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _recarregar,
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            );
          }

          final itens = snapshot.data ?? [];

          if (itens.isEmpty) {
            return const Center(
              child: Text('Você ainda não tem ocorrências registradas.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: itens.length,
            itemBuilder: (context, indice) {
            final item = itens[indice];
            final numeroOcorrencia = itens.length - indice;
            final descricao =
           (item['descricao'] as String?)?.trim() ?? '';

          return Center(
            child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Card(
            color: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 2,
            shadowColor: const Color(0x220754A5),
            margin: const EdgeInsets.only(bottom: 16),
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
      ),
            child: ListTile(
            contentPadding: const EdgeInsets.all(20),
            minVerticalPadding: 20,
            onTap: () {
            Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TelaDetalheOcorrencia(
                idOcorrencia: item['id_ocorrencia'] as int,
                numeroOcorrencia: numeroOcorrencia,
              ),
            ),
          );
        },
        leading: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F7FF),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.assignment_outlined,
            color: Color(0xFF0754A5),
            size: 28,
          ),
        ),
        title: Text(
            'Ocorrência $numeroOcorrencia',
            style: const TextStyle(
            color: Color(0xFF0754A5),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            descricao.isEmpty ? 'Sem descrição' : descricao,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF53627A),
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_rounded,
          color: Color(0xFFFF861D),
        ),
      ),
    ),
  ),
);
            },
          );
        },
      ),
    );
  }
}
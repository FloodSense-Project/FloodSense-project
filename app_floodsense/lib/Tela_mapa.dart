import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'Tela_detalhe_ocorrencia.dart';

class TelaMapa extends StatefulWidget {
  const TelaMapa({super.key});

  @override
  State<TelaMapa> createState() => _TelaMapaState();
}

class _TelaMapaState extends State<TelaMapa> {
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

    final registros = await cliente
        .from('ocorrencia')
        .select('id_ocorrencia, latitude, longitude')
        .eq('id_usuario', usuario.id)
        .order('id_ocorrencia', ascending: false);

    final pontos = <Map<String, dynamic>>[];

    for (var indice = 0; indice < registros.length; indice++) {
      final registro = registros[indice];
      final latitude =
          double.tryParse('${registro['latitude']}');
      final longitude =
          double.tryParse('${registro['longitude']}');

      if (latitude == null ||
          longitude == null ||
          !latitude.isFinite ||
          !longitude.isFinite ||
          latitude.abs() > 90 ||
          longitude.abs() > 180) {
        continue;
      }

      // Coordenadas de exemplo usadas pelo formulário antigo.
      if (latitude == -23.5505 && longitude == -46.6333) {
        continue;
      }

      pontos.add({
        'id_ocorrencia': registro['id_ocorrencia'],
        'numero': registros.length - indice,
        'latitude': latitude,
        'longitude': longitude,
      });
    }

    return pontos;
  }

  void _atualizar() {
    setState(() {
      _ocorrencias = _buscarOcorrencias();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F7FF),
      appBar: AppBar(
        title: const Text('Mapa das minhas ocorrências'),
        centerTitle: true,
        backgroundColor: const Color(0xFFE8F7FF),
        foregroundColor: const Color(0xFF0754A5),
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: _atualizar,
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar mapa',
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
                  const Text('Não foi possível carregar o mapa.'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _atualizar,
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            );
          }

          final ocorrencias = snapshot.data ?? [];

          if (ocorrencias.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Você ainda não tem ocorrências com localização '
                  'válida para mostrar no mapa.\n\n'
                  'Registre uma usando a localização do dispositivo.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final coordenadas = ocorrencias.map((ocorrencia) {
            return LatLng(
              ocorrencia['latitude'] as double,
              ocorrencia['longitude'] as double,
            );
          }).toList();

          return Padding(
            padding: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: FlutterMap(
                key: ObjectKey(ocorrencias),
                options: MapOptions(
                  initialCenter: coordenadas.first,
                  initialZoom: 15,
                  initialCameraFit: coordenadas.length > 1
                      ? CameraFit.coordinates(
                          coordinates: coordenadas,
                          padding: const EdgeInsets.all(60),
                          maxZoom: 15,
                        )
                      : null,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'br.floodsense.app',
                  ),
                  MarkerLayer(
                    markers: ocorrencias.map((ocorrencia) {
                      final numero = ocorrencia['numero'] as int;

                      return Marker(
                        point: LatLng(
                          ocorrencia['latitude'] as double,
                          ocorrencia['longitude'] as double,
                        ),
                        width: 52,
                        height: 52,
                        child: IconButton(
                          tooltip: 'Ocorrência $numero',
                          icon: const Icon(
                            Icons.location_on,
                            color: Color(0xFFFF861D),
                            size: 40,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TelaDetalheOcorrencia(
                                  idOcorrencia:
                                      ocorrencia['id_ocorrencia'] as int,
                                  numeroOcorrencia: numero,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    }).toList(),
                  ),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Material(
                      color: Colors.white,
                      child: TextButton(
                        onPressed: () async {
                          await launchUrl(
                            Uri.parse(
                              'https://www.openstreetmap.org/copyright',
                            ),
                          );
                        },
                        child: const Text(
                          '© OpenStreetMap contributors',
                          style: TextStyle(fontSize: 11),
                        ),
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
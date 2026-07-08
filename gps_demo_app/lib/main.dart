import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

const defaultApiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'https://TU-SERVICIO.onrender.com',
);

void main() {
  runApp(const GpsDemoApp());
}

class GpsDemoApp extends StatelessWidget {
  const GpsDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Demo GPS',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const GpsHomePage(),
    );
  }
}

class GpsHomePage extends StatefulWidget {
  const GpsHomePage({super.key});

  @override
  State<GpsHomePage> createState() => _GpsHomePageState();
}

class _GpsHomePageState extends State<GpsHomePage> {
  final TextEditingController _apiController = TextEditingController(
    text: defaultApiUrl,
  );

  Position? _position;
  List<Map<String, dynamic>> _records = [];
  bool _busy = false;
  bool _hasError = false;
  String _status =
      'Pega la URL pública de Render y pulsa "Obtener y enviar ubicación".';

  @override
  void dispose() {
    _apiController.dispose();
    super.dispose();
  }

  Uri _locationsEndpoint() {
    var value = _apiController.text.trim();
    if (value.isEmpty || value.contains('TU-SERVICIO')) {
      throw const FormatException('Escribe primero la URL pública de Render.');
    }

    value = value.replaceFirst(RegExp(r'/+$'), '');
    if (!value.endsWith('/api/ubicaciones')) {
      value = '$value/api/ubicaciones';
    }

    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.hasScheme ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const FormatException(
        'La URL debe comenzar por https:// o http://.',
      );
    }
    return uri;
  }

  Future<void> _verifyLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('Activa la ubicación (GPS) del teléfono.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception('Debes permitir el acceso a la ubicación.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'El permiso GPS está bloqueado. Habilítalo en Ajustes > Aplicaciones.',
      );
    }
  }

  Future<Position> _getCurrentPosition() async {
    await _verifyLocationPermission();
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
  }

  Future<void> _sendLocation() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _hasError = false;
      _status = 'Obteniendo coordenadas del teléfono…';
    });

    try {
      final endpoint = _locationsEndpoint();
      final position = await _getCurrentPosition();
      if (!mounted) return;

      setState(() {
        _position = position;
        _status = 'Enviando datos al webhook…';
      });

      final payload = <String, dynamic>{
        'latitud': position.latitude,
        'longitud': position.longitude,
        'precision': position.accuracy,
        'altitud': position.altitude,
        'velocidad': position.speed,
        'rumbo': position.heading,
        'marca_tiempo': position.timestamp.toUtc().toIso8601String(),
      };

      final response = await http
          .post(
            endpoint,
            headers: const {'Content-Type': 'application/json; charset=UTF-8'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          'El servidor respondió HTTP ${response.statusCode}: ${response.body}',
        );
      }

      await _loadRecordsFromServer(endpoint);
      if (!mounted) return;
      setState(() {
        _status = '✓ Ubicación guardada en PostgreSQL. Historial actualizado.';
      });
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _loadRecords() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _hasError = false;
      _status = 'Consultando PostgreSQL mediante la API…';
    });

    try {
      await _loadRecordsFromServer(_locationsEndpoint());
      if (!mounted) return;
      setState(() {
        _status = '✓ Se cargaron ${_records.length} registros del servidor.';
      });
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _loadRecordsFromServer(Uri endpoint) async {
    final response = await http
        .get(endpoint)
        .timeout(const Duration(seconds: 30));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'El servidor respondió HTTP ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic> || decoded['ubicaciones'] is! List) {
      throw const FormatException('La respuesta del servidor no es válida.');
    }

    final records = (decoded['ubicaciones'] as List)
        .whereType<Map<String, dynamic>>()
        .toList();

    if (mounted) {
      setState(() => _records = records);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    final text = error
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst('FormatException: ', '');
    setState(() {
      _hasError = true;
      _status = 'Error: $text';
    });
  }

  String _number(dynamic value, [int decimals = 2]) {
    if (value == null) return '—';
    if (value is num) return value.toStringAsFixed(decimals);
    final parsed = num.tryParse(value.toString());
    return parsed?.toStringAsFixed(decimals) ?? value.toString();
  }

  Widget _dataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }

  Widget _currentLocationCard() {
    final position = _position;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Datos del teléfono',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Divider(),
            _dataRow(
              'Latitud',
              position == null ? '—' : position.latitude.toStringAsFixed(7),
            ),
            _dataRow(
              'Longitud',
              position == null ? '—' : position.longitude.toStringAsFixed(7),
            ),
            _dataRow(
              'Precisión',
              position == null
                  ? '—'
                  : '${position.accuracy.toStringAsFixed(2)} m',
            ),
            _dataRow(
              'Altitud',
              position == null
                  ? '—'
                  : '${position.altitude.toStringAsFixed(2)} m',
            ),
            _dataRow(
              'Velocidad',
              position == null
                  ? '—'
                  : '${position.speed.toStringAsFixed(2)} m/s',
            ),
            _dataRow(
              'Rumbo',
              position == null
                  ? '—'
                  : '${position.heading.toStringAsFixed(2)}°',
            ),
            _dataRow(
              'Marca tiempo',
              position?.timestamp.toLocal().toString() ?? '—',
            ),
          ],
        ),
      ),
    );
  }

  Widget _recordCard(Map<String, dynamic> record) {
    return Card(
      child: ExpansionTile(
        leading: CircleAvatar(child: Text('${record['id'] ?? '?'}')),
        title: Text(
          '${_number(record['latitud'], 6)}, ${_number(record['longitud'], 6)}',
        ),
        subtitle: Text('${record['fecha_registro'] ?? 'Sin fecha'}'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _dataRow('Latitud', _number(record['latitud'], 7)),
          _dataRow('Longitud', _number(record['longitud'], 7)),
          _dataRow('Precisión', '${_number(record['precision'])} m'),
          _dataRow('Altitud', '${_number(record['altitud'])} m'),
          _dataRow('Velocidad', '${_number(record['velocidad'])} m/s'),
          _dataRow('Rumbo', '${_number(record['rumbo'])}°'),
          _dataRow('GPS timestamp', '${record['marca_tiempo'] ?? '—'}'),
          _dataRow('Registro BD', '${record['fecha_registro'] ?? '—'}'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GPS → Webhook → PostgreSQL'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _apiController,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'URL pública del backend en Render',
                hintText: 'https://mi-backend.onrender.com',
                prefixIcon: Icon(Icons.cloud_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _hasError
                    ? Theme.of(context).colorScheme.errorContainer
                    : Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  if (_busy)
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(_hasError ? Icons.error_outline : Icons.info_outline),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_status)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _currentLocationCard(),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _busy ? null : _sendLocation,
              icon: const Icon(Icons.my_location),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Obtener y enviar ubicación'),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _loadRecords,
              icon: const Icon(Icons.storage),
              label: const Text('Ver datos guardados'),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Registros en PostgreSQL',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Chip(label: Text('${_records.length}')),
              ],
            ),
            if (_records.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('Aún no se han consultado registros.'),
                ),
              )
            else
              ..._records.map(_recordCard),
          ],
        ),
      ),
    );
  }
}
